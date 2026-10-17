import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import '../state/shell_state.dart';
import 'brand_logo.dart';
import 'desktop.dart';

/// Custom frameless title bar (replaces the native Windows caption):
/// draggable brand region, dark-mode quick toggle, and in-window
/// minimize / maximize / restore / close controls with Windows-style
/// hover states (close turns red). Double-click toggles maximize;
/// right-click opens the native window menu. The close button parks the
/// app in the tray (see [ShellState.closeWindow]).
///
/// Rendered only on desktop targets (see `isDesktopUI`) — never on
/// phones, tablets or web.
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _probeMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => _set(true);

  @override
  void onWindowUnmaximize() => _set(false);

  void _set(bool v) {
    if (!mounted || _maximized == v) return;
    setState(() => _maximized = v);
  }

  Future<void> _probeMaximized() async {
    if (!isDesktop || runningInTest) return;
    try {
      final m = await windowManager.isMaximized();
      _set(m);
    } catch (_) {}
  }

  void _toggleMaximize() => safeWindow(() async {
        if (await windowManager.isMaximized()) {
          await windowManager.restore();
        } else {
          await windowManager.maximize();
        }
        _probeMaximized();
      });

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellState>();
    final ink = AppPalette.ink;
    final muted = AppPalette.muted;

    return Material(
      color: AppPalette.panel,
      child: SizedBox(
        height: 42,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------- draggable brand region
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  onSecondaryTapUp: (_) =>
                      safeWindow(windowManager.popUpWindowMenu),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const BrandMark(size: 17),
                      const SizedBox(width: 9),
                      Text(
                        'RentWise',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 14,
                        color: AppPalette.stroke,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Event rentals, calm and connected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
            ),
            // -------- in-window caption controls
            _CaptionButton(
              tooltip: shell.isDark ? 'Switch to light mode' : 'Switch to dark mode',
              onPressed: shell.toggleTheme,
              child: Icon(
                shell.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 17,
                color: muted,
              ),
            ),
            _CaptionButton(
              tooltip: 'Minimize',
              onPressed: () => safeWindow(windowManager.minimize),
              child: Icon(Icons.minimize_rounded, size: 17, color: ink),
            ),
            _CaptionButton(
              tooltip: _maximized ? 'Restore' : 'Maximize',
              onPressed: _toggleMaximize,
              child: Icon(
                _maximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                size: 15,
                color: ink,
              ),
            ),
            _CaptionButton(
              tooltip: 'Close',
              hoverColor: const Color(0xFFC42B1C), // Windows close red
              hoverIconColor: Colors.white,
              onPressed: () =>
                  context.read<ShellState>().closeWindow(),
              child: Icon(Icons.close_rounded, size: 17, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// One caption button: square hit target, subtle hover fill, and the
/// Windows signature red hover for close.
class _CaptionButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _CaptionButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fill = _hover
        ? (widget.hoverColor ??
            AppPalette.ink.withOpacity(AppPalette.dark ? 0.09 : 0.06))
        : Colors.transparent;
    final child = _hover && widget.hoverIconColor != null
        ? IconTheme.merge(
            data: IconThemeData(color: widget.hoverIconColor),
            child: widget.child,
          )
        : widget.child;

    // NOTE: no Tooltip widget here — the title bar lives ABOVE the
    // Navigator's Overlay (MaterialApp.builder), so overlay-backed
    // tooltips can't render. Semantics carries the label instead.
    return Semantics(
      label: widget.tooltip,
      button: true,
      container: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 46,
            color: fill,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
