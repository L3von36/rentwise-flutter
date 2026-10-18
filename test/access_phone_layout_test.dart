import 'package:flutter/material.dart'
    show Scrollable, Size, TextField, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rentwise/app.dart';
import 'package:rentwise/state/shell_state.dart';
import 'package:rentwise/state/workspace_state.dart';
import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';

/// Phone-viewport layout guarantees for the Access & roles console.
///
/// Regression guard: the stacked role-preview branch used Expanded
/// inside a shrink-wrapping Column and threw
/// "RenderFlex children have non-zero flex but incoming height
/// constraints are unbounded" on phones — the whole screen rendered
/// blank. Desktop-size tests (default 800×600 surface) never exercised
/// that branch, so these tests pin the screen at 390×844.
Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => WorkspaceState(backend: RecordingBackend())),
        ChangeNotifierProvider(create: (_) => ShellState()),
      ],
      child: const RentWiseApp(),
    );

void main() {
  initTestCloud(); // path-provider shim before any Appwrite client exists

  Future<void> openAccessAsOwner(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0),
        SampleDataset.demoOwner.email);
    await tester.enterText(find.byType(TextField).at(1), 'owner-pass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // On phones the owner sections live in the bottom-nav More sheet.
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Access & roles').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'access & roles renders every section at phone size — no flex crash',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await openAccessAsOwner(tester);

    expect(find.text('Team members'), findsOneWidget);
    expect(find.text('Role preview'), findsOneWidget);
    expect(find.text('Permission matrix'), findsOneWidget);
    expect(find.text('Current session'), findsOneWidget);
    expect(find.text('Danger zone'), findsOneWidget);

    // Stacked role cards both visible on the phone branch.
    expect(find.text('Employee'), findsWidgets);
    expect(find.text('Owner'), findsWidgets);
  });

  testWidgets('add-employee dialog opens and is usable at phone size',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await openAccessAsOwner(tester);

    await tester.tap(find.text('Add employee').last);
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Temporary password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('danger-zone confirm opens as a sheet at phone size',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await openAccessAsOwner(tester);

    await tester.scrollUntilVisible(
      find.text('Reset data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reset data'));
    await tester.pumpAndSettle();

    // Sheet chrome with the typed-confirmation pattern intact.
    expect(find.text('Reset workspace data?'), findsOneWidget);
    expect(find.text('Delete everything'), findsOneWidget);
  });
}
