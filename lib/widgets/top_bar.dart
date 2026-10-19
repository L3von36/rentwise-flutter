import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/breakpoints.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../state/workspace_state.dart';
import '../state/shell_state.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'brand_logo.dart';
import 'chips.dart';
import 'cards.dart';
import 'motion.dart';
import 'desktop.dart';
import '../core/palette.dart';

/// Global search result payload.
class SearchHit {
  final String title;
  final String subtitle;
  final String type;
  final Section target;
  const SearchHit(this.title, this.subtitle, this.type, this.target);
}

/// Top application bar. Wide: breadcrumb + search + bell + user chip.
/// Narrow: hamburger + centered brand + bell.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool compact;
  final VoidCallback? onOpenDrawer;

  const TopBar({super.key, required this.compact, this.onOpenDrawer});

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    // Phone app mode: bottom nav owns navigation — no hamburger,
    // brand sits left (Telegram-style), search collapses to an icon.
    final phoneApp =
        compact && Breakpoints.useBottomNav(MediaQuery.sizeOf(context).width);
    final showHamburger = compact && !phoneApp;
    // Safe area: the custom bar draws edge-to-edge, so it must consume
    // the status-bar inset itself (SafeArea would also work — this keeps
    // the white background extending behind the status bar).
    final topInset = MediaQuery.paddingOf(context).top;
    final baseHeight = phoneApp ? 50.0 : 54.0;
    return Container(
      height: baseHeight + topInset,
      color: AppPalette.surface,
      padding: EdgeInsets.only(top: topInset),
      child: Row(
        children: [
          if (showHamburger) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.menu, color: AppPalette.ink),
              onPressed: onOpenDrawer,
            ),
            const Expanded(
              child: Center(child: BrandLockup(markSize: 22, fontSize: 15.5)),
            ),
            const SizedBox(width: 8),
          ] else if (phoneApp) ...[
            const SizedBox(width: 14),
            // Flexible brand: the fixed-width right cluster (search +
            // bell + theme toggle) always fits; the lockup shrinks first.
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandLockup(markSize: 22, fontSize: 15.5),
              ),
            ),
          ] else ...[
            const SizedBox(width: 16),
            _Breadcrumb(state: state),
          ],

          if (!compact) ...[
            const Spacer(),
            _SearchField(onOpen: () => openGlobalSearch(context)),
            const SizedBox(width: 10),
          ] else if (phoneApp) ...[
            _SearchIconButton(onOpen: () => openGlobalSearch(context)),
            const SizedBox(width: 8),
          ] else
            const Spacer(),

          _BellButton(unread: state.unreadActivity),

          // Theme toggle — available to every role on every platform
          // (Settings > Appearance is owner-only, the title-bar toggle is
          // desktop-only; this is the always-reachable switch).
          const SizedBox(width: 8),
          const _ThemeToggleButton(),

          if (!compact) ...[
            const SizedBox(width: 10),
            _UserChip(state: state),
            const SizedBox(width: 14),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

}

/// Opens the global search dialog (shared with the Ctrl+K shortcut).
void openGlobalSearch(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (_) => const _SearchDialog(),
  );
}

// ------------------------------------------------------------------ breadcrumb
class _Breadcrumb extends StatelessWidget {
  final WorkspaceState state;
  const _Breadcrumb({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.workspace,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppPalette.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.faint),
        ),
        Text(
          state.section.breadcrumb,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppPalette.ink,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- search field
class _SearchIconButton extends StatelessWidget {
  final VoidCallback onOpen;
  const _SearchIconButton({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.fill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Icon(Icons.search_rounded,
              size: 18, color: AppPalette.body),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoidCallback onOpen;
  const _SearchField({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 250,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppPalette.fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 16, color: AppPalette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search items, orders, or customers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.faint,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppPalette.fill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppPalette.stroke),
              ),
              child: Text(searchShortcutLabel,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.muted,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog();
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  String _query = '';

  List<SearchHit> _results(WorkspaceState state) {
    final hits = <SearchHit>[
      for (final i in state.inventory)
        SearchHit(i.name, '${i.category} · ${i.available} of ${i.totalStock} available',
            'Item', Section.inventory),
      for (final o in state.orders)
        SearchHit(
            '#${o.id} · ${o.eventName}',
            '${o.contactName} · ${o.itemCount} items',
            'Order',
            Section.orders),
      for (final c in state.customers)
        SearchHit(c.name, c.company, 'Customer', Section.customers),
    ];
    if (_query.trim().isEmpty) return hits.take(6).toList();
    final q = _query.trim().toLowerCase();
    return hits.where((h) => h.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final results = _results(state);
    return Dialog(
      backgroundColor: AppPalette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 70),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search items, orders, or customers…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppPalette.muted),
                  fillColor: AppPalette.fill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppPalette.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppPalette.stroke),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                children: [
                  for (final hit in results)
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      leading: IconChipLite(
                        icon: hit.type == 'Item'
                            ? Icons.inventory_2_outlined
                            : hit.type == 'Order'
                                ? Icons.receipt_long_outlined
                                : Icons.person_outline,
                        color: AppPalette.primary,
                        bg: AppPalette.primarySoft,
                        size: 28,
                      ),
                      title: Text(hit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(hit.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11.5)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.fill,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(hit.type,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.muted)),
                      ),
                      onTap: () {
                        context.read<WorkspaceState>().navigate(hit.target);
                        Navigator.pop(context);
                      },
                    ),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No matches found',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppPalette.muted,
                                fontSize: 13.5)),
                      ),
                    ),
                ],
              ),
            ),
            // Desktop affordance: remind keyboard users of the other
            // fast paths while search is open.
            if (isDesktop)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: AppPalette.stroke)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: const Row(
                  children: [
                    Expanded(
                      child: ShortcutHint(
                          keys: ['Ctrl B'], action: 'New booking'),
                    ),
                    Expanded(
                      child: ShortcutHint(
                          keys: ['Ctrl 1–5'], action: 'Sections'),
                    ),
                    Expanded(
                      child: ShortcutHint(
                          keys: ['Ctrl /'],
                          action: 'All shortcuts'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bell + user
/// Compact sun/moon switch shown in the top bar for every role.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellState>();
    return Material(
      color: AppPalette.fill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: shell.toggleTheme,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Tooltip(
            message: shell.isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: Icon(
              shell.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 17,
              color: AppPalette.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppPalette.fill,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showNotifications(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.stroke),
              ),
              child: Icon(Icons.notifications_none_rounded,
                  size: 18, color: AppPalette.body),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.surface, width: 2),
              ),
              child: Text('$unread',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
            ),
          ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final entries = state.activity.take(5).toList();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppPalette.stroke),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Notifications',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          openNotifications(context);
                        },
                        child: Text('View all',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.primary)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text('Latest employee actions in the workspace.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppPalette.muted)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    children: [
                      for (final e in entries)
                        _NotificationRow(entry: e),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final ActivityEntry entry;
  const _NotificationRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return HoverFill(
      onTap: () {
        // close the dialog, then land on the mapped workspace section
        Navigator.of(context, rootNavigator: true).pop();
        context.read<WorkspaceState>().navigate(_targetFor(entry.type));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(
                initials: entry.actorInitials,
                color: entry.actorColor,
                size: 26,
                fontSize: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RichActivityText(body: entry.body, fontSize: 12),
                  const SizedBox(height: 3),
                  Text(_timeLabel(entry.at),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          color: AppPalette.faint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.custom(
              label: entry.type.label,
              fg: entry.type.fg,
              bg: entry.type.bg,
              fontSize: 10,
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            ),
          ],
        ),
      ),
    );
  }

  Section _targetFor(ActivityType type) => switch (type) {
        ActivityType.payment => Section.orders,
        ActivityType.orderUpdate => Section.orders,
        ActivityType.newBooking => Section.orders,
        ActivityType.rental => Section.inventory,
        ActivityType.returnItem => Section.inventory,
        ActivityType.note => Section.activity,
      };
}

String _timeLabel(DateTime at) {
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final ampm = at.hour >= 12 ? 'PM' : 'AM';
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}

class _UserChip extends StatelessWidget {
  final WorkspaceState state;
  const _UserChip({required this.state});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppPalette.stroke)),
      onSelected: (v) {
        if (v == 'signout') state.signOut();
        if (v == 'profile') {
          Navigator.of(context, rootNavigator: true).pop();
          openProfile(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.account?.name ?? '',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(state.account?.email ?? '',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppPalette.muted)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined,
                  size: 17, color: AppPalette.body),
              const SizedBox(width: 8),
              Text('View profile',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 17, color: AppPalette.red),
              const SizedBox(width: 8),
              Text('Sign out',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppPalette.red,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppPalette.stroke),
        ),
        child: Row(
          children: [
            InitialsAvatar(
              initials: state.account?.initials ?? '??',
              color: state.isOwner
                  ? AppColors.avatarIndigo
                  : AppColors.avatarGreen,
              size: 26,
              fontSize: 10,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.account?.name ?? '',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(state.role.label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        color: AppPalette.muted)),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppPalette.muted),
          ],
        ),
      ),
    );
  }
}

/// Renders "text with **bold** segments" used by activity entries.
class _RichActivityText extends StatelessWidget {
  final String body;
  final double fontSize;
  const _RichActivityText({required this.body, this.fontSize = 13});

  static final RegExp _bold = RegExp(r'\*\*(.+?)\*\*');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _bold.allMatches(body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
          fontSize: fontSize,
        ),
      ));
      cursor = match.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: fontSize,
          color: AppPalette.body,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}

/// Public helper — other screens reuse the rich-text renderer.
class RichActivityText extends StatelessWidget {
  final String body;
  final double fontSize;
  const RichActivityText({super.key, required this.body, this.fontSize = 13});

  @override
  Widget build(BuildContext context) =>
      _RichActivityText(body: body, fontSize: fontSize);
}
