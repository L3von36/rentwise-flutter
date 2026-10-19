import 'package:flutter_test/flutter_test.dart';

import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/rental_order.dart'
    show OrderStatus, OrderStatusX, kOrderTransitions;
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
      expect(state.monthGrossRevenueK, 289.0);
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
      expect(state.orderById(orderId)!.total, closeTo(qty * 20.0, 0.01)); // Br rates
      expect(
          state.inventory.firstWhere((i) => i.id == chairs.id).available,
          availableBefore - qty);

      // …and the customer stat line moved too.
      final avery = state.customerByName('Avery Harper')!;
      expect(avery.rentals, 2); // 1 seeded order + this booking
      expect(avery.lifetimeSpend, closeTo(7720 + qty * 20.0, 0.01)); // Br

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

      // The workspace document reached the cloud, and the active-
      // workspace pointer went to the user's own user_prefs document —
      // profiles are create-once and never updated by the client.
      expect(
          backend.writes
              .where((w) => w.collection == 'workspaces')
              .map((w) => w.id),
          contains('cedar-loft-co'));
      expect(
          backend.writes
              .where((w) => w.collection == 'user_prefs')
              .isNotEmpty,
          isTrue,
          reason: 'active workspace must persist to user_prefs');

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
      expect(tasks.any((t) => t.title == 'Expect return'), isTrue);
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
          closeTo(4 * 120.0, 0.01)); // Br rates
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
      expect(nova1.lifetimeSpend, closeTo(6 * 100.0, 0.01)); // Br rates
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
      expect(nova2.lifetimeSpend, closeTo(6 * 100.0 + 3 * 80.0, 0.01)); // Br
      expect(state.ordersForCustomer('Nova Reyes'), hasLength(2));
      expect({id1, id2}.length, 2, reason: 'order ids must be unique');

      // Availability was decremented once per booking.
      expect(
          state.inventory.firstWhere((i) => i.id == lights.id).available,
          availableBefore - 6);

      // Every seeded customer booked within the last month, so the
      // follow-up shortlist stays empty — and certainly never suggests
      // a customer who just booked.
      expect(state.followUpsCount, 0,
          reason: 'all seeded customers booked within the last 30 days');
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

  // ================================================== RBAC GUARANTEES
  group('RBAC guarantees — permission matrix, denials, honest sync', () {
    test('owner holds every capability in the matrix', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      expect(state.role.canOperateRentals, isTrue);
      expect(state.role.canAdjustStock, isTrue);
      expect(state.role.canManageCustomers, isTrue);
      expect(state.role.canCreateInventory, isTrue);
      expect(state.role.canDeleteInventory, isTrue);
      expect(state.role.canEditPricing, isTrue);
      expect(state.role.canViewReports, isTrue);
      expect(state.role.canViewFinancials, isTrue);
      expect(state.role.canExportReports, isTrue);
      expect(state.role.canExportCustomersCsv, isTrue);
      expect(state.role.canManageTeam, isTrue);
      expect(state.role.canChangeSettings, isTrue);
      expect(state.role.canManageWorkspaces, isTrue);
    });

    test('a failed cloud write is SURFACED, never pretended successful',
        () async {
      final backend = RecordingBackend()..failWrites = true;
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      state.addInventoryItem(
        name: 'Ghost Chair',
        category: 'Seating',
        totalStock: 2,
        ratePerDay: 7,
      );

      // The mutation is applied locally but the sync failure raises a
      // user-facing error notice.
      expect(state.inventory.first.name, 'Ghost Chair');
      // give the fire-and-forget push a tick to land
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(state.lastNotice, isNotNull,
          reason: 'write failure must be emitted');
      expect(state.lastNotice!.isError, isTrue);
      expect(state.lastNotice!.message, contains('Cloud sync failed'));
    });

    test('an unprovisioned account is refused with the provisioning hint',
        () async {
      // Credentials are fine but the PROFILE is missing — exactly what
      // the real backend returns when profiles lookup fails and the
      // bootstrap rule cannot run (e.g. profiles collection unreadable).
      final backend = _NoProfileBackend();
      final state = WorkspaceState(backend: backend);
      final err = await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      expect(err, isNotNull);
      expect(err, contains('not added to a RentWise workspace yet'));
      expect(err, contains('Employee accounts are created by the workspace owner'));
      expect(state.isSignedIn, isFalse,
          reason: 'no profile → no workspace, no demo fallback');
      expect(state.inventory, isEmpty);
    });

    test('owner creates employee accounts from the dashboard — and '
        'self-registration stays closed', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      // Team directory loaded at sign-in (owner first).
      expect(state.team, isNotEmpty);
      expect(state.team.first.role, UserRole.owner);
      final teamBefore = state.team.length;

      final err = await state.addEmployee(
        name: 'Sam Staff',
        email: 'sam@rentwise.app',
        password: 'strong-pass-9',
        title: 'Warehouse lead',
      );
      expect(err, isNull, reason: 'owner may create employee accounts');
      expect(state.team.length, teamBefore + 1);
      final sam = state.team.last;
      expect(sam.role, UserRole.employee);
      expect(sam.title, 'Warehouse lead');

      // The profile document was written to the cloud with role employee.
      final profileWrite = backend.writes.firstWhere(
        (w) => w.collection == 'profiles' && w.id == 'sam@rentwise.app',
      );
      expect(profileWrite.isNew, isTrue);
      expect(profileWrite.data['role'], 'employee');

      // The action is logged like every other business action.
      expect(
        state.activity.any((a) =>
            a.body.contains('employee account') &&
            a.body.contains('Sam Staff')),
        isTrue,
      );

      // The new employee can now SIGN IN (no self-service sign-up needed).
      final freshState = WorkspaceState(backend: backend);
      final signInErr = await freshState.signInWithEmail(
          'sam@rentwise.app', 'strong-pass-9');
      expect(signInErr, isNull);
      expect(freshState.isOwner, isFalse);
      expect(freshState.canAccess(Section.access), isFalse);

      // …while SELF-registration remains closed for anyone else.
      final signUpErr = await freshState.signUpWithEmail(
          'Mallory', 'mallory@example.com', 'strong-pass-8');
      expect(signUpErr, isNotNull);
      expect(signUpErr, contains('Registration is closed'));
    });

    test('employees can NEVER create employee accounts (capability guard)',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final err = await state.addEmployee(
        name: 'Backdoor Bob',
        email: 'bob@example.com',
        password: 'strong-pass-7',
      );
      expect(err, isNotNull);
      expect(err, contains('Owner access required'));
      // The denial is a visible, honest notice — never silent.
      expect(state.lastNotice, isNotNull);
      expect(state.lastNotice!.isError, isTrue);
      // Nothing was written and the team is not even loaded for staff.
      expect(
        backend.writes.where(
            (w) => w.collection == 'profiles' && w.id == 'bob@example.com'),
        isEmpty,
      );
    });

    test('weak employee password is rejected before any profile write',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final err = await state.addEmployee(
        name: 'Shorty Staff',
        email: 'shorty@example.com',
        password: 'short',
      );
      expect(err, isNotNull);
      expect(err, contains('at least 8 characters'));
      expect(
        backend.writes.where(
            (w) =>
                w.collection == 'profiles' &&
                w.id == 'shorty@example.com'),
        isEmpty,
      );
    });

    test('owner promotes an employee to owner, edits titles — and the '
        'last owner cannot be demoted', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final emp =
          state.team.firstWhere((m) => m.role == UserRole.employee);
      final err = await state.updateTeamMember(
        emp,
        newRole: UserRole.owner,
        title: 'Co-manager',
      );
      expect(err, isNull);
      expect(state.team.where((m) => m.role == UserRole.owner).length, 2);
      final promoted =
          state.team.firstWhere((m) => m.userId == emp.userId);
      expect(promoted.role, UserRole.owner);
      expect(promoted.title, 'Co-manager');
      final write = backend.writes
          .firstWhere((w) => w.collection == 'profiles' && w.id == emp.userId);
      expect(write.data['role'], 'owner');
      expect(write.data['title'], 'Co-manager');
      // Promotion is activity-logged.
      expect(
        state.activity
            .any((a) => a.body.contains('promoted') && a.body.contains(emp.name)),
        isTrue,
      );

      // With two owners a demotion is allowed…
      final err2 =
          await state.updateTeamMember(promoted, newRole: UserRole.employee);
      expect(err2, isNull);
      expect(
        state.team.firstWhere((m) => m.userId == emp.userId).role,
        UserRole.employee,
      );

      // …but the LAST owner can never be demoted. (Here the last owner
      // is the signed-in owner, so the self-guard speaks first; the
      // state ALSO refuses the demotion of a last owner via the
      // 'At least one owner' check — defense in depth — and the edit
      // dialog disables the option entirely.)
      final lastOwner =
          state.team.firstWhere((m) => m.role == UserRole.owner);
      final err3 = await state.updateTeamMember(
        lastOwner,
        newRole: UserRole.employee,
      );
      expect(err3, isNotNull);
      expect(
        state.team.where((m) => m.role == UserRole.owner).length,
        1,
        reason: 'the demotion must not have gone through',
      );
    });

    test('you cannot change your own role, and employees cannot edit '
        'the team at all', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final me = state.team
          .firstWhere((m) => m.userId == state.account!.userId);
      final err = await state.updateTeamMember(me, newRole: UserRole.employee);
      expect(err, isNotNull);
      expect(err, contains('your own role'));

      final employeeState = WorkspaceState(backend: backend);
      await employeeState.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');
      final someone = employeeState.team.isEmpty
          ? const Account(
              name: 'x',
              email: 'x@example.com',
              role: UserRole.employee,
              initials: 'X',
              title: '',
              userId: 'u-x')
          : employeeState.team.first;
      final err2 =
          await employeeState.updateTeamMember(someone, newRole: UserRole.owner);
      expect(err2, contains('Owner access required'));
      expect(employeeState.lastNotice!.isError, isTrue);
    });

    test('owner resets an employee password via the function; everyone '
        'rotates their own password with the current one', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final emp =
          state.team.firstWhere((m) => m.role == UserRole.employee);
      final weak = await state.resetTeamMemberPassword(emp, 'short');
      expect(weak, contains('at least 8 characters'));

      final err = await state.resetTeamMemberPassword(emp, 'brand-new-pass');
      expect(err, isNull);
      final fnWrite = backend.writes
          .firstWhere((w) => w.collection == 'functions');
      expect(fnWrite.id, 'reset-password');
      expect(fnWrite.data['userId'], emp.userId);

      // Self-service: wrong current password is refused…
      final err2 = await state.changeMyPassword('wrong-current', 'another-pass-1');
      expect(err2, contains('Current password is incorrect.'));
      // …the correct one rotates it, and the NEW password signs in.
      final err3 = await state.changeMyPassword('owner-pass', 'another-pass-1');
      expect(err3, isNull);
      final freshState = WorkspaceState(backend: backend);
      final signInErr =
          await freshState.signInWithEmail(SampleDataset.demoOwner.email,
              'another-pass-1');
      expect(signInErr, isNull);
      expect(freshState.isSignedIn, isTrue);
    });

    test('stock invariants — availability clamped, negative stock impossible',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      final item = state.inventory.first;
      state.adjustStock(item, available: -5);
      expect(state.inventory.firstWhere((i) => i.id == item.id).available, 0,
          reason: 'negative availability must clamp to 0');

      state.adjustStock(item, available: item.totalStock + 999);
      expect(state.inventory.firstWhere((i) => i.id == item.id).available,
          item.totalStock,
          reason: 'availability can never exceed total stock');

      state.adjustStock(item, totalStock: -3);
      expect(state.inventory.firstWhere((i) => i.id == item.id).totalStock, 0,
          reason: 'negative total stock must clamp to 0');
    });

    test('payment flow: needsPayment → confirmed reads as payment accepted',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final pending =
          state.orders.firstWhere((o) => o.status == OrderStatus.needsPayment);
      // The offered action for a pending order is the CONFIRMED
      // transition, labelled 'Accept payment'.
      expect(OrderStatus.confirmed.actionLabel, 'Accept payment');
      expect(
          kOrderTransitions[pending.status], contains(OrderStatus.confirmed));

      final ok = state.updateOrderStatus(pending, OrderStatus.confirmed);
      expect(ok, isTrue);
      expect(state.orderById(pending.id)!.status, OrderStatus.confirmed);

      // The write hit the orders collection with the accepted status…
      final write = backend.writes
          .where((w) => w.collection == 'orders')
          .lastWhere((w) => w.id == pending.id);
      expect(write.data['status'], 'confirmed');
      // …and an activity entry was logged.
      expect(
          backend.writes
              .where((w) => w.collection == 'activities')
              .map((w) => w.data['body']),
          contains(contains('payment accepted')));
    });

    test('illegal lifecycle jumps are rejected with an error notice',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      final returned =
          state.orders.firstWhere((o) => o.status == OrderStatus.returned);
      final ok = state.updateOrderStatus(returned, OrderStatus.confirmed);
      expect(ok, isFalse, reason: 'returned is terminal — no resurrection');
      expect(state.orderById(returned.id)!.status, OrderStatus.returned);
      expect(state.lastNotice?.isError, isTrue);

      final confirmed =
          state.orders.firstWhere((o) => o.status == OrderStatus.confirmed);
      expect(state.updateOrderStatus(confirmed, OrderStatus.returned), isFalse,
          reason: 'confirmed → returned skips the lifecycle');
    });

    test('employee can operate but can NEVER extend the catalog or manage workspaces',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      // Capability matrix — operational yes, business no.
      expect(state.role.canOperateRentals, isTrue);
      expect(state.role.canAdjustStock, isTrue);
      expect(state.role.canManageCustomers, isTrue);
      expect(state.role.canCreateInventory, isFalse);
      expect(state.role.canDeleteInventory, isFalse);
      expect(state.role.canEditPricing, isFalse);
      expect(state.role.canViewReports, isFalse);
      expect(state.role.canViewFinancials, isFalse);
      expect(state.role.canManageTeam, isFalse);
      expect(state.role.canChangeSettings, isFalse);
      expect(state.role.canManageWorkspaces, isFalse);

      // Stock adjustment is allowed and written through.
      final chairs = state.inventory.first;
      state.adjustStock(chairs, available: chairs.available - 1);
      expect(
          state.inventory.firstWhere((i) => i.id == chairs.id).available,
          chairs.available - 1);
      expect(
          backend.writes
              .where((w) => w.collection == 'inventory')
              .map((w) => w.id),
          contains(chairs.id));

      // Catalog growth is refused at the STATE level — no new item,
      // no cloud write, and a clear denial notice is emitted.
      final itemsBefore = state.inventory.length;
      state.addInventoryItem(
          name: 'Ghost Item', category: 'Seating', totalStock: 5, ratePerDay: 9);
      expect(state.inventory.length, itemsBefore,
          reason: 'employee addInventoryItem must be a no-op');
      expect(state.lastNotice?.isError, isTrue);
      expect(state.lastNotice?.message, contains('Owner access required'));

      // Workspace management is refused the same way.
      expect(state.addWorkspace('Shadow Ops'), isFalse);
      expect(state.workspaces, isNot(contains('Shadow Ops')));
      state.switchWorkspace('Another Place');
      expect(state.workspace, 'Riverside Events');
    });
  });
}

/// Stand-in that mimics an unprovisioned account: credentials are fine
/// but the profile lookup finds nothing.
class _NoProfileBackend extends RecordingBackend {
  @override
  Future<Account> authenticate(String email, String password) async {
    throw NoProfileException();
  }
}
