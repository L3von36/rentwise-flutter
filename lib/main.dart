import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/appwrite_backend.dart';
import 'services/system_proxy.dart';
import 'state/shell_state.dart';
import 'state/workspace_state.dart';
import 'app.dart';
import 'widgets/desktop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web + automation/screen-reader support: Flutter web paints to canvas,
  // so the DOM stays empty until semantics are enabled. `?a11y=1` opts in
  // (assistive tech can also enable it via the browser's a11y toggle).
  if (kIsWeb && Uri.base.queryParameters['a11y'] == '1') {
    RendererBinding.instance.ensureSemantics();
  }
  // Route HTTP through the OS system proxy when one is configured —
  // without this, machines behind VPN/proxy "system proxy" toggles can
  // never reach Appwrite Cloud from the desktop builds.
  await applySystemProxy();
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

  final workspace = WorkspaceState(backend: AppwriteBackend());
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
