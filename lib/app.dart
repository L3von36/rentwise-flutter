import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'state/shell_state.dart';
import 'state/workspace_state.dart';
import 'screens/auth/auth_scaffold.dart';
import 'widgets/app_shell.dart';
import 'widgets/desktop.dart';
import 'widgets/window_title_bar.dart';

class RentWiseApp extends StatelessWidget {
  const RentWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-key on theme AND locale changes so the whole tree rebuilds and
    // custom painted chrome re-reads AppPalette, and every t() call and
    // Fmt date re-resolves in the new language / calendar system.
    final shell = context.watch<ShellState>();
    return MaterialApp(
      key: ValueKey(
          'rentwise-${shell.themeSetting.name}-${shell.language.name}-'
          '${shell.calendarSystem.name}'),
      title: 'RentWise — Event Rentals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: shell.themeMode,
      locale: const Locale('en'), // framework widgets; app strings use t()
      builder: (context, child) {
        // Compact app: tighten the whole text scale on narrow screens,
        // then apply the global trim so every breakpoint reads a touch
        // smaller (user request: fonts felt big).
        final w = MediaQuery.sizeOf(context).width;
        final scale = (w < 430 ? 0.92 : w < 600 ? 0.94 : w < 1000 ? 0.97 : 1.0) *
            AppTheme.textScale;
        Widget content = MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
        // Frameless windows draw their own caption above every route.
        if (isDesktopUI) {
          content = Column(
            children: [
              const WindowTitleBar(),
              Expanded(child: content),
            ],
          );
        }
        return content;
      },
      home: const AuthGate(),
    );
  }
}

/// Root switch between auth screens and the workspace shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    if (state.isSignedIn) {
      return const AppShell();
    }
    return const AuthFlow();
  }
}
