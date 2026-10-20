import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rentwise/app.dart';
import 'package:rentwise/data/appwrite_mappers.dart';
import 'package:rentwise/models/payment_receipt.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/screens/orders/order_detail_screen.dart';
import 'package:rentwise/services/appwrite_backend.dart';
import 'package:rentwise/state/shell_state.dart';
import 'package:rentwise/state/workspace_state.dart';

import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';

/// v1.30 payments ledger: receipts are append-only facts (in and out);
/// WHAT each receipt settles is DERIVED in policy order — down payment →
/// remaining balance → collateral — and the order document's stage flags
/// are materialized from that derived truth. Partial payments, refunds
/// and owner corrections all flow through the same allocator.
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

  Future<(WorkspaceState, RecordingBackend)> employeeSession() async {
    final backend = RecordingBackend();
    final state = WorkspaceState(backend: backend);
    final err = await state.signInWithEmail(
        SampleDataset.demoEmployee.email, 'employee-pass');
    expect(err, isNull);
    return (state, backend);
  }

  /// Books a fresh order for 4 folding chairs with a 50/50 plan and
  /// returns (id, total). Plan amounts stay relative to the real total
  /// so the tests never depend on fixture day-rates.
  (String, double) bookWithPlan(WorkspaceState state,
      {double downFactor = 0.5, double collateralFactor = 0.5}) {
    final chairs =
        state.inventory.firstWhere((i) => i.name == 'Folding Chairs');
    final total = chairs.ratePerDay * 4;
    final id = state.createBooking(
      customerName: 'Mia Chen',
      eventName: 'Ledger Probe',
      eventDate: DateTime.now().add(const Duration(days: 3)),
      lines: [BookingLine(item: chairs, qty: 4)],
      downPayment: total * downFactor,
      collateralAmount: total * collateralFactor,
    );
    return (id, total);
  }

  group('allocator — pure policy order (down → remaining → collateral)', () {
    test('one receipt may honestly span two buckets', () {
      final now = DateTime.now();
      final order = RentalOrder(
        id: 'RW-X1',
        eventName: 'Span',
        customerName: 'C',
        contactName: 'C',
        createdAt: now,
        eventDate: now,
        itemCount: 1,
        total: 1200,
        status: OrderStatus.confirmed,
        downPayment: 600,
        collateralAmount: 300,
      );
      final ledger = PaymentLedger.of(order, [
        PaymentReceipt(
          id: 'PAY-1',
          orderId: 'RW-X1',
          amount: 900,
          method: PaymentMethod.cash,
          recordedBy: 'Desk',
          recordedAt: now,
        ),
      ]);

      // 900 = 600 down (crossed) + 300 of the 600 remaining (partial).
      expect(ledger.downPaid, 600);
      expect(ledger.remainingPaid, 300);
      expect(ledger.collateralPaid, 0);
      expect(ledger.downPaidAt, now);
      expect(ledger.bucketSettled(PaymentBucket.downPayment), isTrue);
      expect(ledger.bucketSettled(PaymentBucket.remaining), isFalse);
      expect(ledger.outstandingTotal, closeTo(600, 0.001)); // 300 rem + 300 col
      expect(ledger.nextDue!.bucket, PaymentBucket.remaining);
      expect(ledger.nextDue!.amount, closeTo(300, 0.001));
      expect(ledger.canHandOver, isFalse);
      expect(
        ledger.handoverBlockers,
        containsAll([
          contains('partially received'),
          contains('Collateral'),
        ]),
      );
    });

    test('a refund drains collateral first and un-sets the crossing', () {
      final now = DateTime.now();
      final order = RentalOrder(
        id: 'RW-X2',
        eventName: 'Refund',
        customerName: 'C',
        contactName: 'C',
        createdAt: now,
        eventDate: now,
        itemCount: 1,
        total: 1000,
        status: OrderStatus.returned,
        downPayment: 500,
        collateralAmount: 400,
      );
      final t1 = now.subtract(const Duration(days: 2));
      final t2 = now.subtract(const Duration(days: 1));
      final t3 = now;

      final settled = PaymentLedger.of(order, [
        PaymentReceipt(
            id: 'PAY-1',
            orderId: 'RW-X2',
            amount: 500,
            method: PaymentMethod.telebirr,
            recordedBy: 'D',
            recordedAt: t1),
        PaymentReceipt(
            id: 'PAY-2',
            orderId: 'RW-X2',
            amount: 500,
            method: PaymentMethod.cash,
            recordedBy: 'D',
            recordedAt: t2),
        PaymentReceipt(
            id: 'PAY-3',
            orderId: 'RW-X2',
            amount: 400,
            method: PaymentMethod.cash,
            recordedBy: 'D',
            recordedAt: t3),
      ]);
      expect(settled.fullySettled, isTrue);
      expect(settled.collateralPaidAt, t3);
      expect(settled.collateralMethod, PaymentMethod.cash);

      final refunded = PaymentLedger.of(order, [
        ...settled.receipts,
        PaymentReceipt(
            id: 'PAY-4',
            orderId: 'RW-X2',
            amount: -400,
            method: PaymentMethod.cash,
            recordedBy: 'D',
            recordedAt: t3.add(const Duration(hours: 1))),
      ]);
      // Collateral un-settles honestly — the money is back with the
      // customer, so it is no longer "held".
      expect(refunded.collateralPaid, 0);
      expect(refunded.collateralPaidAt, isNull);
      expect(refunded.collateralMethod, isNull);
      expect(refunded.collateralHeld, 0);
      expect(refunded.downPaidAt, t1);
      expect(refunded.remainingPaidAt, t2);
      // The collateral stage honestly UN-SETTLES: the plan no longer
      // shows a satisfied deposit stage. (Returned orders are excluded
      // from outstanding KPIs, so this never becomes fake debt.)
      expect(refunded.bucketSettled(PaymentBucket.collateral), isFalse);
      expect(refunded.outstandingFor(PaymentBucket.collateral),
          closeTo(400, 0.001));
      expect(refunded.fullySettled, isFalse);
    });

    test('a refunded stage can be re-settled by a later receipt', () {
      final now = DateTime.now();
      final order = RentalOrder(
        id: 'RW-X3',
        eventName: 'Re-cross',
        customerName: 'C',
        contactName: 'C',
        createdAt: now,
        eventDate: now,
        itemCount: 1,
        total: 400,
        status: OrderStatus.confirmed,
        downPayment: 400, // remainingDue = 0 — down + collateral are the targets
        collateralAmount: 400,
      );
      final rows = [
        PaymentReceipt(
            id: 'PAY-1',
            orderId: 'RW-X3',
            amount: 800, // one handover: down 400 + collateral 400
            method: PaymentMethod.cash,
            recordedBy: 'D',
            recordedAt: now.subtract(const Duration(days: 1))),
      ];
      final l1 = PaymentLedger.of(order, rows);
      expect(l1.collateralPaidAt, isNotNull);

      final refund = PaymentReceipt(
          id: 'PAY-2',
          orderId: 'RW-X3',
          amount: -400,
          method: PaymentMethod.cash,
          recordedBy: 'D',
          recordedAt: now);
      final l2 = PaymentLedger.of(order, [...rows, refund]);
      expect(l2.collateralPaidAt, isNull);

      final again = PaymentReceipt(
          id: 'PAY-3',
          orderId: 'RW-X3',
          amount: 400,
          method: PaymentMethod.mpesa,
          recordedBy: 'D',
          recordedAt: now.add(const Duration(hours: 1)));
      final l3 = PaymentLedger.of(order, [...rows, refund, again]);
      expect(l3.collateralPaidAt, again.recordedAt);
      expect(l3.collateralMethod, PaymentMethod.mpesa);
    });

    test('allocationFor previews the split without touching the ledger',
        () {
      final now = DateTime.now();
      final order = RentalOrder(
        id: 'RW-X4',
        eventName: 'Preview',
        customerName: 'C',
        contactName: 'C',
        createdAt: now,
        eventDate: now,
        itemCount: 1,
        total: 1200,
        status: OrderStatus.confirmed,
        downPayment: 600,
        collateralAmount: 300,
      );
      final ledger = PaymentLedger.of(order, const []);

      expect(ledger.allocationFor(900), {
        PaymentBucket.downPayment: closeTo(600, 0.001),
        PaymentBucket.remaining: closeTo(300, 0.001),
      });
      expect(ledger.allocationFor(2000), {
        PaymentBucket.downPayment: 600,
        PaymentBucket.remaining: 600,
        PaymentBucket.collateral: 300,
      });
      expect(ledger.allocationFor(50), {
        PaymentBucket.downPayment: 50,
      });
    });
  });

  group('recordPayment — the state path', () {
    test('receipts append with honest counter ids and write through', () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final order = state.orderById(id)!;

      expect(state.recordPayment(order,
        amount: total * 0.5,
        method: PaymentMethod.telebirr,
        note: 'Down payment'), isTrue);

      // Fixture seeds PAY-0001..0009 — the next receipt counts up.
      final rows = state.paymentsForOrder(id);
      expect(rows, hasLength(1));
      expect(rows.first.id, 'PAY-0010');
      expect(rows.first.amount, total * 0.5);
      expect(rows.first.orderId, id);

      final write = backend.writes
          .where((w) => w.collection == 'payments' && w.id == 'PAY-0010')
          .first;
      expect(write.data['orderId'], id);
      expect(write.data['amount'], total * 0.5);
      expect(write.data['method'], 'telebirr');
      expect(write.data['note'], isNotEmpty);

      // The stage flag materialized from the ledger.
      final live = state.orderById(id)!;
      expect(live.downPaymentPaidAt, isNotNull);
      expect(live.downPaymentMethod, PaymentMethod.telebirr);
    });

    test('overpayment is refused — the ledger never invents credit',
        () async {
      final (state, _) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final order = state.orderById(id)!;

      expect(
          state.recordPayment(order,
              amount: total * 1.6, method: PaymentMethod.cash),
          isFalse);
      expect(state.lastNotice?.isError, isTrue);
      expect(state.paymentsForOrder(id), isEmpty);
      expect(state.orderById(id)!.downPaymentPaidAt, isNull);
    });

    test('a returned order\'s ledger is closed', () async {
      final (state, _) = await ownerSession();
      final (id, _) = bookWithPlan(state, downFactor: 0, collateralFactor: 0);
      // Cancel before dispatch: confirmed → preparing → returned.
      expect(
          state.updateOrderStatus(
              state.orderById(id)!, OrderStatus.preparing),
          isTrue);
      expect(
          state.updateOrderStatus(
              state.orderById(id)!, OrderStatus.returned),
          isTrue);

      expect(
          state.recordPayment(state.orderById(id)!,
              amount: 100, method: PaymentMethod.cash),
          isFalse);
      expect(state.lastNotice?.isError, isTrue);
    });

    test('a split receipt logs the honest allocation trail', () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final order = state.orderById(id)!;

      // 75% of total covers the 50% down AND 25% of the remaining.
      expect(
          state.recordPayment(order,
              amount: total * 0.75, method: PaymentMethod.cash, note: 'T1'),
          isTrue);

      final log = backend.writes
          .where((w) =>
              w.collection == 'activities' &&
              (w.data['body'] as String).contains('#$id') &&
              (w.data['body'] as String).contains('T1'))
          .first;
      final body = log.data['body'] as String;
      expect(body, contains('via Cash'));
      expect(body, contains('Down payment'));
      expect(body, contains('Remaining balance'));
    });

    test('employees record receipts too — payments are shift work',
        () async {
      final (state, backend) = await employeeSession();
      final (id, total) = bookWithPlan(state);
      expect(
          state.recordPayment(state.orderById(id)!,
              amount: total * 0.5, method: PaymentMethod.cbeBirr),
          isTrue);
      expect(backend.writes.any((w) => w.collection == 'payments'), isTrue);
    });
  });

  group('materialization — stage flags follow the ledger', () {
    test('partial money keeps the flag open; the crossing sets it',
        () async {
      final (state, _) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final down = total * 0.5;

      // Half of the down payment lands.
      expect(
          state.recordPayment(state.orderById(id)!,
              amount: down / 2, method: PaymentMethod.cash),
          isTrue);
      var live = state.orderById(id)!;
      expect(live.downPaymentPaidAt, isNull,
          reason: 'half the down payment must NOT settle the stage');
      final ledger = state.ledgerFor(live);
      expect(ledger.paidFor(PaymentBucket.downPayment), closeTo(down / 2, 0.01));
      expect(ledger.handoverBlockers.first, contains('partially received'));

      // The second half crosses the threshold.
      expect(
          state.recordPayment(live,
              amount: down / 2, method: PaymentMethod.mpesa),
          isTrue);
      live = state.orderById(id)!;
      expect(live.downPaymentPaidAt, isNotNull);
      expect(live.downPaymentMethod, PaymentMethod.mpesa,
          reason: 'the crossing receipt supplies the stage rail');
    });

    test('owner correction removes a receipt and un-sets its stage',
        () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final order = state.orderById(id)!;

      expect(
          state.recordPayment(order,
              amount: total * 0.5, method: PaymentMethod.card),
          isTrue);
      expect(state.orderById(id)!.downPaymentPaidAt, isNotNull);

      final receipt = state.paymentsForOrder(id).first;
      expect(state.deletePaymentReceipt(state.orderById(id)!, receipt),
          isTrue);
      expect(backend.deletedPaymentIds, contains(receipt.id));

      final live = state.orderById(id)!;
      expect(live.downPaymentPaidAt, isNull,
          reason: 'the crossing receipt is gone — the stage re-opens');
      expect(state.ledgerFor(live).outstandingTotal, closeTo(total * 1.5, 0.01));
    });

    test('employees can never correct the ledger', () async {
      final (state, backend) = await employeeSession();
      final (id, total) = bookWithPlan(state);
      expect(
          state.recordPayment(state.orderById(id)!,
              amount: total * 0.5, method: PaymentMethod.cash),
          isTrue);
      final receipt = state.paymentsForOrder(id).first;
      expect(state.deletePaymentReceipt(state.orderById(id)!, receipt),
          isFalse);
      expect(backend.deletedPaymentIds, isEmpty);
      expect(state.lastNotice?.isError, isTrue,
          reason: 'denials are never silent');
    });
  });

  group('refundCollateral — deposits go back when items return', () {
    test('refused while the order is still open', () async {
      final (state, _) = await ownerSession();
      final (id, _) = bookWithPlan(state);
      expect(
          state.refundCollateral(state.orderById(id)!,
              method: PaymentMethod.cash),
          isFalse);
      expect(state.lastNotice?.isError, isTrue);
    });

    test('full loop: settle → hand over → return → refund', () async {
      final (state, backend) = await ownerSession();
      final (id, total) = bookWithPlan(state);
      final collateral = total * 0.5;

      var order = state.orderById(id)!;
      state.markCollateralReceived(order); // settles everything
      state.markIdVerified(order);
      final strokes = [
        [const Offset(0, 10), const Offset(200, 400), const Offset(600, 200)],
      ];
      state.saveSignature(order, strokes: strokes, signedName: 'Mia Chen');
      order = state.orderById(id)!;
      expect(order.canHandOver, isTrue);
      expect(
          state.updateOrderStatus(order, OrderStatus.outForDelivery), isTrue);
      expect(
          state.updateOrderStatus(
              state.orderById(id)!, OrderStatus.returned),
          isTrue);

      final heldBefore = state.ledgerFor(state.orderById(id)!).collateralHeld;
      expect(heldBefore, closeTo(collateral, 0.01));

      expect(
          state.refundCollateral(state.orderById(id)!,
              method: PaymentMethod.telebirr, note: 'deposit back'),
          isTrue);

      final live = state.orderById(id)!;
      final ledger = state.ledgerFor(live);
      expect(ledger.collateralHeld, 0);
      expect(live.collateralPaidAt, isNull,
          reason: 'the deposit is no longer held — the stage un-settles');

      final refundRow = state.paymentsForOrder(id).first;
      expect(refundRow.isRefund, isTrue);
      expect(refundRow.amount, closeTo(-collateral, 0.01));
      expect(refundRow.note, contains('deposit back'));

      final write = backend.writes
          .where((w) =>
              w.collection == 'payments' && w.data['amount'] is num && (w.data['amount'] as num) < 0)
          .first;
      expect(write.data['method'], 'telebirr');

      final log = backend.writes
          .where((w) =>
              w.collection == 'activities' &&
              (w.data['body'] as String).contains('collateral'))
          .last;
      expect(log.data['body'], contains('returned the'));
    });
  });

  group('legacy orders — v1.29 flags read as held money', () {
    /// A v1.29-world snapshot: stage flags exist, but NO receipts —
    /// exactly what every pre-ledger cloud looks like on upgrade day.
    RecordingBackend legacyBackend() {
      final now = DateTime.now();
      return RecordingBackend(
        snapshot: WorkspaceSnapshot(
          accountUserId: 'fake-user',
          inventory: SampleDataset.inventory(),
          orders: SampleDataset.orders(now),
          customers: SampleDataset.customers(now),
          activity: SampleDataset.activity(now),
          pickups: SampleDataset.pickups(now),
          payments: const [],
          workspaces: [SampleDataset.workspaceName],
          activeWorkspace: SampleDataset.workspaceName,
          grossMonthK: SampleDataset.grossRevenueMonth,
          utilizationPct: SampleDataset.utilizationPct,
          earnings: SampleDataset.earningsDaily(now),
          categoryRevenue: SampleDataset.categoryRevenue,
          trend: SampleDataset.revenueTrend(now),
        ),
      );
    }

    Future<WorkspaceState> legacySession(
        RecordingBackend backend) async {
      final state = WorkspaceState(backend: backend);
      final err = await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');
      expect(err, isNull);
      return state;
    }

    test('untouched legacy stages project as settled without receipts',
        () async {
      final backend = legacyBackend();
      final state = await legacySession(backend);
      final order = state.orderById('RW-2051')!;
      final ledger = state.ledgerFor(order);

      expect(ledger.downPaid, closeTo(order.downPayment, 0.01));
      expect(ledger.remainingPaid, closeTo(order.remainingDue, 0.01));
      expect(ledger.collateralPaid, closeTo(order.collateralAmount, 0.01));
      expect(ledger.fullySettled, isTrue);
      // No REAL receipts: nothing shows in the ledger list…
      expect(state.paymentsForOrder('RW-2051'), isEmpty);
    });

    test('first mutation migrates legacy flags into real receipts',
        () async {
      final backend = legacyBackend();
      final state = await legacySession(backend);
      final order = state.orderById('RW-2051')!;
      expect(state.ledgerFor(order).fullySettled, isTrue);

      // Retire the items, then hand the deposit back — the first ledger
      // mutation on this legacy order.
      expect(
          state.updateOrderStatus(
              state.orderById('RW-2051')!, OrderStatus.returned),
          isTrue);
      expect(
          state.refundCollateral(state.orderById('RW-2051')!,
              method: PaymentMethod.cash),
          isTrue);

      final rows = state.paymentsForOrder('RW-2051');
      // The legacy stages became REAL migration receipts…
      expect(rows.where((r) => r.amount > 0), hasLength(3));
      // …with honest provenance…
      expect(
          rows
              .where((r) => r.amount > 0)
              .every((r) => r.note.contains('ledger was enabled')),
          isTrue);
      // …and the refund drew the collateral back to zero.
      expect(state.ledgerFor(state.orderById('RW-2051')!).collateralHeld, 0);

      final migratedWrite = backend.writes
          .where((w) =>
              w.collection == 'payments' &&
              (w.data['note'] as String? ?? '')
                  .contains('ledger was enabled'))
          .toList();
      expect(migratedWrite, hasLength(3));
    });

    test('fixture receipts reproduce the settled orders exactly', () async {
      final (state, _) = await ownerSession();
      for (final orderId in ['RW-2051', 'RW-2042']) {
        final order = state.orderById(orderId)!;
        final ledger = state.ledgerFor(order);
        expect(ledger.downPaidAt, order.downPaymentPaidAt,
            reason: '$orderId down crossing matches the flag');
        expect(ledger.downMethod, order.downPaymentMethod);
        // Remaining/collateral receipts were recorded the same DAY as
        // the flags but a couple of hours apart — compare loosely.
        expect(
          ledger.remainingPaidAt!.difference(order.remainingPaidAt!).abs(),
          lessThan(const Duration(hours: 3)),
          reason: '$orderId remaining crossing matches the flag day',
        );
        expect(ledger.remainingMethod, order.remainingMethod);
        expect(
          ledger.collateralPaidAt!.difference(order.collateralPaidAt!).abs(),
          lessThan(const Duration(hours: 3)),
          reason: '$orderId collateral crossing matches the flag day',
        );
        expect(ledger.collateralMethod, order.collateralMethod);
      }
      // RW-2039 is returned WITH its collateral still held — the desk
      // still owes that deposit back, on purpose (demo of the refund).
      final returned = state.ledgerFor(state.orderById('RW-2039')!);
      expect(returned.collateralHeld, closeTo(800, 0.01));
    });
  });

  group('codec — receipts round-trip through documents', () {
    test('paymentToDoc → paymentFromDoc preserves every field', () {
      final at = DateTime.utc(2026, 2, 3, 10, 30, 15);
      final receipt = PaymentReceipt(
        id: 'PAY-77',
        orderId: 'RW-2051',
        amount: -42.5,
        method: PaymentMethod.chapa,
        note: 'partial refund',
        recordedBy: 'Olivia Wells',
        recordedAt: at,
      );

      final doc = paymentToDoc(receipt);
      final back = paymentFromDoc('PAY-77', doc);

      expect(back.id, 'PAY-77');
      expect(back.orderId, 'RW-2051');
      expect(back.amount, -42.5);
      expect(back.method, PaymentMethod.chapa);
      expect(back.note, 'partial refund');
      expect(back.recordedBy, 'Olivia Wells');
      // Documents store UTC; the codec returns local time.
      expect(back.recordedAt.toUtc(), at);
      expect(back.isRefund, isTrue);
    });
  });

  group('order detail UI — the ledger on screen', () {
    Widget app() => MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (_) => WorkspaceState(backend: RecordingBackend())),
            ChangeNotifierProvider(create: (_) => ShellState()),
          ],
          child: const RentWiseApp(),
        );

    Future<WorkspaceState> signIn(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0),
          SampleDataset.demoOwner.email);
      await tester.enterText(find.byType(TextField).at(1), 'owner-pass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      final state =
          tester.element(find.byType(Scaffold)).read<WorkspaceState>();
      return state;
    }

    Future<void> openOrder(WidgetTester tester, WorkspaceState state,
        String orderId) async {
      final order = state.orderById(orderId)!;
      // ignore: unawaited_futures
      Navigator.of(tester.element(find.byType(Scaffold))).push(
        MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(order: order)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('settled order shows its receipts and refund flow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await signIn(tester);
      await openOrder(tester, state, 'RW-2051');

      // The three settled stages…
      expect(find.text('Down payment'), findsWidgets);
      expect(find.text('Remaining balance'), findsWidgets);
      // …the receipts section with the fixture rows (newest first)…
      expect(find.textContaining('Receipts'), findsOneWidget);
      expect(find.text('+Br 2,050'), findsNWidgets(2));
      expect(find.text('+Br 500'), findsOneWidget);
      expect(find.textContaining('Olivia Wells'), findsWidgets);
      // …and NO record button (nothing outstanding).
      expect(find.text('Record payment'), findsNothing);
    });

    testWidgets('returned order offers the collateral refund',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await signIn(tester);
      await openOrder(tester, state, 'RW-2039');

      expect(find.textContaining('Refund collateral'), findsOneWidget);
      expect(find.textContaining('800'), findsWidgets);
    });

    testWidgets('record-payment dialog previews the allocation split',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await signIn(tester);
      await openOrder(tester, state, 'RW-2048');

      // The Harper Wedding has no plan flags — everything is still due.
      expect(find.text('Record payment'), findsOneWidget);
      await tester.ensureVisible(find.text('Record payment'));
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();

      expect(find.text('Amount received'), findsOneWidget);
      expect(find.text('will be applied to'), findsOneWidget);
      expect(find.textContaining('Down payment'), findsWidgets);
    });
  });
}
