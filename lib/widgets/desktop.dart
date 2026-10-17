import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../state/workspace_state.dart';
import 'cards.dart';

/// True when the app runs as a native desktop build (Windows/macOS/Linux).
bool get isDesktop =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// macOS uses ⌘ in shortcut hints; Windows/Linux show Ctrl.
bool get isApple => !kIsWeb && Platform.isMacOS;

String get searchShortcutLabel => isApple ? '⌘K' : 'Ctrl K';

/// Configures the native desktop window: sensible default size, a minimum
/// size below which the responsive layout never breaks, centered on
/// launch, and a proper window title. No-op on mobile and web.
Future<void> initDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    title: 'RentWise — Riverside Events',
    titleBarStyle: TitleBarStyle.normal,
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
    if (!isDesktop) return;
    windowManager.setTitle('RentWise — ${widget.section.label}');
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
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
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              color: AppColors.textBody,
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
        backgroundColor: Colors.white,
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
                    const IconChipLite(
                        icon: Icons.keyboard_rounded,
                        color: AppColors.primary,
                        bg: AppColors.primarySoft,
                        size: 34),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Keyboard shortcuts',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fast paths for the desk — no mouse required.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppColors.textMuted),
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
