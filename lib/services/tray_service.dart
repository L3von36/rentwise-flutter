import 'dart:io' show Platform;

import 'package:system_tray/system_tray.dart';

import '../widgets/desktop.dart';

/// Native system-tray presence: indigo brand icon, right-click quick
/// actions, and a live "tasks due" line rebuilt from workspace state.
///
/// All plugin work is no-op'd unless running as a real desktop app —
/// widget tests and web never touch the native channels.
class TrayService {
  TrayService._();
  static final TrayService instance = TrayService._();

  static const String _iconPathWindows = 'assets/icons/tray_icon.ico';
  static const String _iconPathOther = 'assets/icons/tray_icon.png';

  final SystemTray _tray = SystemTray();
  final Menu _menu = Menu();

  bool _initialized = false;
  bool _disposed = false;
  String _signature = '';

  void Function()? _onShow;
  void Function()? _onQuit;
  void Function()? _onOpenDashboard;
  void Function()? _onOpenOrders;
  void Function()? _onOpenInventory;
  void Function()? _onToggleTheme;

  Future<bool> init({
    required void Function() onShow,
    required void Function() onQuit,
    required void Function() onOpenDashboard,
    required void Function() onOpenOrders,
    required void Function() onOpenInventory,
    required void Function() onToggleTheme,
  }) async {
    _onShow = onShow;
    _onQuit = onQuit;
    _onOpenDashboard = onOpenDashboard;
    _onOpenOrders = onOpenOrders;
    _onOpenInventory = onOpenInventory;
    _onToggleTheme = onToggleTheme;

    if (!isDesktop || runningInTest || _initialized) return _initialized;

    try {
      final ok = await _tray.initSystemTray(
        title: 'RentWise',
        iconPath: Platform.isWindows ? _iconPathWindows : _iconPathOther,
        toolTip: 'RentWise — event rentals',
      );
      if (!ok) return false;
      _initialized = true;

      await _tray.setToolTip('RentWise — event rentals');

      // Left click: bring the window back. Right click: quick actions menu
      // (we re-show + pop the menu ourselves, which covers Windows/macOS).
      _tray.registerSystemTrayEventHandler((eventName) {
        switch (eventName) {
          case kSystemTrayEventClick:
          case kSystemTrayEventDoubleClick:
            _onShow?.call();
            break;
          case kSystemTrayEventRightClick:
            _tray.popUpContextMenu();
            break;
        }
      });

      _rebuild(taskCount: 0, isDark: false);
      return true;
    } catch (_) {
      // Tray is a nicety — never block startup on it.
      return false;
    }
  }

  /// Rebuilds the context menu only when something visible changed.
  void updateMenu({required int taskCount, required bool isDark}) {
    if (!_initialized || _disposed) return;
    final signature = '$taskCount|$isDark';
    if (signature == _signature) return;
    _rebuild(taskCount: taskCount, isDark: isDark);
  }

  void _rebuild({required int taskCount, required bool isDark}) {
    _signature = '$taskCount|$isDark';
    final tasks = taskCount == 0
        ? 'All clear — no open tasks'
        : '$taskCount task${taskCount == 1 ? '' : 's'} on deck';
    _menu.buildFrom([
      MenuItemLabel(label: 'Show RentWise', onClicked: (_) => _onShow?.call()),
      MenuSeparator(),
      MenuItemLabel(
          label: 'Dashboard · $tasks',
          onClicked: (_) => _onOpenDashboard?.call()),
      MenuItemLabel(label: 'Orders', onClicked: (_) => _onOpenOrders?.call()),
      MenuItemLabel(
          label: 'Inventory', onClicked: (_) => _onOpenInventory?.call()),
      MenuSeparator(),
      MenuItemLabel(
        label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        onClicked: (_) => _onToggleTheme?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(label: 'Quit RentWise', onClicked: (_) => _onQuit?.call()),
    ]);
    _tray.setContextMenu(_menu);
  }

  /// Nudge after the window parks in the tray (updates the native tooltip).
  Future<void> announceParked() async {
    if (!_initialized || _disposed) return;
    try {
      await _tray.setToolTip('RentWise is running in the tray');
    } catch (_) {}
  }

  void dispose() {
    if (_disposed || !_initialized) return;
    _disposed = true;
    try {
      _tray.destroy();
    } catch (_) {}
  }
}
