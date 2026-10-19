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
import '../../core/app_locale.dart';
import '../../core/formatters.dart';

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
      eyebrow: AppLocale.t('Profile'),
      title: account?.name ?? AppLocale.t('Profile'),
      icon: Icons.account_circle_outlined,
      // Centered readable column on wide windows — full-width identity
      // cards and password fields look broken at 1300px+.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          SectionCard(
            icon: Icons.badge_outlined,
            title: AppLocale.t('Identity'),
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
                                label: state.isOwner ? AppLocale.t('Owner') : AppLocale.t('Employee'),
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
                    label: AppLocale.t('Email'),
                    value: account?.email ?? '—'),
                _InfoLine(
                    icon: Icons.storefront_outlined,
                    label: AppLocale.t('Workspace'),
                    value: state.workspace),
                _InfoLine(
                    icon: Icons.verified_user_outlined,
                    label: AppLocale.t('Permissions'),
                    value: state.isOwner
                        ? AppLocale.t('Full access — business + team')
                        : AppLocale.t('Operations — dashboard, inventory, orders, customers, activity')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.dark_mode_rounded,
            title: AppLocale.t('Appearance'),
            child: SegmentedThemePicker(
              current: shell.themeSetting,
              onChanged: shell.setThemeSetting,
            ),
          ),
          const SizedBox(height: 14),
          // Ethiopian context: UI language (English / አማርኛ) and the
          // calendar the whole app renders dates with. Both persist on
          // this device and apply instantly.
          SectionCard(
            icon: Icons.public_rounded,
            title: AppLocale.t('Region & language'),
            child: _RegionAndLanguage(shell: shell),
          ),
          const SizedBox(height: 14),
          // self-service password rotation — every role. Owners reset
          // EMPLOYEE passwords from Access & roles → Team members.
          const _ChangePasswordCard(),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.settings_outlined,
            title: AppLocale.t('Session'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlineButton(
                  label: AppLocale.t('Sign out'),
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
        ),
      ),
    );
  }
}

/// Language + calendar pickers with a live dual-calendar preview — the
/// same segment style as [SegmentedThemePicker] so the screen reads as
/// one family of settings.
class _RegionAndLanguage extends StatelessWidget {
  final ShellState shell;
  const _RegionAndLanguage({required this.shell});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocale.t('Language'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.muted)),
        const SizedBox(height: 7),
        _Segmented<AppLanguage>(
          current: shell.language,
          options: const [
            (AppLanguage.en, 'English'),
            (AppLanguage.am, 'አማርኛ'),
          ],
          onChanged: shell.setLanguage,
        ),
        const SizedBox(height: 14),
        Text(AppLocale.t('Calendar system'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.muted)),
        const SizedBox(height: 7),
        _Segmented<CalendarSystem>(
          current: shell.calendarSystem,
          options: [
            (CalendarSystem.ethiopic,
                AppLocale.isAmharic ? 'ዓ.ም' : AppLocale.t('Ethiopian')),
            (CalendarSystem.gregorian,
                AppLocale.isAmharic ? 'እ.ኤ.አ' : AppLocale.t('Gregorian')),
          ],
          onChanged: shell.setCalendarSystem,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppPalette.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocale.t('Today'),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppPalette.faint)),
              const SizedBox(height: 3),
              Text(Fmt.longDate(now),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink)),
              const SizedBox(height: 2),
              Text(AppLocale.otherSystemDate(now),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppPalette.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Generic two-option segmented control (same look as the theme one).
class _Segmented<T> extends StatelessWidget {
  final T current;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const _Segmented({
    required this.current,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: current == value
                        ? AppPalette.raise
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: current == value
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
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: current == value
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: current == value
                              ? AppPalette.ink
                              : AppPalette.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces
/// Self-service password change (account.updatePassword — session-safe).
class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<WorkspaceState>();
    setState(() => _error = null);
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = AppLocale.t('Passwords do not match.'));
      return;
    }
    setState(() => _submitting = true);
    final err = await state.changeMyPassword(
        _currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    if (err == null) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() => _submitting = false);
      return;
    }
    setState(() {
      _submitting = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.password_rounded,
      title: AppLocale.t('Password'),
      subtitle:
          AppLocale.t('Update your password'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
                hintText: AppLocale.t('Current password')),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                    hintText: AppLocale.t('New password (min 8 characters)')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _obscure ? AppLocale.t('Show passwords') : AppLocale.t('Hide passwords'),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AppPalette.muted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration:
                InputDecoration(hintText: AppLocale.t('Repeat new password')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.red)),
          ],
          const SizedBox(height: 12),
          OutlineButton(
            label: _submitting ? AppLocale.t('Updating…') : AppLocale.t('Update password'),
            icon: Icons.check_rounded,
            fg: AppPalette.primary,
            onTap: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

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
      (AppThemeSetting.system, AppLocale.t('System'),
          Icons.settings_suggest_outlined),
      (AppThemeSetting.light, AppLocale.t('Light'), Icons.light_mode_outlined),
      (AppThemeSetting.dark, AppLocale.t('Dark'), Icons.dark_mode_outlined),
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
