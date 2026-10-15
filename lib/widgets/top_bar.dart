import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../state/workspace_state.dart';
import 'brand_logo.dart';
import 'chips.dart';
import 'cards.dart';

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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    return Container(
      height: 64,
      color: Colors.white,
      child: Row(
        children: [
          if (compact) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark),
              onPressed: onOpenDrawer,
            ),
            const Expanded(
              child: Center(child: BrandLockup(markSize: 24, fontSize: 17)),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const SizedBox(width: 26),
            _Breadcrumb(state: state),
          ],

          if (!compact) ...[
            const Spacer(),
            _SearchField(onOpen: () => _openSearch(context)),
            const SizedBox(width: 14),
          ] else
            const Spacer(),

          _BellButton(unread: state.unreadActivity),

          if (!compact) ...[
            const SizedBox(width: 14),
            _UserChip(state: state),
            const SizedBox(width: 24),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (_) => const _SearchDialog(),
    );
  }
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
        const Text(
          'Riverside Events',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.textFaint),
        ),
        Text(
          state.section.breadcrumb,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- search field
class _SearchField extends StatelessWidget {
  final VoidCallback onOpen;
  const _SearchField({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 300,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.subtleFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Search items, orders, or customers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textFaint,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Text('⌘K',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
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
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 90),
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
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                  fillColor: AppColors.subtleFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
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
                        color: AppColors.primary,
                        bg: AppColors.primarySoft,
                        size: 32,
                      ),
                      title: Text(hit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(hit.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.subtleFill,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(hit.type,
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                      ),
                      onTap: () {
                        context.read<WorkspaceState>().navigate(hit.target);
                        Navigator.pop(context);
                      },
                    ),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No matches found',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppColors.textMuted,
                                fontSize: 13.5)),
                      ),
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
class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showNotifications(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 20, color: AppColors.textBody),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
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
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Text('Notifications',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text('Latest employee actions in the workspace.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppColors.textMuted)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(
              initials: entry.actorInitials,
              color: entry.actorColor,
              size: 30,
              fontSize: 11),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RichActivityText(body: entry.body, fontSize: 12.5),
                const SizedBox(height: 3),
                Text(_timeLabel(entry.at),
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppColors.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge.custom(
            label: entry.type.label,
            fg: entry.type.fg,
            bg: entry.type.bg,
            fontSize: 10.5,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          ),
        ],
      ),
    );
  }
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder)),
      onSelected: (v) {
        if (v == 'signout') state.signOut();
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(state.account?.email ?? '',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppColors.textMuted)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 17, color: AppColors.red),
              SizedBox(width: 8),
              Text('Sign out',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            InitialsAvatar(
              initials: state.account?.initials ?? '??',
              color: state.isOwner
                  ? AppColors.avatarIndigo
                  : AppColors.avatarGreen,
              size: 30,
              fontSize: 11,
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.account?.name ?? '',
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Text(state.role.label,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.textMuted),
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
          color: AppColors.textDark,
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
          color: AppColors.textBody,
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
