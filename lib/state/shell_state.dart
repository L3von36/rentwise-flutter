import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../core/app_locale.dart';
import '../core/palette.dart';
import '../services/tray_service.dart';
import '../widgets/desktop.dart';
import 'workspace_state.dart';

/// How the app picks its brightness.
enum AppThemeSetting { system, light, dark }

/// UI-shell state, separate from the domain store ([WorkspaceState]):
///
///  * theme mode (system / light / dark) — persisted to SharedPreferences
///    so the desktop app reopens with the user's choice;
///  * language (English / አማርኛ) and calendar system (Ethiopian /
///    Gregorian) — persisted, mirrored into [AppLocale] so formatters and
///    model labels can localize without a BuildContext;
///  * the global [AppPalette.brightness] mirror that custom-painted chrome
///    resolves against (single writer: [setThemeMode]);
///  * the native desktop bridge: tray quick actions, close-to-tray and the
///    tray menu rebuilding live when the workspace data changes.
class ShellState extends ChangeNotifier {
  ShellState({SharedPreferences? prefs}) : _prefs = prefs {
    _themeMode = _restore();
    // Locale mirror must be set BEFORE the first build so every static
    // Fmt/label call renders in the restored language + calendar.
    AppLocale.set(
      language: _restoreLanguage(),
      calendarSystem: _restoreCalendar(),
    );
    AppPalette.brightness = _resolvedBrightness();
  }

  static const String _prefKey = 'rentwise.theme';
  static const String _prefLang = 'rentwise.lang';
  static const String _prefCalendar = 'rentwise.calendar';

  final SharedPreferences? _prefs;
  AppThemeSetting _themeMode = AppThemeSetting.system;

  AppThemeSetting get themeSetting => _themeMode;

  AppLanguage get language => AppLocale.language;
  CalendarSystem get calendarSystem => AppLocale.calendarSystem;
  ThemeMode get themeMode => switch (_themeMode) {
        AppThemeSetting.system => ThemeMode.system,
        AppThemeSetting.light => ThemeMode.light,
        AppThemeSetting.dark => ThemeMode.dark,
      };

  /// Whether the resolved palette is dark (system setting included).
  bool get isDark => _resolvedBrightness() == Brightness.dark;

  // ------------------------------------------------------------ theme mode

  void setThemeSetting(AppThemeSetting setting) {
    if (setting == _themeMode) return;
    _themeMode = setting;
    _persist();
    // Refresh the token mirror BEFORE notifying, so every listener (the
    // re-keyed MaterialApp, the title bar, the tray icon) sees the new one.
    AppPalette.brightness = _resolvedBrightness();
    notifyListeners();
  }

  void toggleTheme() =>
      setThemeSetting(isDark ? AppThemeSetting.light : AppThemeSetting.dark);

  // --------------------------------------------------- language + calendar

  /// Switches the UI language (English ⇄ አማርኛ). Updates the [AppLocale]
  /// mirror first, then notifies — the MaterialApp re-keys on the new
  /// setting so the whole tree rebuilds localized.
  Future<void> setLanguage(AppLanguage lang) async {
    if (lang == AppLocale.language) return;
    AppLocale.set(language: lang);
    notifyListeners();
    try {
      await _prefs?.setString(_prefLang, lang.name);
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  /// Switches the calendar the whole app renders dates with (Ethiopian
  /// 13-month ⇄ Gregorian). Business data stays Gregorian — display only.
  Future<void> setCalendarSystem(CalendarSystem system) async {
    if (system == AppLocale.calendarSystem) return;
    AppLocale.set(calendarSystem: system);
    notifyListeners();
    try {
      await _prefs?.setString(_prefCalendar, system.name);
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  AppLanguage _restoreLanguage() => switch (_prefs?.getString(_prefLang)) {
        'am' => AppLanguage.am,
        'en' => AppLanguage.en,
        _ => AppLanguage.en,
      };

  CalendarSystem _restoreCalendar() =>
      switch (_prefs?.getString(_prefCalendar)) {
        'ethiopic' => CalendarSystem.ethiopic,
        'gregorian' => CalendarSystem.gregorian,
        _ => CalendarSystem.gregorian,
      };

  Brightness _resolvedBrightness() {
    switch (_themeMode) {
      case AppThemeSetting.light:
        return Brightness.light;
      case AppThemeSetting.dark:
        return Brightness.dark;
      case AppThemeSetting.system:
        final binding = SchedulerBinding.instance;
        return binding.platformDispatcher.platformBrightness;
    }
  }

  AppThemeSetting _restore() {
    final raw = _prefs?.getString(_prefKey); // 'rentwise.theme'
    return switch (raw) {
      'light' => AppThemeSetting.light,
      'dark' => AppThemeSetting.dark,
      'system' => AppThemeSetting.system,
      _ => AppThemeSetting.system,
    };
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(_prefKey, _themeMode.name);
    } catch (_) {
      // Persistence is best-effort (e.g. storage unavailable).
    }
  }

  // ------------------------------------------------------- desktop bridge

  WorkspaceState? _workspace;
  bool _desktopBound = false;
  bool _trayWired = false;

  /// Binds the desktop shell: close-to-tray + tray quick actions. Called
  /// once from `main()` after the first frame; no-op on mobile/web/tests.
  Future<void> initDesktopShell(WorkspaceState workspace) async {
    if (_desktopBound || !isDesktop || runningInTest) return;
    _desktopBound = true;
    _workspace = workspace;
    workspace.addListener(_onWorkspaceChanged);

    // Intercept the native close: the app parks in the tray instead of
    // quitting (Quit lives in the tray menu).
    await safeWindow(() => windowManager.setPreventClose(true));

    await _ensureTray();
    _syncTray();
  }

  Future<void> _ensureTray() async {
    if (_trayWired) return;
    _trayWired = await TrayService.instance.init(
      onShow: showWindow,
      onQuit: quit,
      onOpenDashboard: () => _goto(Section.dashboard),
      onOpenOrders: () => _goto(Section.orders),
      onOpenInventory: () => _goto(Section.inventory),
      onToggleTheme: toggleTheme,
    );
  }

  void _goto(Section section) {
    showWindow();
    _workspace?.navigate(section);
  }

  /// Tray menu labels carry live workspace numbers — rebuild whenever the
  /// domain store changes (order created, payment recorded, …).
  void _onWorkspaceChanged() => _syncTray();

  void _syncTray() {
    final ws = _workspace;
    if (ws == null || !_trayWired) return;
    TrayService.instance.updateMenu(
      taskCount: ws.preparingCount + ws.needsPaymentCount,
      isDark: isDark,
    );
  }

  /// Native close button → park in the tray (the window keeps running and
  /// stays reachable from the tray icon).
  Future<void> closeWindow() async {
    if (!isDesktop) return;
    await safeWindow(windowManager.hide);
    if (!isDesktop) return;
    if (runningInTest) return;
    try {
      await TrayService.instance.announceParked();
    } catch (_) {}
  }

  /// Show + focus the window (tray click / quick actions).
  Future<void> showWindow() async {
    await safeWindow(() async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// Real exit — only offered from the tray menu.
  Future<void> quit() async {
    TrayService.instance.dispose();
    await safeWindow(() async {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    });
  }

  @override
  void dispose() {
    _workspace?.removeListener(_onWorkspaceChanged);
    TrayService.instance.dispose();
    super.dispose();
  }
}
