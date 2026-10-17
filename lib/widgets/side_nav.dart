import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../state/workspace_state.dart';
import '../screens/profile/profile_screen.dart';
import 'brand_logo.dart';
import 'chips.dart';
import 'cards.dart';
import '../core/palette.dart';

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
    // Top safe area: on devices with a notch/status bar the dark sidebar
    // must not draw under it (nested SafeArea inside the drawer is a no-op).
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        width: width,
        color: AppPalette.panel,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _WorkspaceSwitcher(workspace: state.workspace),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text('WORKSPACE',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppPalette.faint,
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
                    color: AppPalette.primarySoft.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppPalette.primaryTint.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconChipLite(
                          icon: Icons.auto_awesome,
                          color: AppPalette.primary,
                          bg: AppPalette.raise,
                          size: 28),
                      const SizedBox(height: 8),
                      Text('All caught up',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.ink,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        'Every active rental is on track today.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          height: 1.38,
                          color: AppPalette.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Workspace settings live in the owner-only Access & roles
                // console — employees never see this destination.
                if (state.isOwner)
                  _SideItem(
                    item: const _NavItem(
                        Section.access, Icons.tune, Icons.tune),
                    selected: state.section == Section.access,
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppPalette.stroke)),
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
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                      Text(
                        state.account?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz,
                      size: 18, color: AppPalette.muted),
                  onPressed: () => _showUserMenu(context),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.account_circle_outlined,
                  color: AppPalette.body),
              title: Text(context.read<WorkspaceState>().account?.name ?? ''),
              subtitle: Text(context.read<WorkspaceState>().account?.email ?? ''),
              trailing: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppPalette.faint),
              onTap: () {
                Navigator.pop(sheetCtx);
                openProfile(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: AppPalette.red),
              title: Text('Sign out',
                  style: TextStyle(
                      color: AppPalette.red, fontWeight: FontWeight.w600)),
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
    final color = selected ? AppPalette.primary : AppPalette.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppPalette.primarySoft : Colors.transparent,
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
                    border: Border(
                        left: BorderSide(
                            color: AppPalette.primary, width: 3)),
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
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary,
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
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _showWorkspaceSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppPalette.stroke),
            boxShadow: AppShadow.card(opacity: 0.04),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(workspace.isEmpty ? 'R' : workspace[0].toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    )),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspace',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.muted,
                        )),
                    const SizedBox(height: 1),
                    Text(workspace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        )),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppPalette.muted),
            ],
          ),
        ),
      ),
    );
  }

  /// Real workspace picker: switch between workspaces or create a new
  /// one (both write through to the store and the activity log).
  void _showWorkspaceSheet(BuildContext context) {
    final state = context.read<WorkspaceState>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final nameCtrl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your workspaces',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                const SizedBox(height: 4),
                Text(
                  'Switch the whole app to another workspace, or add one.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppPalette.muted),
                ),
                const SizedBox(height: 12),
                for (final name in state.workspaces)
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: name == state.workspace
                            ? AppPalette.primarySoft
                            : AppPalette.fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: name == state.workspace
                                ? AppPalette.primaryBorder
                                : AppPalette.stroke),
                      ),
                      child: Text(
                          name.isEmpty ? 'R' : name[0].toUpperCase(),
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: name == state.workspace
                                  ? AppPalette.primary
                                  : AppPalette.body)),
                    ),
                    title: Text(name,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.ink)),
                    trailing: name == state.workspace
                        ? Icon(Icons.check_rounded,
                            size: 18, color: AppPalette.primary)
                        : null,
                    onTap: name == state.workspace
                        ? null
                        : () {
                            state.switchWorkspace(name);
                            Navigator.pop(sheetCtx);
                          },
                  ),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            hintText: 'New workspace name'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add',
                          style:
                              TextStyle(fontFamily: AppTheme.fontFamily)),
                      onPressed: () {
                        final ok = state.addWorkspace(nameCtrl.text);
                        if (ok) {
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Switched to ${nameCtrl.text.trim()}'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Enter a unique, non-empty workspace name'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Drawer body for compact layouts (reuses SideNav content).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppPalette.panel,
      surfaceTintColor: AppPalette.panel,
      shape: const RoundedRectangleBorder(),
      child: const SafeArea(
        right: false,
        child: SideNav(width: 254),
      ),
    );
  }
}
