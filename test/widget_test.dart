import 'package:flutter/material.dart' show Icons, NavigationDrawer, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rentwise/app.dart';
import 'package:rentwise/models/account.dart';
import 'package:rentwise/state/workspace_state.dart';
import 'package:rentwise/widgets/bottom_nav.dart';

/// Plain unit test (no fake async) — exercises the store directly.
void main() {
  test('booking creation decrements availability, appends order, logs activity',
      () async {
    final state = WorkspaceState();
    await state.signIn(UserRole.employee);

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

  test('role switch gates the reports section and updates the account',
      () async {
    final state = WorkspaceState();
    await state.signIn(UserRole.employee);

    expect(state.isOwner, isFalse);

    state.switchRole(UserRole.owner);
    expect(state.isOwner, isTrue);
    expect(state.account!.name, 'Olivia Wells');
  });

  testWidgets('sign-in as employee lands on the operations dashboard',
      (tester) async {
    // Desktop surface (matching the 1440×900 design pack).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WorkspaceState(),
        child: const RentWiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Auth screen visible
    expect(find.text('Welcome back'), findsOneWidget);

    // Tap the CTA (defaults to employee role)
    await tester.tap(find.text('Sign in as employee'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Dashboard visible — employee gets the task-first shift view.
    expect(find.text('Operations overview'), findsWidgets); // top-bar breadcrumb
    expect(find.text('Your task list'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    // Financial/owner-only widgets stay hidden from employees.
    expect(find.text('Month to date'), findsNothing);
    expect(find.text('Business Open'), findsNothing);
  });

  testWidgets('sign-in as owner lands on the business-pulse dashboard',
      (tester) async {
    // Desktop surface (matching the 1440×900 design pack).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WorkspaceState(),
        child: const RentWiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch the role selector to Owner, then tap the CTA.
    await tester.tap(find.text('Owner'));
    await tester.pump();
    await tester.tap(find.text('Sign in as owner'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Owner sees the financial pulse, not the employee shift view.
    expect(find.text('Month to date'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('Revenue trend'), findsOneWidget);
    expect(find.text('Business Open'), findsOneWidget);
    expect(find.text('Your task list'), findsNothing);
    expect(find.text('My recent actions'), findsNothing);
  });

  testWidgets('phone viewport shows bottom app nav instead of drawer',
      (tester) async {
    // Phone surface (matching the 390×844 design pack).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WorkspaceState(),
        child: const RentWiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sign in through the UI (signIn() uses a real timer internally).
    await tester.tap(find.text('Sign in as employee'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

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

    // More sheet exposes secondary sections.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Activity Log'), findsWidgets);
    expect(find.text('Access & roles'), findsOneWidget);
  });
}
