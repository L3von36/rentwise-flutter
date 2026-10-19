import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart'
    show
        Axis,
        BuildContext,
        Icons,
        IconData,
        Material,
        MaterialApp,
        NavigationDrawer,
        Navigator,
        Scaffold,
        SingleChildScrollView,
        Size,
        SizedBox,
        TextField,
        Text,
        Theme,
        ThemeMode,
        Widget;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rentwise/app.dart';
import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/rental_order.dart' show OrderStatus;
import 'package:rentwise/state/shell_state.dart';
import 'package:rentwise/state/workspace_state.dart';
import 'package:rentwise/widgets/bottom_nav.dart';
import 'package:rentwise/widgets/kpi_card.dart' show KpiStrip, KpiTileMini;
import 'package:rentwise/widgets/side_nav.dart';
import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';
import 'package:rentwise/widgets/window_title_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full provider stack matching production bootstrap.
Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => WorkspaceState(backend: RecordingBackend())),
        ChangeNotifierProvider(create: (_) => ShellState()),
      ],
      child: const RentWiseApp(),
    );

/// Types real credentials into the auth form and submits — exactly what
/// a live user does (no persona shortcuts exist anymore).
Future<void> _signInUi(
    WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

/// Plain unit test (no fake async) — exercises the store directly.
void main() {
  initTestCloud(); // path-provider shim BEFORE any Appwrite client exists

  test('sign-in without a backend fails honestly — no demo fallback', () async {
    final state = WorkspaceState();
    final err =
        await state.signInWithEmail('jordan@riverside.events', 'whatever');
    expect(err, isNotNull);
    expect(err, contains('Appwrite'));
    expect(state.isSignedIn, isFalse);
    expect(state.authError, isNotNull);
  });

  test('booking creation decrements availability, appends order, logs activity',
      () async {
    final backend = RecordingBackend();
    final state = WorkspaceState(backend: backend);
    await state.signInWithEmail(
        SampleDataset.demoEmployee.email, 'employee-pass');

    final chairs = state.inventory.firstWhere((i) => i.name == 'Folding Chairs');
    final availableBefore = chairs.available;
    final ordersBefore = state.orders.length;
    final activityBefore = state.activity.length;

    state.createBooking(
      customerName: 'Avery Harper',
      eventName: 'Test Gala',
      eventDate: DateTime.now().add(const Duration(days: 3)),
      lines: [BookingLine(item: chairs, qty: 10)],
    );

    expect(
      state.inventory.firstWhere((i) => i.id == chairs.id).available,
      availableBefore - 10,
    );
    expect(state.orders.length, ordersBefore + 1);
    expect(state.activity.length, activityBefore + 1);
    expect(state.orders.first.eventName, 'Test Gala');
  });

  test('employees are restricted: no owner areas, no self-promotion',
      () async {
    final state = WorkspaceState(backend: RecordingBackend());
    await state.signInWithEmail(
        SampleDataset.demoEmployee.email, 'employee-pass');

    expect(state.isOwner, isFalse);

    // Owner-only areas are permission-gated.
    expect(state.canAccess(Section.reports), isFalse);
    expect(state.canAccess(Section.access), isFalse);
    state.navigate(Section.reports);
    state.navigate(Section.access);
    expect(state.section, Section.dashboard); // navigation refused

    // An employee can never promote themselves to owner.
    state.switchRole(UserRole.owner);
    expect(state.isOwner, isFalse);
    expect(state.account!.name, 'Jordan Miller');

    // Day-to-day sections stay open.
    expect(state.canAccess(Section.inventory), isTrue);
    expect(state.canAccess(Section.orders), isTrue);
    state.navigate(Section.orders);
    expect(state.section, Section.orders);
  });

  test('owner manages access and can preview the employee role', () async {
    final state = WorkspaceState(backend: RecordingBackend());
    await state.signInWithEmail(
        SampleDataset.demoOwner.email, 'owner-pass');

    expect(state.isOwner, isTrue);
    expect(state.canAccess(Section.reports), isTrue);
    expect(state.canAccess(Section.access), isTrue);
    state.navigate(Section.access);
    expect(state.section, Section.access);

    // Owner previews the employee experience...
    state.switchRole(UserRole.employee);
    expect(state.isOwner, isFalse);
    // ...and is dropped onto a section the employee role may open.
    expect(state.section, Section.dashboard);

    // But the preview session cannot switch back — only owners manage
    // access, so sign out/in is required.
    state.switchRole(UserRole.owner);
    expect(state.isOwner, isFalse);
  });

  testWidgets('sign-in as employee lands on the operations dashboard',
      (tester) async {
    // Desktop surface (matching the 1440×900 design pack).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Auth screen visible
    expect(find.text('Welcome back'), findsOneWidget);

    // Sign in through the real email/password flow.
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    // Dashboard visible — employee gets the task-first shift view.
    expect(find.text('Operations overview'), findsWidgets); // top-bar breadcrumb
    expect(find.text('Your task list'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    // Financial/owner-only widgets stay hidden from employees.
    expect(find.text('Month to date'), findsNothing);
    expect(find.text('Business Open'), findsNothing);

    // ---- task-list filters narrow the list live
    expect(find.text('All · 5'), findsOneWidget);
    await tester.tap(find.text('Payments · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Collect payment'), findsOneWidget);
    expect(find.text('Stage & pack'), findsNothing);
    expect(find.text('Pull & stage'), findsNothing);
    await tester.tap(find.text('Prep · 3'));
    await tester.pumpAndSettle();
    expect(find.text('Stage & pack'), findsOneWidget);
    expect(find.text('Pull & stage'), findsNWidgets(2)); // two pickups
    expect(find.text('Collect payment'), findsNothing);
    await tester.tap(find.text('All · 5'));
    await tester.pumpAndSettle();
    expect(find.text('Stage & pack'), findsOneWidget);

    // Employee quick actions differ from owner shortcuts.
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);

    // Privilege separation: owner destinations never render for staff.
    expect(find.text('Access & roles'), findsNothing);
    expect(find.text('Settings'), findsNothing);

    // Inventory is open to employees, but catalog management is not.
    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Inventory'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add inventory'), findsNothing);
  });

  testWidgets('sign-in as owner lands on the business-pulse dashboard',
      (tester) async {
    // Desktop surface (matching the 1440×900 design pack).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Sign in as the owner account through the real flow.
    await _signInUi(tester, SampleDataset.demoOwner.email, 'owner-pass');

    // Owner sees the financial pulse + earnings chart, not the shift view.
    expect(find.text('Month to date'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('Earnings overview'), findsOneWidget);
    expect(find.text('TOP CATEGORIES'), findsOneWidget); // Eyebrow uppercases
    expect(find.text('Business Open'), findsOneWidget);
    // Owner quick actions = business levers.
    expect(find.text('Access & roles'), findsWidgets); // sidebar + quick tile
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Record payment'), findsNothing);
    expect(find.text('Your task list'), findsNothing);
    expect(find.text('My recent actions'), findsNothing);

    // Catalog management is an owner privilege.
    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Inventory'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add inventory'), findsOneWidget);
  });

  testWidgets('phone viewport shows bottom app nav instead of drawer',
      (tester) async {
    // Phone surface (matching the 390×844 design pack).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    // Bottom nav tabs exist and the workspace is visible.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('More'), findsOneWidget);
    // Employee phone home = shift view (role-differentiated dashboard).
    expect(find.textContaining(', Jordan'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Business Open'), findsNothing);
    // No hamburger / drawer chrome on phones.
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing);

    // Center ＋ opens the booking sheet.
    await tester.tap(find.descendant(
      of: find.byType(RentWiseBottomNav),
      matching: find.byIcon(Icons.add_rounded),
    ));
    await tester.pumpAndSettle();
    // Title appears in the sheet header (a "New booking" button may
    // also exist on the underlying screen, so allow multiple hits).
    expect(find.text('New rental booking'), findsWidgets);

    // More sheet exposes secondary sections — but the access console
    // and reports stay owner-only, so an employee never sees them.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Activity Log'), findsWidgets);
    expect(find.text('Access & roles'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('desktop keyboard shortcuts drive the workspace',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    // Ctrl+K opens the global search dialog.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Search items, orders, or customers…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Ctrl+B opens the new-rental booking sheet.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('New rental booking'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // Ctrl+3 jumps straight to the Orders section.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Orders'), findsWidgets);

    // Ctrl+/ opens the shortcuts help panel.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
  });

  testWidgets('desktop title bar drives dark mode (frameless shell)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    try {
      // Simulate a Windows desktop build: custom title bar must render.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Custom frameless caption is present on the auth screen too.
    final bar = find.byType(WindowTitleBar);
    expect(bar, findsOneWidget);
    expect(find.text('RentWise'), findsWidgets);
    Finder inBar(IconData icon) {
      return find.descendant(of: bar, matching: find.byIcon(icon));
    }
    expect(inBar(Icons.minimize_rounded), findsOneWidget);
    expect(inBar(Icons.crop_square_rounded), findsOneWidget);
    expect(inBar(Icons.close_rounded), findsOneWidget);

    // Theme toggle flips the whole app to dark.
    BuildContext scaffoldCtx() => tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffoldCtx()).brightness, Brightness.light);
    expect(inBar(Icons.dark_mode_rounded), findsOneWidget);
    await tester.tap(inBar(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    expect(Theme.of(scaffoldCtx()).brightness, Brightness.dark);
    expect(inBar(Icons.light_mode_rounded), findsOneWidget);

    // Dark surfaces actually painted: scaffold background is the dark canvas.
    final material = tester.widget<Material>(
      find.descendant(
          of: find.byType(WindowTitleBar), matching: find.byType(Material)),
    );
    expect(material.color, const Color(0xFF0E121C)); // DarkTokens.sidebar

    // Sign in — dark mode survives the route change and the toggle is
    // available to every role (title bar is window chrome, not owner-only).
    await tester.tap(inBar(Icons.light_mode_rounded));
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');
    expect(find.byType(WindowTitleBar), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(WindowTitleBar),
            matching: find.byIcon(Icons.dark_mode_rounded)),
        findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('theme preference persists across sessions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = ShellState(prefs: prefs);
    expect(first.themeSetting, AppThemeSetting.system);
    expect(first.isDark, isFalse);

    first.setThemeSetting(AppThemeSetting.dark);
    expect(first.isDark, isTrue);

    // A fresh controller (app relaunch) restores the saved choice.
    final second = ShellState(prefs: prefs);
    expect(second.themeSetting, AppThemeSetting.dark);
    expect(second.isDark, isTrue);
    expect(second.themeMode, ThemeMode.dark);

    second.toggleTheme();
    expect(ShellState(prefs: prefs).themeSetting, AppThemeSetting.light);
  });

  testWidgets('orders status filters narrow the live list', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoOwner.email, 'owner-pass');

    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Orders'),
    ));
    await tester.pumpAndSettle();

    // Status chips render with live, tab-scoped counts (5 seeded orders,
    // one per status).
    expect(find.text('All · 5'), findsOneWidget);
    expect(find.text('Preparing · 1'), findsOneWidget);
    expect(find.text('Out for delivery · 1'), findsOneWidget);
    expect(find.text('Needs payment · 1'), findsOneWidget);
    expect(find.text('Returned · 1'), findsOneWidget);

    // Narrow to needs payment: only the Monroe order remains.
    await tester.tap(find.text('Needs payment · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Monroe Family Reunion'), findsOneWidget);
    expect(find.text('Northstar Product Launch'), findsNothing);
    expect(find.text('The Harper Wedding'), findsNothing);

    // Filters compose with tabs: Completed + needsPayment = empty.
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('No orders in this view.'), findsOneWidget);

    // Back to All orders keeps the status chip; clearing via All restores.
    await tester.tap(find.text('All orders'));
    await tester.pumpAndSettle();
    expect(find.text('Monroe Family Reunion'), findsOneWidget);
    await tester.tap(find.text('All · 5'));
    await tester.pumpAndSettle();
    expect(find.text('Northstar Product Launch'), findsOneWidget);
    expect(find.text('Brighton Arts Gala'), findsOneWidget);
  });

  testWidgets('owner phone home opens on the business-pulse hero',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _signInUi(tester, SampleDataset.demoOwner.email, 'owner-pass');

    // Compact owner hero replaces the plain header + banner: gradient
    // panel with greeting, glass avatar and live status pills.
    expect(find.textContaining('Welcome back, '), findsOneWidget);
    expect(find.textContaining('Open · closes'), findsOneWidget);
    expect(find.textContaining('active rentals'), findsOneWidget);
    // The wide-only "Business Open" banner stays off the phone layout.
    expect(find.text('Business Open'), findsNothing);

    // Glance strip still anchors the screen below the hero — and stays
    // honest: tile values come from live workspace getters (the old
    // hardcoded '24' / '8' are gone), and the strip renders as a
    // swipeable KpiStrip with a scroll affordance instead of squeezing
    // three Expanded tiles into unreadable thirds.
    expect(find.text("Today's revenue"), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('24'), findsNothing);
    expect(find.text('8'), findsNothing);
    final state = tester.state(find.byType(Navigator)).context
        .read<WorkspaceState>();
    final activeTile = find.ancestor(
        of: find.text('Active rentals'), matching: find.byType(KpiTileMini));
    expect(
        find.descendant(
            of: activeTile, matching: find.text('${state.openOrdersCount}')),
        findsOneWidget);
    final returnsTile = find.ancestor(
        of: find.text('Pending returns'), matching: find.byType(KpiTileMini));
    expect(
        find.descendant(
            of: returnsTile,
            matching: find.text('${state.returnsTodayCount}')),
        findsOneWidget);

    // 390px < 3 × 124px tiles + gaps: the strip becomes a horizontal
    // scroll view (fade affordance), and swiping left reveals the tail.
    final kpiStrip = find.byType(KpiStrip);
    expect(kpiStrip, findsOneWidget);
    final hScroll = find.descendant(
        of: kpiStrip,
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView &&
            w.scrollDirection == Axis.horizontal));
    expect(hScroll, findsOneWidget);
    await tester.drag(hScroll, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('KpiStrip lays out as a plain row when tiles all fit',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          child: KpiStrip(children: [Text('A'), Text('B'), Text('C')]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // No overflow → no scroll view, tiles share the width like Expandeds.
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('tapping an order row opens its detail page', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Orders'),
    ));
    await tester.pumpAndSettle();

    // Row tap → full detail page with the quoted manifest + notes.
    await tester.tap(find.text('Northstar Product Launch'));
    await tester.pumpAndSettle();
    expect(find.text('Item manifest'), findsOneWidget);
    expect(find.text('Delivery notes'), findsOneWidget);
    expect(find.text('Order RW-2051'), findsOneWidget);
    expect(find.text('Folding Chairs'), findsWidgets);

    // Status actions write through to the store — the button uses the
    // action label ('Mark dispatched'), not the status label.
    await tester.tap(find.text('Mark dispatched'));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(Navigator)).context
        .read<WorkspaceState>();
    expect(
      state.orderById('RW-2051')!.status,
      OrderStatus.outForDelivery,
    );
  });

  testWidgets('view customer insights opens the insights page',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoOwner.email, 'owner-pass');

    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Customers'),
    ));
    await tester.pumpAndSettle();

    // The purple pulse panel's link now has a real destination.
    await tester.tap(find.text('View customer insights'));
    await tester.pumpAndSettle();
    expect(find.text('Customer insights'), findsOneWidget);
    expect(find.text('Top customers'), findsOneWidget);
    expect(find.text('Retention mix'), findsOneWidget);
    expect(find.text('Avery Harper'), findsOneWidget);
  });

  testWidgets('tapping a customer row opens the customer profile',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Customers'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Avery Harper'));
    await tester.pumpAndSettle();
    expect(find.text('Order history'), findsOneWidget);
    expect(find.text('The Harper Wedding'), findsOneWidget);
    expect(find.text('Lifetime spend'), findsOneWidget);
  });

  testWidgets('employee task rows open the source order', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoEmployee.email, 'employee-pass');

    // The first task ("Stage & pack" for RW-2051) opens the order detail.
    await tester.tap(find.text('Stage & pack'));
    await tester.pumpAndSettle();
    expect(find.text('Item manifest'), findsOneWidget);
    expect(find.text('Order RW-2051'), findsOneWidget);
  });

  test('workspaces can be added and switched', () async {
    final state = WorkspaceState(backend: RecordingBackend());
    await state.signInWithEmail(
        SampleDataset.demoOwner.email, 'owner-pass');

    expect(state.workspace, SampleDataset.workspaceName);
    expect(state.workspaces.length, 1);

    expect(state.addWorkspace('Cedar Loft Co.'), isTrue);
    expect(state.workspace, 'Cedar Loft Co.');
    expect(state.workspaces, contains(SampleDataset.workspaceName));

    // Duplicate / empty names are refused.
    expect(state.addWorkspace('Cedar Loft Co.'), isFalse);
    expect(state.addWorkspace('  '), isFalse);

    state.switchWorkspace(SampleDataset.workspaceName);
    expect(state.workspace, SampleDataset.workspaceName);
  });

  testWidgets('orders KPI cards apply their matching status filter',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _signInUi(tester, SampleDataset.demoOwner.email, 'owner-pass');

    await tester.tap(find.descendant(
      of: find.byType(SideNav),
      matching: find.text('Orders'),
    ));
    await tester.pumpAndSettle();

    // The awaiting-payment KPI card filters the list to that bucket.
    await tester.tap(find.text('Awaiting payment'));
    await tester.pumpAndSettle();
    expect(find.text('Monroe Family Reunion'), findsOneWidget);
    expect(find.text('Northstar Product Launch'), findsNothing);
  });
}
