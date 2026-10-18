import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../models/account.dart';
import '../../state/shell_state.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/restricted.dart';
import '../../core/palette.dart';

class AccessRolesScreen extends StatelessWidget {
  const AccessRolesScreen({super.key});

  static const List<_Capability> _matrix = [
    _Capability('View dashboard & activity', employee: true, owner: true),
    _Capability('Create and edit bookings', employee: true, owner: true),
    _Capability('Record payments', employee: true, owner: true),
    _Capability('Adjust stock on hand', employee: true, owner: true),
    _Capability('Add inventory items', employee: false, owner: true),
    _Capability('View financial reports', employee: false, owner: true),
    _Capability('Create employee accounts', employee: false, owner: true),
    _Capability('Manage team access', employee: false, owner: true),
    _Capability('Change workspace settings', employee: false, owner: true),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final shell = context.watch<ShellState>();

    // Owner-only console: even if this screen is somehow mounted for an
    // employee, only the restricted panel renders (no role switcher,
    // no permission matrix — an employee can never promote themselves).
    if (!state.isOwner) {
      return Padding(
        padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
            Density.pagePad(context), 24),
        child: const RestrictedPanel(area: 'Access & roles'),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(
                  icon: Icons.verified_user_outlined,
                  color: AppPalette.primary,
                  bg: AppPalette.primarySoft,
                  size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Workspace / Access & roles'),
                    const SizedBox(height: 4),
                    Text('Access & roles',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: Density.compact(context) ? 17 : 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppPalette.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Control what employees can see and do across '
              '${state.workspace.isEmpty ? 'your workspace' : state.workspace}.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppPalette.muted)),
          const SizedBox(height: 22),

          // role-based access banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.primarySoft.withOpacity(0.55),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppPalette.primaryTint),
            ),
            child: Row(
              children: [
                IconChipLite(
                    icon: Icons.shield_outlined,
                    color: AppPalette.primary,
                    bg: AppPalette.surface,
                    size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role-based access is active',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink)),
                      const SizedBox(height: 3),
                      Text(
                          'Every action is logged, and sensitive owner controls stay protected.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              color: AppPalette.body)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge.custom(
                  label: 'Protected',
                  fg: AppPalette.green,
                  bg: AppPalette.greenBg,
                  dot: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // team directory + the ONLY place employee accounts are
          // created (owner action; self-registration is closed).
          const _TeamCard(),
          const SizedBox(height: 18),

          // role cards
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  icon: Icons.person_outline,
                  title: UserRole.employee.label,
                  subtitle: UserRole.employee.tagline,
                  selected: state.role == UserRole.employee,
                  onTap: () => state.switchRole(UserRole.employee),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _RoleCard(
                  icon: Icons.shield_outlined,
                  title: UserRole.owner.label,
                  subtitle: UserRole.owner.tagline,
                  selected: state.role == UserRole.owner,
                  onTap: () => state.switchRole(UserRole.owner),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // appearance — the cross-platform home of the theme toggle
          // (the desktop title bar and tray menu expose the same control).
          SectionCard(
            icon: Icons.contrast_rounded,
            title: 'Appearance',
            subtitle: 'Choose how RentWise looks on this device.',
            child: Row(
              children: [
                for (final mode in AppThemeSetting.values) ...[
                  _ThemeChoice(
                    mode: mode,
                    selected: shell.themeSetting == mode,
                    onTap: () => shell.setThemeSetting(mode),
                  ),
                  if (mode != AppThemeSetting.values.last)
                    const SizedBox(width: 10),
                ],
                const Spacer(),
                Flexible(
                  child: Text('Remembered on this device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: AppPalette.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // permission matrix
          SectionCard(
            icon: Icons.key_outlined,
            title: 'Permission matrix',
            subtitle: 'Compare access levels before inviting your next team member.',
            action: OutlineButton(
              label: 'Preview sign-in',
              icon: Icons.visibility_outlined,
              onTap: () => state.signOut(),
            ),
            child: Column(
              children: [
                // header
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 6,
                          child: Text('CAPABILITY',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      Expanded(
                          flex: 2,
                          child: Text('EMPLOYEE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 2,
                          child: Text('OWNER',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                    ],
                  ),
                ),
                for (final cap in _matrix)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppPalette.stroke)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Text(cap.label,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppPalette.ink)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: cap.employee
                                ? const _CheckMark()
                                : const _Dash(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: cap.owner
                                ? const _CheckMark()
                                : const _Dash(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // current session
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppPalette.stroke),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Current session'),
                      const SizedBox(height: 5),
                      Text(
                          '${state.account?.name ?? '—'} · ${state.role.label}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink)),
                      const SizedBox(height: 2),
                      Text(
                          'Signed in with ${state.account?.email ?? '—'}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppPalette.muted)),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => state.signOut(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 16, color: AppPalette.red),
                        const SizedBox(width: 6),
                        Text('Sign out',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // danger zone — wipe sample/business data (owner only)
          const _DangerZoneCard(),
        ],
      ),
    );
  }
}

/// Team directory — every workspace member plus the Add-employee
/// action. This is the ONLY place employee accounts are created:
/// self-registration on the auth screen closes as soon as an owner
/// exists, so credentials are always issued by the owner.
class _TeamCard extends StatelessWidget {
  const _TeamCard();

  Future<void> _openAddDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => const _AddEmployeeDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Employee account created — share the credentials securely.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final team = state.team;

    return SectionCard(
      icon: Icons.groups_rounded,
      title: 'Team members',
      subtitle: 'Employee accounts are created here by you — '
          'self-registration is disabled.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlineButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            onTap: state.loadingTeam ? null : () => state.loadTeam(),
          ),
          const SizedBox(width: 8),
          OutlineButton(
            label: 'Add employee',
            icon: Icons.person_add_alt_rounded,
            fg: AppPalette.primary,
            onTap: () => _openAddDialog(context),
          ),
        ],
      ),
      child: state.loadingTeam && team.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppPalette.primary)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < team.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: AppPalette.stroke
                                  .withOpacity(i == 0 ? 0 : 1))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: team[i].role == UserRole.owner
                              ? AppPalette.primarySoft
                              : AppPalette.greenBg,
                          child: Text(
                            team[i].initials,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: team[i].role == UserRole.owner
                                    ? AppPalette.primary
                                    : AppPalette.green),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(team[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppPalette.ink)),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge.custom(
                                    label: team[i].role.label,
                                    fg: team[i].role == UserRole.owner
                                        ? AppPalette.primary
                                        : AppPalette.green,
                                    bg: team[i].role == UserRole.owner
                                        ? AppPalette.primarySoft
                                        : AppPalette.greenBg,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                team[i].title.isEmpty
                                    ? team[i].email
                                    : '${team[i].title} · ${team[i].email}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11.5,
                                    color: AppPalette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (team.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No team profiles loaded yet — tap Refresh. '
                      'Create employee accounts with “Add employee”.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppPalette.muted),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Dialog that creates an employee account (auth account + profile).
/// Kept open on failure with the error shown inline, closed with
/// `true` on success so the caller can raise a confirmation snackbar.
class _AddEmployeeDialog extends StatefulWidget {
  const _AddEmployeeDialog();

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final state = context.read<WorkspaceState>();
    setState(() => _submitting = true);
    final err = await state.addEmployee(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      title: _titleCtrl.text.trim().isEmpty
          ? 'Team member'
          : _titleCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _submitting = false);
    // Validation errors come back as messages too — show them inline.
    setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add employee',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creates the sign-in account and the employee profile. '
              'Share the email + password with the employee — they sign '
              'in on the Sign in screen. Employees cannot sign up.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  height: 1.5,
                  color: AppPalette.body),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Full name'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Sam Staff'),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Work email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(hintText: 'sam@company.com'),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Job title (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(hintText: 'Warehouse lead'),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Temporary password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'At least 8 characters',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppPalette.muted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppPalette.redBg,
                  borderRadius: BorderRadius.circular(9),
                  border:
                      Border.all(color: AppPalette.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 15, color: AppPalette.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.red)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppPalette.body)),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Text('Create account',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ],
    );
  }
}

/// Owner-only danger zone: permanently deletes every business document
/// from Appwrite (inventory, orders, customers, activity, pickups) and
/// zeroes the metrics. Use it to clear the preloaded sample dataset and
/// start entering real data. Profiles, workspaces and the account are
/// kept. Requires typing RESET to confirm.
class _DangerZoneCard extends StatefulWidget {
  const _DangerZoneCard();

  @override
  State<_DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends State<_DangerZoneCard> {
  bool _running = false;

  Future<void> _confirmAndReset() async {
    final state = context.read<WorkspaceState>();
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reset workspace data?',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes ALL inventory, orders, customers, '
                'activity and pickups from Appwrite Cloud, and zeroes the '
                'metrics. Your account, team profiles and workspaces are kept.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppPalette.body),
              ),
              const SizedBox(height: 10),
              Text(
                'There is no undo. Type RESET to confirm.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.red),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'RESET'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppPalette.body)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.red,
            ),
            onPressed: () =>
                Navigator.pop(dialogCtx, ctrl.text.trim() == 'RESET'),
            child: const Text('Delete everything',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _running = true);
    try {
      await state.resetWorkspaceData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Workspace data deleted — you are starting fresh.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reset failed — $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    return SectionCard(
      icon: Icons.warning_amber_rounded,
      title: 'Danger zone',
      subtitle:
          'Remove the sample dataset (or everything) and start fresh.',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.redBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.red.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset workspace data',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ink)),
                  const SizedBox(height: 3),
                  Text(
                    'Deletes ${state.inventory.length} inventory lines, '
                    '${state.orders.length} orders, ${state.customers.length} '
                    'customers and the full activity log from Appwrite. '
                    'Cannot be undone.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppPalette.body),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: Material(
                color: AppPalette.red,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _running ? null : _confirmAndReset,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            )
                          : const Text('Reset data',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppPalette.ink));
  }
}

class _Capability {
  final String label;
  final bool employee;
  final bool owner;
  const _Capability(this.label, {required this.employee, required this.owner});
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.raise : AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppPalette.primary : AppPalette.stroke,
                width: selected ? 1.6 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppPalette.primary.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ]
                : null,
          ),
          child: Row(
            children: [
              IconChipLite(
                  icon: icon,
                  color:
                      selected ? AppPalette.primary : AppPalette.body,
                  bg: selected
                      ? AppPalette.primarySoft
                      : AppPalette.fill,
                  size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppPalette.primary
                                : AppPalette.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppPalette.muted)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color:
                    selected ? AppPalette.primary : AppPalette.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
          color: AppPalette.greenBg, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: 13, color: AppPalette.green),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return Text('—',
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppPalette.faint));
  }
}

/// Pill selector for the three theme modes (Appearance card).
class _ThemeChoice extends StatelessWidget {
  final AppThemeSetting mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice(
      {required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (mode) {
      AppThemeSetting.system => (Icons.brightness_auto_outlined, 'System'),
      AppThemeSetting.light => (Icons.light_mode_outlined, 'Light'),
      AppThemeSetting.dark => (Icons.dark_mode_outlined, 'Dark'),
    };
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppPalette.primarySoft : AppPalette.fill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: selected ? AppPalette.primary : AppPalette.stroke,
                width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? AppPalette.primary : AppPalette.body),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppPalette.primary : AppPalette.body)),
            ],
          ),
        ),
      ),
    );
  }
}
