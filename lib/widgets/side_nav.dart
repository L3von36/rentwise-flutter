import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../state/workspace_state.dart';
import 'brand_logo.dart';
import 'chips.dart';
import 'cards.dart';

/// Destinations shown in the sidebar / drawer.
class _NavItem {
  final Section section;
  final IconData icon;
  final IconData iconActive;
  const _NavItem(this.section, this.icon, this.iconActive);
}

const List<_NavItem> _kNavItems = [
  _NavItem(Section.dashboard, Icons.grid_view_outlined, Icons.grid_view),
  _NavItem(Section.inventory, Icons.inventory_2_outlined, Icons.inventory_2),
  _NavItem(Section.orders, Icons.receipt_long_outlined, Icons.receipt_long),
  _NavItem(Section.customers, Icons.people_outline, Icons.people),
  _NavItem(Section.activity, Icons.show_chart, Icons.show_chart),
  _NavItem(Section.access, Icons.verified_user_outlined, Icons.verified_user),
];

const _NavItem _kReportsItem =
    _NavItem(Section.reports, Icons.donut_small_outlined, Icons.donut_small);

/// Full-height sidebar for wide layouts.
class SideNav extends StatelessWidget {
  final double width;
  const SideNav({super.key, this.width = 230});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    return Container(
      width: width,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BrandLockup(),
            ),
          ),
          const SizedBox(height: 10),

          // Workspace switcher
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _WorkspaceSwitcher(workspace: 'Riverside Events'),
          ),
          const SizedBox(height: 12),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text('WORKSPACE',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.textFaint,
                )),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ..._kNavItems.map((item) => _SideItem(
                      item: item,
                      selected: state.section == item.section,
                      badge: item.section == Section.activity
                          ? state.unreadActivity
                          : 0,
                      onTap: () => context
                          .read<WorkspaceState>()
                          .navigate(item.section),
                    )),
                if (state.isOwner)
                  _SideItem(
                    item: _kReportsItem,
                    selected: state.section == Section.reports,
                    badge: 0,
                    onTap: () => context
                        .read<WorkspaceState>()
                        .navigate(Section.reports),
                  ),
                const SizedBox(height: 8),

                // All caught up card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primaryTint.withOpacity(0.5)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconChipLite(
                          icon: Icons.auto_awesome,
                          color: AppColors.primary,
                          bg: Colors.white,
                          size: 28),
                      SizedBox(height: 8),
                      Text('All caught up',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          )),
                      SizedBox(height: 3),
                      Text(
                        'Every active rental is on track today.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          height: 1.38,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _SideItem(
                  item: const _NavItem(Section.access, Icons.tune, Icons.tune),
                  selected: false,
                  badge: 0,
                  overrideLabel: 'Settings',
                  onTap: () => context
                      .read<WorkspaceState>()
                      .navigate(Section.access),
                ),
              ],
            ),
          ),

          // User footer
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                InitialsAvatar(
                  initials: state.account?.initials ?? '??',
                  color: state.isOwner
                      ? AppColors.avatarIndigo
                      : AppColors.avatarGreen,
                  size: 30,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.account?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        state.account?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: AppColors.textMuted),
                  onPressed: () => _showUserMenu(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined,
                  color: AppColors.textBody),
              title: Text(context.read<WorkspaceState>().account?.name ?? ''),
              subtitle: Text(context.read<WorkspaceState>().account?.email ?? ''),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text('Sign out',
                  style: TextStyle(
                      color: AppColors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<WorkspaceState>().signOut();
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final int badge;
  final String? overrideLabel;
  final VoidCallback onTap;

  const _SideItem({
    required this.item,
    required this.selected,
    required this.badge,
    this.overrideLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textBody;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 12),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: const Border(
                        left: BorderSide(
                            color: AppColors.primary, width: 3)),
                  )
                : null,
            child: Row(
              children: [
                Icon(selected ? item.iconActive : item.icon,
                    size: 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    overrideLabel ?? item.section.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  final String workspace;
  const _WorkspaceSwitcher({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppShadow.card(opacity: 0.04),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('R',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    )),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspace',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        )),
                    SizedBox(height: 1),
                    Text('Riverside Events',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawer body for compact layouts (reuses SideNav content).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      backgroundColor: AppColors.sidebar,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(),
      child: SafeArea(
        right: false,
        child: SideNav(width: 254),
      ),
    );
  }
}
