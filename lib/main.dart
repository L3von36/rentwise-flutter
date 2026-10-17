import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/shell_state.dart';
import 'state/workspace_state.dart';
import 'app.dart';
import 'widgets/desktop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  if (isDesktop) {
    // Windows/macOS/Linux: frameless window sized, centered and titled
    // before the first frame; the app draws its own title bar
    // (see widgets/desktop.dart + widgets/window_title_bar.dart).
    await initDesktopWindow();
  } else {
    // Touch platforms: edge-to-edge, draw behind the status bar /
    // system nav bar. SafeArea + the custom TopBar consume the insets
    // (see app_shell/top_bar).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
        AppSystemChrome.lightSurfaces); // dark icons on light backgrounds
  }

  final workspace = WorkspaceState();
  final shell = ShellState(prefs: prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: workspace),
        ChangeNotifierProvider.value(value: shell),
      ],
      child: const RentWiseApp(),
    ),
  );

  // Tray quick actions + close-to-tray — wired after the first frame so
  // the window/tray plugins are ready and startup never blocks.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    shell.initDesktopShell(workspace);
  });
}

/// Centralized system-chrome styles.
class AppSystemChrome {
  AppSystemChrome._();

  /// Transparent status/nav bars, dark icons — for light surfaces.
  static const SystemUiOverlayStyle lightSurfaces = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
