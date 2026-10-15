import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rentwise/app.dart';
import 'package:rentwise/models/account.dart';
import 'package:rentwise/state/workspace_state.dart';

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

    // Dashboard visible
    expect(find.text('Operations overview'), findsWidgets);
  });
}
