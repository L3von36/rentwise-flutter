import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'state/workspace_state.dart';
import 'screens/auth/auth_scaffold.dart';
import 'widgets/app_shell.dart';

class RentWiseApp extends StatelessWidget {
  const RentWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RentWise — Event Rentals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        // Compact app: tighten the whole text scale on narrow screens.
        final w = MediaQuery.sizeOf(context).width;
        final scale = w < 430 ? 0.92 : w < 600 ? 0.94 : w < 1000 ? 0.97 : 1.0;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
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
