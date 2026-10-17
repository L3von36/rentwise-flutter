import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'state/workspace_state.dart';
import 'app.dart';
import 'widgets/desktop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop) {
    // Windows/macOS/Linux: size, center and title the native window
    // before the first frame (see widgets/desktop.dart).
    await initDesktopWindow();
  } else {
    // Touch platforms: edge-to-edge, draw behind the status bar /
    // system nav bar. SafeArea + the custom TopBar consume the insets
    // (see app_shell/top_bar).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
        AppSystemChrome.lightSurfaces); // dark icons on light backgrounds
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => WorkspaceState(),
      child: const RentWiseApp(),
    ),
  );
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
