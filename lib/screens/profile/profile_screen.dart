import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../state/shell_state.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../core/palette.dart';

/// Personal profile — identity card, appearance switcher (same engine as
/// the top-bar toggle, persisted), and account actions. Every role can
/// open their own profile from the user menu.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final shell = context.watch<ShellState>();
    final account = state.account;

    return DetailPage(
      eyebrow: 'Workspace / Profile',
      title: account?.name ?? 'Profile',
      subtitle: 'Your identity, appearance and session.',
      icon: Icons.account_circle_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            icon: Icons.badge_outlined,
            title: 'Identity',
            subtitle: 'What your teammates see in the activity log.',
            child: Column(
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      initials: account?.initials ?? '??',
                      color: state.isOwner
                          ? AppColors.avatarIndigo
                          : AppColors.avatarGreen,
                      size: 52,
                      fontSize: 17,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account?.name ?? '—',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: AppPalette.ink)),
                          const SizedBox(height: 3),
                          Text(account?.title ?? '',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  color: AppPalette.muted)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              StatusBadge.custom(
                                label: state.isOwner ? 'Owner' : 'Employee',
                                fg: state.isOwner
                                    ? AppPalette.primary
                                    : AppPalette.green,
                                bg: state.isOwner
                                    ? AppPalette.primarySoft
                                    : AppPalette.greenBg,
                                dot: true,
                              ),
                              StatusBadge.custom(
                                label: state.workspace,
                                fg: AppPalette.purple,
                                bg: AppPalette.purpleBg,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                _InfoLine(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: account?.email ?? '—'),
                _InfoLine(
                    icon: Icons.storefront_outlined,
                    label: 'Workspace',
                    value: state.workspace),
                _InfoLine(
                    icon: Icons.verified_user_outlined,
                    label: 'Permissions',
                    value: state.isOwner
                        ? 'Full access — business + team'
                        : 'Operations — dashboard, inventory, orders, customers, activity'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.dark_mode_rounded,
            title: 'Appearance',
            subtitle: 'Persisted across restarts — same engine as the top-bar toggle.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedThemePicker(
                  current: shell.themeSetting,
                  onChanged: shell.setThemeSetting,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 15, color: AppPalette.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Tip: the sun/moon button in the top bar flips light/dark instantly; “System” follows your OS.',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            height: 1.45,
                            color: AppPalette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.settings_outlined,
            title: 'Session',
            subtitle: 'Workspace controls for your role.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlineButton(
                      label: 'Access & roles',
                      icon: Icons.verified_user_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        state.navigate(Section.access);
                      },
                    ),
                  ),
                OutlineButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  fg: AppPalette.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    state.signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('${state.workspace} · RentWise',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppPalette.faint)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoLine(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppPalette.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppPalette.muted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.body)),
          ),
        ],
      ),
    );
  }
}

/// System / Light / Dark segmented control bound to [ShellState].
class SegmentedThemePicker extends StatelessWidget {
  final AppThemeSetting current;
  final ValueChanged<AppThemeSetting> onChanged;

  const SegmentedThemePicker({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (AppThemeSetting.system, 'System', Icons.settings_suggest_outlined),
      (AppThemeSetting.light, 'Light', Icons.light_mode_outlined),
      (AppThemeSetting.dark, 'Dark', Icons.dark_mode_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final (setting, label, icon) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(setting),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: current == setting
                        ? AppPalette.raise
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: current == setting
                        ? [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(AppPalette.dark ? 0.4 : 0.06),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 14,
                          color: current == setting
                              ? AppPalette.primary
                              : AppPalette.muted),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: current == setting
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: current == setting
                                  ? AppPalette.ink
                                  : AppPalette.muted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Entry point used by the user menus.
void openProfile(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
}
