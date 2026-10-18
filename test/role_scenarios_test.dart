import 'package:flutter_test/flutter_test.dart';

import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/rental_order.dart' show OrderStatus;
import 'package:rentwise/services/appwrite_backend.dart';
import 'package:rentwise/state/workspace_state.dart';

import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';

/// End-to-end role journeys against the in-memory Appwrite stand-in.
///
/// Three personas use the system exactly as the live app would —
/// sign-in through [WorkspaceState.signInWithEmail], every mutation
/// written through to the fake cloud — and each write is asserted on
/// the backend side. No demo mode, no persona shortcuts: a journey
/// that cannot reach the cloud simply fails.
void main() {
  initTestCloud(); // path-provider shim BEFORE any Appwrite client exists

  // =========================================================== OWNER
  group('OWNER journey — Olivia runs the business', () {
    test('signs in, loads the live cloud workspace and sees everything',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);

      final err = await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');
      expect(err, isNull, reason: 'owner sign-in must succeed');

      expect(state.isSignedIn, isTrue);
      expect(state.isOwner, isTrue);
      expect(state.account!.name, SampleDataset.demoOwner.name);
      expect(state.liveBackend, isTrue);

      // Exactly what the cloud returned — the live Riverside dataset.
      expect(state.workspace, 'Riverside Events');
      expect(state.inventory.length, 6);
      expect(state.orders.length, 5);
      expect(state.customers.length, 5);
      expect(state.activity.length, 6);
      expect(state.pickups.length, 3);

      // Owner-only sections are open to her.
      expect(state.canAccess(Section.reports), isTrue);
      expect(state.canAccess(Section.access), isTrue);

      // Metrics came from the cloud metrics document, not local defaults.
      expect(state.monthGrossRevenueK, 28.9);
      expect(state.utilization, 72.8);
      expect(state.earnings, isNotEmpty);
      expect(state.categorySeries, isNotEmpty);

      expect(backend.authenticateCalls, 1);
      expect(backend.loadCalls, 1);
    });

    test('adds inventory — write-through to the inventory collection',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final unitsBefore = state.totalUnits;
      state.addInventoryItem(
        name: 'Wedding Arch — White',
        category: 'Furniture',
        totalStock: 4,
        ratePerDay: 35,
      );

      expect(state.inventory.first.name, 'Wedding Arch — White');
      expect(state.totalUnits, unitsBefore + 4);

      // Write-through: one create on the inventory collection + the
      // accompanying activity entry.
      final invWrites =
          backend.writes.where((w) => w.collection == 'inventory').toList();
      expect(invWrites, hasLength(1));
      expect(invWrites.single.isNew, isTrue);
      final actWrites =
          backend.writes.where((w) => w.collection == 'activities').toList();
      expect(actWrites, hasLength(1));
      expect(actWrites.single.data['body'],
          contains('added **Wedding Arch — White** to inventory'));
    });

    test('creates a booking for a customer — order, stock and customer '
        'stats all hit the cloud', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final chairs =
          state.inventory.firstWhere((i) => i.name == 'Folding Chairs');
      final availableBefore = chairs.available;
      const qty = 40;

      final orderId = state.createBooking(
        customerName: 'Avery Harper',
        eventName: 'Lakeside Charity Ball',
        eventDate: DateTime.now().add(const Duration(days: 10)),
        lines: [BookingLine(item: chairs, qty: qty)],
        notes: 'Deliver via loading dock A.',
      );

      // Local reactions are instant and consistent…
      expect(state.orderById(orderId), isNotNull);
      expect(state.orderById(orderId)!.status, OrderStatus.confirmed);
      expect(state.orderById(orderId)!.total, closeTo(qty * 1.50, 0.01));
      expect(
          state.inventory.firstWhere((i) => i.id == chairs.id).available,
          availableBefore - qty);

      // …and the customer stat line moved too.
      final avery = state.customerByName('Avery Harper')!;
      expect(avery.rentals, 9); // 8 in the cloud + this booking
      expect(avery.lifetimeSpend, closeTo(8420 + qty * 1.50, 0.01));

      // Write-through: order (new) + inventory (update) + customer
      // (update) + activity (new).
      expect(
          backend.writes.where((w) => w.collection == 'orders').map((w) => w.id),
          contains(orderId));
      expect(
          backend.writes
              .where((w) => w.collection == 'inventory')
              .map((w) => w.id),
          contains(chairs.id));
      expect(
          backend.writes
              .where((w) => w.collection == 'customers')
              .map((w) => w.id),
          contains(avery.id));
      expect(
          backend.writes.where((w) => w.collection == 'activities').length, 1);
    });

    test('previews the employee role but cannot self-promote back',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      state.navigate(Section.access);
      expect(state.section, Section.access);

      // Preview the employee experience…
      state.switchRole(UserRole.employee);
      expect(state.isOwner, isFalse);
      expect(state.canAccess(Section.reports), isFalse);

      // …and only sign-out/in restores owner powers.
      state.switchRole(UserRole.owner);
      expect(state.isOwner, isFalse);
    });

    test('opens a second workspace and switches between them', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      expect(state.isSingleWorkspace, isTrue);
      expect(state.addWorkspace('Cedar Loft Co.'), isTrue);
      expect(state.workspace, 'Cedar Loft Co.');
      expect(state.isSingleWorkspace, isFalse);

      // Both writes reached the cloud: the workspace doc + the
      // profile's activeWorkspace pointer.
      expect(
          backend.writes
              .where((w) => w.collection == 'workspaces')
              .map((w) => w.id),
          contains('cedar-loft-co'));
      expect(
          backend.writes.where((w) => w.collection == 'profiles').last.data['name'],
          'Cedar Loft Co.');

      state.switchWorkspace('Riverside Events');
      expect(state.workspace, 'Riverside Events');
    });
  });

  // ======================================================== EMPLOYEE
  group('EMPLOYEE journey — Jordan works the shift', () {
    test('signs in and is kept out of owner-only areas', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);

      final err = await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');
      expect(err, isNull);

      expect(state.isOwner, isFalse);
      expect(state.canAccess(Section.dashboard), isTrue);
      expect(state.canAccess(Section.inventory), isTrue);
      expect(state.canAccess(Section.orders), isTrue);
      expect(state.canAccess(Section.customers), isTrue);
      expect(state.canAccess(Section.activity), isTrue);
      expect(state.canAccess(Section.reports), isFalse);
      expect(state.canAccess(Section.access), isFalse);

      // Navigation to owner areas is refused outright.
      state.navigate(Section.reports);
      state.navigate(Section.access);
      expect(state.section, Section.dashboard);

      // No self-promotion, ever.
      state.switchRole(UserRole.owner);
      expect(state.isOwner, isFalse);
    });

    test('sees shift tasks derived from live cloud data', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final tasks = state.shiftTasks(DateTime.now());
      final kinds = tasks.map((t) => t.kind).toList();

      // 1 preparing → prep, 1 out-for-delivery → delivery,
      // 1 needs-payment → payment, plus 2 upcoming pickups → prep.
      expect(kinds.where((k) => k == 'prep'), hasLength(3));
      expect(kinds.where((k) => k == 'delivery'), hasLength(1));
      expect(kinds.where((k) => k == 'payment'), hasLength(1));
      expect(tasks.any((t) => t.title == 'Stage & pack'), isTrue);
      expect(tasks.any((t) => t.title == 'Confirm delivery'), isTrue);
      expect(tasks.any((t) => t.title == 'Collect payment'), isTrue);
    });

    test('moves an order through the pipeline — every status change is '
        'written through', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final order = state.orderById('RW-2051')!; // Northstar, preparing
      expect(order.status, OrderStatus.preparing);

      state.updateOrderStatus(order, OrderStatus.outForDelivery);
      expect(state.orderById('RW-2051')!.status,
          OrderStatus.outForDelivery);

      state.updateOrderStatus(
          state.orderById('RW-2051')!, OrderStatus.returned);
      expect(state.orderById('RW-2051')!.status, OrderStatus.returned);

      // Two status writes hit the orders collection with the right ids…
      final orderWrites =
          backend.writes.where((w) => w.collection == 'orders').toList();
      expect(orderWrites, hasLength(2));
      expect(orderWrites.every((w) => w.id == 'RW-2051'), isTrue);
      expect(orderWrites.last.data['status'], 'returned');

      // …and each change logged an activity entry.
      expect(
          backend.writes.where((w) => w.collection == 'activities').length, 2);
    });

    test('adds a customer and books their first rental', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      state.addCustomer(
        name: 'Nova Reyes',
        company: 'Reyes Ceramics',
        email: 'nova@reyesstudio.com',
        phone: '(555) 019-2277',
      );

      final nova = state.customerByName('nova reyes')!; // case-insensitive
      expect(nova.rentals, 0);
      expect(nova.lifetimeSpend, 0);

      final heaters =
          state.inventory.firstWhere((i) => i.name == 'Bistro Heaters');
      final availableBefore = heaters.available;

      final orderId = state.createBooking(
        customerName: 'Nova Reyes',
        eventName: 'Studio Opening Night',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        lines: [BookingLine(item: heaters, qty: 4)],
      );

      expect(state.ordersForCustomer('Nova Reyes'), hasLength(1));
      expect(state.customerByName('Nova Reyes')!.rentals, 1);
      expect(
          state.customerByName('Nova Reyes')!.lifetimeSpend,
          closeTo(4 * 8.00, 0.01));
      expect(
          state.inventory.firstWhere((i) => i.id == heaters.id).available,
          availableBefore - 4);

      expect(
          backend.writes.where((w) => w.collection == 'customers').length, 2);
      expect(
          backend.writes.where((w) => w.collection == 'orders').map((w) => w.id),
          contains(orderId));
    });
  });

  // ======================================================== CUSTOMER
  group('CUSTOMER journey — Nova Reyes rents over time', () {
    test('first booking creates history; repeat bookings accumulate',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      // The owner serves the customer (customers are workspace records,
      // not app sign-ins).
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      state.addCustomer(
        name: 'Nova Reyes',
        company: 'Reyes Ceramics',
        email: 'nova@reyesstudio.com',
        phone: '(555) 019-2277',
      );

      final lights =
          state.inventory.firstWhere((i) => i.name == 'String Lights');
      final availableBefore = lights.available;

      // --- Rental 1
      final id1 = state.createBooking(
        customerName: 'Nova Reyes',
        eventName: 'Pop-up Market',
        eventDate: DateTime.now().add(const Duration(days: 5)),
        lines: [BookingLine(item: lights, qty: 6)],
      );
      expect(state.ordersForCustomer('Nova Reyes'), hasLength(1));
      final nova1 = state.customerByName('Nova Reyes')!;
      expect(nova1.rentals, 1);
      expect(nova1.lifetimeSpend, closeTo(6 * 12.00, 0.01));
      expect(nova1.lastBooking.day, DateTime.now().day);

      // --- Rental 2 (a returning customer)
      final tables =
          state.inventory.firstWhere((i) => i.name == '6ft Round Tables');
      final id2 = state.createBooking(
        customerName: 'Nova Reyes',
        eventName: 'Holiday Party',
        eventDate: DateTime.now().add(const Duration(days: 30)),
        lines: [BookingLine(item: tables, qty: 3)],
      );

      final nova2 = state.customerByName('Nova Reyes')!;
      expect(nova2.rentals, 2);
      expect(nova2.lifetimeSpend, closeTo(6 * 12.00 + 3 * 6.00, 0.01));
      expect(state.ordersForCustomer('Nova Reyes'), hasLength(2));
      expect({id1, id2}.length, 2, reason: 'order ids must be unique');

      // Availability was decremented once per booking.
      expect(
          state.inventory.firstWhere((i) => i.id == lights.id).available,
          availableBefore - 6);

      // Recent customers are not on the follow-up shortlist.
      expect(state.followUpsCount, isNot(equals(0)));
      final followUps = state.customers
          .where((c) =>
              c.lastBooking
                  .isBefore(DateTime.now().subtract(const Duration(days: 30))))
          .map((c) => c.name);
      expect(followUps, isNot(contains('Nova Reyes')));

      // Every booking reached the cloud, twice — once per order.
      final orderWrites = backend.writes
          .where((w) => w.collection == 'orders')
          .map((w) => w.id)
          .toSet();
      expect(orderWrites, containsAll([id1, id2]));
    });

    test('returned orders do not silently restock — manual stock fix is '
        'written through', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final lights =
          state.inventory.firstWhere((i) => i.name == 'String Lights');
      final before = lights.available;

      final id = state.createBooking(
        customerName: 'Nova Reyes',
        eventName: 'Gallery Night',
        eventDate: DateTime.now().add(const Duration(days: 2)),
        lines: [BookingLine(item: lights, qty: 5)],
      );
      expect(
          state.inventory.firstWhere((i) => i.id == lights.id).available,
          before - 5);

      // Event happens, items come back: the employee marks the order
      // returned and manually restocks after count verification.
      state.updateOrderStatus(state.orderById(id)!, OrderStatus.returned);
      expect(
          state.inventory.firstWhere((i) => i.id == lights.id).available,
          before - 5,
          reason: 'returning an order must never auto-restock');

      final item = state.inventory.firstWhere((i) => i.id == lights.id);
      state.adjustStock(item, available: before);
      expect(
          state.inventory.firstWhere((i) => i.id == lights.id).available,
          before);

      // Both the status change and the manual restock hit the cloud.
      expect(
          backend.writes.where((w) => w.collection == 'orders').map((w) => w.id),
          contains(id));
      expect(
          backend.writes
              .where((w) => w.collection == 'inventory')
              .map((w) => w.id),
          contains(lights.id));
    });
  });

  // ============================================== NO-DEMO GUARANTEES
  group('no-demo guarantees — the app is honest about the cloud', () {
    test('a fresh store is EMPTY — nothing is bundled', () {
      final state = WorkspaceState();
      expect(state.inventory, isEmpty);
      expect(state.orders, isEmpty);
      expect(state.customers, isEmpty);
      expect(state.activity, isEmpty);
      expect(state.pickups, isEmpty);
      expect(state.earnings, isEmpty);
      expect(state.revenueTrend, isEmpty);
      expect(state.categorySeries, isEmpty);
      expect(state.workspaces, isEmpty);
      expect(state.workspace, isEmpty);
      expect(state.monthGrossRevenueK, 0);
      expect(state.utilization, 0);
      expect(state.isSignedIn, isFalse);
    });

    test('sign-in without a configured backend fails — no demo fallback',
        () async {
      final state = WorkspaceState();
      final err = await state.signInWithEmail('anyone@example.com', 'pw');
      expect(err, isNotNull);
      expect(err, contains('Appwrite'));
      expect(state.isSignedIn, isFalse);
      expect(state.inventory, isEmpty, reason: 'no data may appear');
    });

    test('wrong password surfaces the Appwrite error verbatim', () async {
      final state = WorkspaceState(backend: RecordingBackend());
      final err =
          await state.signInWithEmail(SampleDataset.demoOwner.email, 'nope');
      expect(err, isNotNull);
      expect(err, contains('Email or password is incorrect'));
      expect(state.isSignedIn, isFalse);
      expect(state.inventory, isEmpty);
    });

    test('cloud load failure after auth — error surfaces, nothing faked',
        () async {
      final backend = RecordingBackend()..failLoad = true;
      final state = WorkspaceState(backend: backend);
      final err =
          await state.signInWithEmail(SampleDataset.demoOwner.email, 'owner-pass');
      expect(err, isNotNull, reason: 'load failure must not be swallowed');
      expect(state.isSignedIn, isFalse);
      expect(state.inventory, isEmpty);
    });

    test('an empty cloud workspace renders empty — no Riverside leak',
        () async {
      final empty = RecordingBackend(
        snapshot: const WorkspaceSnapshot(
          accountUserId: 'u',
          inventory: [],
          orders: [],
          customers: [],
          activity: [],
          pickups: [],
          workspaces: [],
          activeWorkspace: '',
          grossMonthK: 0,
          utilizationPct: 0,
          earnings: [],
          categoryRevenue: [],
          trend: [],
        ),
      );
      final state = WorkspaceState(backend: empty);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      expect(state.isSignedIn, isTrue);
      expect(state.inventory, isEmpty);
      expect(state.orders, isEmpty);
      expect(state.customers, isEmpty);
      // A brand-new cloud gets ONE honest starter workspace for its
      // bootstrap owner — created via the real addWorkspace write path
      // (the document actually exists in the cloud afterwards), while
      // every business collection stays genuinely empty.
      expect(state.workspaces, ["Olivia's Workspace"]);
      expect(
        empty.writes.where((w) => w.collection == 'workspaces'),
        isNotEmpty,
      );
      expect(
        empty.writes.where((w) =>
            w.collection == 'inventory' ||
            w.collection == 'orders' ||
            w.collection == 'customers'),
        isEmpty,
      );
      expect(state.monthGrossRevenueK, 0);
    });
  });
}
