import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../state/workspace_state.dart';
import '../screens/booking/new_booking_sheet.dart';
import '../screens/profile/profile_screen.dart';
import 'chips.dart';
import '../core/palette.dart';
import '../core/app_locale.dart';

/// Phone-style bottom navigation (Instagram/Telegram pattern):
/// Dashboard · Inventory · ＋ · Orders · More.
///
/// The center ＋ opens the new-rental booking sheet. "More" opens a
/// bottom sheet with the secondary sections (Customers, Activity,
/// Reports for owners, Access & roles) and account actions.
class RentWiseBottomNav extends StatelessWidget {
  const RentWiseBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          border: Border(top: BorderSide(color: AppPalette.stroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Tab(
                icon: Icons.space_dashboard_outlined,
                activeIcon: Icons.space_dashboard_rounded,
                label: AppLocale.t('Home'),
                selected: state.section == Section.dashboard,
                onTap: () =>
                    context.read<WorkspaceState>().navigate(Section.dashboard),
              ),
            ),
            Expanded(
              child: _Tab(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: AppLocale.t('Stock'),
                selected: state.section == Section.inventory,
                onTap: () =>
                    context.read<WorkspaceState>().navigate(Section.inventory),
              ),
            ),
            const _CenterPlus(),
            Expanded(
              child: _Tab(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: AppLocale.t('Orders'),
                selected: state.section == Section.orders,
                onTap: () =>
                    context.read<WorkspaceState>().navigate(Section.orders),
              ),
            ),
            Expanded(
              child: _Tab(
                icon: Icons.menu_rounded,
                activeIcon: Icons.menu_rounded,
                label: AppLocale.t('More'),
                selected: false,
                badge: state.unreadActivity,
                onTap: () => _openMoreSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    final state = context.read<WorkspaceState>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.stroke,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  openProfile(context);
                },
                child: Row(
                children: [
                  InitialsAvatar(
                    initials: state.account?.initials ?? '??',
                    color: state.isOwner
                        ? AppColors.avatarIndigo
                        : AppColors.avatarGreen,
                    size: 34,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.account?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        Text(state.account?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11.5,
                                color: AppPalette.muted)),
                      ],
                    ),
                  ),
                  Text(AppLocale.t('View profile'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary)),
                  const SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppPalette.primary),
                ],
              ),
            ),
            ),
            const Divider(height: 10),
            _MoreTile(
              icon: Icons.people_outline,
              label: AppLocale.t('Customers'),
              onTap: () => _go(sheetCtx, Section.customers),
            ),
            _MoreTile(
              icon: Icons.show_chart,
              label: AppLocale.t('Activity Log'),
              badge: state.unreadActivity,
              onTap: () => _go(sheetCtx, Section.activity),
            ),
            if (state.isOwner) ...[
              _MoreTile(
                icon: Icons.donut_small_outlined,
                label: AppLocale.t('Reports'),
                onTap: () => _go(sheetCtx, Section.reports),
              ),
              // The access console is owner-only: employees must never be
              // able to reach (or change) role assignments.
              _MoreTile(
                icon: Icons.verified_user_outlined,
                label: AppLocale.t('Access & roles'),
                onTap: () => _go(sheetCtx, Section.access),
              ),
            ],
            const Divider(height: 10),
            _MoreTile(
              icon: Icons.logout_rounded,
              label: AppLocale.t('Sign out'),
              destructive: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<WorkspaceState>().signOut();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext sheetCtx, Section section) {
    Navigator.pop(sheetCtx);
    sheetCtx.read<WorkspaceState>().navigate(section);
  }
}

// ------------------------------------------------------------------- tabs
class _Tab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.primary : AppPalette.muted;
    return InkResponse(
      onTap: onTap,
      radius: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(selected ? activeIcon : icon, size: 23, color: color),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4.5, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Center indigo ＋ button — opens the new-rental booking sheet.
class _CenterPlus extends StatelessWidget {
  const _CenterPlus();

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => showNewBookingSheet(context),
      radius: 32,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppPalette.primary,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
      ),
    );
  }
}

// --------------------------------------------------------------- more tile
class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool destructive;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppPalette.red : AppPalette.ink;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 21, color: color),
      title: Text(label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          )),
      trailing: badge > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
            )
          : Icon(Icons.chevron_right_rounded,
              size: 18, color: AppPalette.faint),
      onTap: onTap,
    );
  }
}
