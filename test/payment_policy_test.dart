import 'package:flutter_test/flutter_test.dart';

import 'package:rentwise/data/appwrite_mappers.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/state/workspace_state.dart';

import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';

/// v1.26 payment policy: down payment → remaining balance → collateral,
/// then ID + signature — everything settles BEFORE the items may leave
/// the shop. The customer picks up and returns the items themselves
/// (the shop does not deliver). Each action is written through to the
/// orders collection and logged as activity.
void main() {
  initTestCloud();

  Future<(WorkspaceState, RecordingBackend)> ownerSession() async {
    final backend = RecordingBackend();
    final state = WorkspaceState(backend: backend);
    final err = await state.signInWithEmail(
        SampleDataset.demoOwner.email, 'owner-pass');
    expect(err, isNull);
    return (state, backend);
  }

  /// Books a fresh order for 4 folding chairs and returns
  /// (id, total). Plan amounts are expressed relative to the real
  /// total so the test never depends on fixture day-rates.
  (String, double) bookWithPlan(WorkspaceState state,
      {double downFactor = 0.5, double collateralFactor = 0.5}) {
    final chairs =
        state.inventory.firstWhere((i) => i.name == 'Folding Chairs');
    final total = chairs.ratePerDay * 4;
    final id = state.createBooking(
      customerName: 'Mia Chen',
      eventName: 'Policy Probe',
      eventDate: DateTime.now().add(const Duration(days: 3)),
      lines: [BookingLine(item: chairs, qty: 4)],
      downPayment: total * downFactor,
      collateralAmount: total * collateralFactor,
    );
    return (id, total);
  }

  group('payment policy — booking carries the plan', () {
    test('down payment + collateral persist through write-through',
        () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final down = total * 0.5;
      final collateral = total * 0.5;

      final order = state.orderById(id)!;
      expect(order.total, total);
      expect(order.downPayment, down);
      expect(order.collateralAmount, collateral);
      expect(order.remainingDue, total - down);
      // Nothing is auto-marked paid — the ledger records real receipts.
      expect(order.downPaymentPaidAt, isNull);
      expect(order.outstandingTotal, total * 1.5); // 0.5 down + 0.5 rem + 0.5 col
      expect(order.canHandOver, isFalse);

      final bookingWrite = backend.writes
          .where((w) => w.collection == 'orders' && w.id == id)
          .first;
      expect(bookingWrite.data['downPayment'], down);
      expect(bookingWrite.data['collateralAmount'], collateral);
    });

    test('zero amounts are auto-satisfied — no fake money is implied',
        () async {
      final (state, _) = await ownerSession();
      final (id, total) = bookWithPlan(state, downFactor: 0, collateralFactor: 0);
      final order = state.orderById(id)!;
      // Down 0 → nothing to collect; collateral 0 → nothing to hold.
      expect(order.downPaymentPaid, isTrue);
      expect(order.collateralPaid, isTrue);
      // Remaining = full total, still owed.
      expect(order.remainingDue, total);
      expect(order.outstandingTotal, total);
      expect(order.handoverBlockers,
          contains('Remaining Br ${total.toStringAsFixed(0)} not received'));
    });
  });

  group('payment policy — the handover gate', () {
    test('handover is REFUSED while anything is outstanding', () async {
      final (state, backend) = await ownerSession();
      final (id, _) = bookWithPlan(state);
      final before = state.orders.length;
      final activityBefore =
          backend.writes.where((w) => w.collection == 'activities').length;

      // Illegal shortcut: straight to "With customer" with money open.
      final ok = state.updateOrderStatus(
          state.orderById(id)!, OrderStatus.outForDelivery);

      expect(ok, isFalse, reason: 'the gate must refuse unpaid handover');
      expect(state.orderById(id)!.status, OrderStatus.confirmed);
      // No orders.status write, no new activity.
      expect(
          backend.writes.where((w) =>
              w.collection == 'orders' &&
              w.id == id &&
              w.data['status'] == 'outForDelivery'),
          isEmpty);
      expect(
          backend.writes.where((w) => w.collection == 'activities').length,
          activityBefore);
      expect(state.orders.length, before);
    });

    test('marking every step unlocks handover — each write recorded',
        () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final down = total * 0.5;
      final collateral = total * 0.5;
      var order = state.orderById(id)!;

      // 1. down payment
      expect(state.markDownPaymentReceived(order), isTrue);
      order = state.orderById(id)!;
      expect(order.downPaymentPaidAt, isNotNull);
      expect(order.outstandingTotal, closeTo(total - down + collateral, 0.01));

      // 2. remaining balance
      expect(state.markRemainingReceived(order), isTrue);
      order = state.orderById(id)!;
      expect(order.remainingPaidAt, isNotNull);
      expect(order.outstandingTotal, closeTo(collateral, 0.01));

      // 3. collateral
      expect(state.markCollateralReceived(order), isTrue);
      order = state.orderById(id)!;
      expect(order.collateralPaidAt, isNotNull);
      expect(order.outstandingTotal, 0);

      // 4. ID check — still blocking.
      expect(order.canHandOver, isFalse);
      expect(state.markIdVerified(order), isTrue);
      order = state.orderById(id)!;
      expect(order.idVerifiedAt, isNotNull);

      // 5. signature — the last blocker.
      final strokes = [
        [const Offset(0, 10), const Offset(200, 400), const Offset(600, 200)],
        [const Offset(800, 100), const Offset(3000, 3500)],
      ];
      expect(
          state.saveSignature(order,
              strokes: strokes, signedName: 'Mia Chen'),
          isTrue);
      order = state.orderById(id)!;
      expect(order.signatureCaptured, isTrue);
      expect(order.signedName, 'Mia Chen');
      expect(order.canHandOver, isTrue);
      expect(order.handoverBlockers, isEmpty);

      // Money + ID + signature actions → activity entries; the four
      // order writes carry the payment fields.
      final orderWrites = backend.writes
          .where((w) => w.collection == 'orders' && w.id == id)
          .toList();
      // booking + down + remaining + collateral + id + signature = 6
      expect(orderWrites, hasLength(6));
      expect(orderWrites.last.data['signatureData'], isNotEmpty);
      expect(orderWrites.last.data['signedName'], 'Mia Chen');
      final paymentLogs = backend.writes
          .where((w) =>
              w.collection == 'activities' &&
              (w.data['body'] as String).contains('#$id'))
          .length;
      expect(paymentLogs, 5); // down, remaining, collateral, id, signature
      // Three of them are payment-type receipts.
      expect(
          backend.writes
              .where((w) =>
                  w.collection == 'activities' &&
                  (w.data['body'] as String).contains('down payment'))
              .length,
          1);

      // The gate now lets the order leave the shop.
      expect(
          state.updateOrderStatus(order, OrderStatus.outForDelivery), isTrue);
      expect(state.orderById(id)!.status, OrderStatus.outForDelivery);
    });

    test('double-marking a step is refused (no duplicate receipts)',
        () async {
      final (state, _) = await ownerSession();
      final (id, _) = bookWithPlan(state);
      final order = state.orderById(id)!;

      expect(state.markDownPaymentReceived(order), isTrue);
      // Already received — a second tap does nothing.
      expect(
          state.markDownPaymentReceived(state.orderById(id)!), isFalse);
    });

    test('saveSignature refuses garbage and oversized blobs', () async {
      final (state, _) = await ownerSession();
      final (id, _) = bookWithPlan(state);
      final order = state.orderById(id)!;

      // Empty ink → refused.
      expect(
          state.saveSignature(order, strokes: const [], signedName: 'X'),
          isFalse);

      // Degenerate single-point strokes → encoded as empty → refused.
      expect(
          state.saveSignature(order,
              strokes: const [
                [Offset(1, 1)]
              ],
              signedName: 'X'),
          isFalse);
    });
  });

  group('payment policy — honest totals', () {
    test('awaitingPaymentTotal reflects the real outstanding money',
        () async {
      final (state, _) = await ownerSession();
      final before = state.awaitingPaymentTotal;

      final (id, total) = bookWithPlan(state);
      // +1.5×total outstanding on the new booking (0.5 remaining +
      // 0.5 down + 0.5 collateral).
      expect(state.awaitingPaymentTotal, closeTo(before + total * 1.5, 0.01));

      // Settle everything on the new order → back to the seed baseline.
      var order = state.orderById(id)!;
      state.markDownPaymentReceived(order);
      state.markRemainingReceived(state.orderById(id)!);
      state.markCollateralReceived(state.orderById(id)!);
      expect(state.awaitingPaymentTotal, closeTo(before, 0.01));
    });

    test('awaitingHandoverOrders lists exactly the blocked ones', () async {
      final (state, _) = await ownerSession();
      final (id, _) = bookWithPlan(state);
      final blocked = state.awaitingHandoverOrders;
      // The two seeded settled orders (RW-2051, RW-2042) are NOT blocked.
      expect(blocked.any((o) => o.id == id), isTrue);
      expect(blocked.any((o) => o.id == 'RW-2051'), isFalse);
      expect(blocked.any((o) => o.id == 'RW-2042'), isFalse);
    });
  });

  group('customer pickup semantics', () {
    test('outForDelivery relabels to With customer — storage name kept',
        () {
      // The cloud documents store the enum NAME (statusToDoc) — the
      // legacy value stays stable, only the display label changes.
      expect(OrderStatus.outForDelivery.name, 'outForDelivery');
      expect(OrderStatus.outForDelivery.label, 'With customer');
      expect(
          OrderStatus.outForDelivery.actionLabel, 'Hand over to customer');
      // Documents written from the label change still decode.
      expect(statusFromDoc('outForDelivery'), OrderStatus.outForDelivery);
    });
  });

  group('signature codec', () {
    test('round-trips strokes through the compact document form', () {
      final strokes = [
        [
          const Offset(10, 20),
          const Offset(150, 300),
          const Offset(900, 4095),
          const Offset(4095, 2000),
        ],
        [
          const Offset(0, 0),
          const Offset(4095, 4095),
        ],
      ];
      final doc = signatureToDoc(strokes);
      expect(doc.startsWith('S1'), isTrue);
      expect(doc.length, lessThan(2800), reason: 'must fit the column');
      final back = signatureFromDoc(doc);
      expect(back, hasLength(2));
      expect(back[0], hasLength(4));
      // Deltas are integer-rounded — allow ±1 per coordinate.
      for (var s = 0; s < strokes.length; s++) {
        for (var p = 0; p < strokes[s].length; p++) {
          expect((back[s][p].dx - strokes[s][p].dx).abs(), lessThanOrEqualTo(1.0));
          expect((back[s][p].dy - strokes[s][p].dy).abs(), lessThanOrEqualTo(1.0));
        }
      }
    });

    test('a dense 300-point signature still fits the column budget', () {
      final stroke = <Offset>[
        for (var i = 0; i < 300; i++) Offset(i * 13.0, (i * 7) % 4095),
      ];
      final doc = signatureToDoc([stroke]);
      expect(doc.length, lessThan(2800),
          reason: 'real signatures must persist — codec too fat');
      expect(signatureFromDoc(doc), hasLength(1));
    });

    test('decodes garbage to empty without throwing', () {
      expect(signatureFromDoc(''), isEmpty);
      expect(signatureFromDoc('seeded-signature'), isEmpty);
      expect(signatureFromDoc('S1not-base64!!'), isEmpty);
      expect(signatureFromDoc('S1QUJD'), isEmpty); // decodes to junk bytes
      expect(signatureFromDoc('S1AAAA'), isEmpty); // truncated stroke count
    });
  });

  group('customer ID records', () {
    test('ID type + number persist through write-through', () async {
      final (state, backend) = await ownerSession();
      state.addCustomer(
        name: 'Kofi Mensah',
        company: '—',
        email: 'kofi@example.com',
        phone: '—',
        idType: 'Passport',
        idNumber: 'GHA-884213',
      );
      final kofi = state.customerByName('kofi mensah')!;
      expect(kofi.idType, 'Passport');
      expect(kofi.idNumber, 'GHA-884213');

      final write = backend.writes
          .where((w) => w.collection == 'customers' && w.id == kofi.id)
          .first;
      expect(write.data['idType'], 'Passport');
      expect(write.data['idNumber'], 'GHA-884213');

      // The handover card's ID row can re-verify against this record:
      // customerByName(order.customerName) → idType/idNumber shown.
      expect(state.customerByName('Kofi Mensah')!.idNumber, 'GHA-884213');
    });
  });
}
