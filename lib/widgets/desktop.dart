import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:window_manager/window_manager.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import '../state/workspace_state.dart';
import 'cards.dart';

/// True when the app runs as a native desktop build (Windows/macOS/Linux).
bool get isDesktop =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// macOS uses ⌘ in shortcut hints; Windows/Linux show Ctrl.
bool get isApple => !kIsWeb && Platform.isMacOS;

String get searchShortcutLabel => isApple ? '⌘K' : 'Ctrl K';

/// True inside `flutter test` runs — native window/tray plugins are stubs
/// there, so desktop shell calls must degrade to no-ops.
bool get runningInTest => Platform.environment.containsKey('FLUTTER_TEST');

/// Whether custom window chrome (title bar) should RENDER. Based on
/// [defaultTargetPlatform] so widget tests can simulate a desktop build
/// with `debugDefaultTargetPlatformOverride`, while phone/tablet surfaces
/// (real or simulated) never show it.
bool get isDesktopUI {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    default:
      return false;
  }
}

/// Runs a native-window call, swallowing failures when no real window
/// manager exists (tests, web). Runtime desktop behavior lives here so
/// call sites stay clean.
Future<void> safeWindow(Future<void> Function() fn) async {
  if (!isDesktop) return;
  try {
    await fn();
  } on MissingPluginException {
    // No native binding (tests) — ignore.
  } catch (_) {
    // Native shell hiccups must never crash the app.
  }
}

/// Configures the native desktop window: sensible default size, a minimum
/// size below which the responsive layout never breaks, centered on
/// launch, and a hidden native title bar (the app draws its own — see
/// `WindowTitleBar`). No-op on mobile and web.
Future<void> initDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    title: 'RentWise — Riverside Events',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Keeps the native window title in sync with the active workspace
/// section ("RentWise — Orders"), like a native document app.
class WindowTitleSync extends StatefulWidget {
  final Section section;

  const WindowTitleSync({super.key, required this.section});

  @override
  State<WindowTitleSync> createState() => _WindowTitleSyncState();
}

class _WindowTitleSyncState extends State<WindowTitleSync> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WindowTitleSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) _sync();
  }

  void _sync() {
    safeWindow(
        () => windowManager.setTitle('RentWise — ${widget.section.label}'));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ----------------------------------------------------------------- help ui

/// Small keyboard-key chip, Windows "kbd" style.
class KeyCap extends StatelessWidget {
  final String label;
  const KeyCap(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.fill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppPalette.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppPalette.dark ? 0.4 : 0.06),
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
        ),
      ),
    );
  }
}

/// Renders a shortcut hint like "Ctrl B + · New rental booking".
class ShortcutHint extends StatelessWidget {
  final List<String> keys;
  final String action;
  const ShortcutHint({super.key, required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final k in keys) ...[
          KeyCap(k),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            action,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              color: AppPalette.body,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog listing the desktop keyboard shortcuts (opened with Ctrl+/).
void showShortcutsHelp(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (dialogCtx) {
      final plus = isApple ? '⌘' : 'Ctrl +';
      final defs = [
        ShortcutHint(
            keys: [isApple ? '⌘ K' : 'Ctrl K'],
            action: 'Search items, orders, and customers'),
        ShortcutHint(
            keys: [isApple ? '⌘ B' : 'Ctrl B'],
            action: 'New rental booking'),
        ShortcutHint(
            keys: ['$plus 1–5'],
            action:
                'Dashboard · Inventory · Orders · Customers · Activity'),
        ShortcutHint(keys: ['$plus /'], action: 'This shortcuts panel'),
        const ShortcutHint(keys: ['Esc'], action: 'Close dialogs and sheets'),
      ];
      return Dialog(
        backgroundColor: AppPalette.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChipLite(
                        icon: Icons.keyboard_rounded,
                        color: AppPalette.primary,
                        bg: AppPalette.primarySoft,
                        size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Keyboard shortcuts',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: AppPalette.muted),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Fast paths for the desk — no mouse required.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppPalette.muted),
                ),
                const SizedBox(height: 14),
                for (final def in defs) ...[
                  // Full-width wrapper: gives the hint's internal Expanded
                  // a bounded constraint.
                  SizedBox(width: double.infinity, child: def),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
