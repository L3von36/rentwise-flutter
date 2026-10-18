import 'dart:math';

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
import '../../widgets/motion.dart';
import '../../widgets/restricted.dart';
import '../../core/palette.dart';

/// OWNER CONSOLE — Access & roles.
///
/// One screen that answers "who can do what":
///  * a gradient security hero with live team stats,
///  * the team directory (the ONLY place employee accounts are created,
///    plus role/title editing and password resets),
///  * a role preview switch, appearance picker, permission matrix,
///    the current session and the danger zone.
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
    final compact = Density.compact(context);

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

    final ownerMembers =
        state.team.where((m) => m.role == UserRole.owner).length;
    final employeeMembers = state.team.length - ownerMembers;

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------------- header
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
                            fontSize: compact ? 17 : 21,
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
          const SizedBox(height: 20),

          // ---------------------------------------------- security hero
          StaggerIn(
            index: 0,
            child: _SecurityHero(
              members: state.team.length,
              owners: ownerMembers,
              employees: employeeMembers,
            ),
          ),
          const SizedBox(height: 16),

          // team directory + the ONLY place employee accounts are
          // created (owner action; self-registration is closed).
          const StaggerIn(
            index: 1,
            child: _TeamCard(),
          ),
          const SizedBox(height: 16),

          // role preview — see the app as the other seat sees it
          StaggerIn(
            index: 2,
            child: SectionCard(
              icon: Icons.swap_horiz_rounded,
              title: 'Role preview',
              subtitle:
                  'Step into the other seat to see what they see — your real '
                  'access never changes.',
              child: LayoutBuilder(builder: (context, box) {
                final tiles = [
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.person_outline,
                      title: UserRole.employee.label,
                      subtitle: UserRole.employee.tagline,
                      selected: state.role == UserRole.employee,
                      onTap: () => state.switchRole(UserRole.employee),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.shield_outlined,
                      title: UserRole.owner.label,
                      subtitle: UserRole.owner.tagline,
                      selected: state.role == UserRole.owner,
                      onTap: () => state.switchRole(UserRole.owner),
                    ),
                  ),
                ];
                if (box.maxWidth < 560) {
                  return Column(
                    children: [
                      tiles[0],
                      const SizedBox(height: 12),
                      tiles[2],
                    ],
                  );
                }
                return Row(children: tiles);
              }),
            ),
          ),
          const SizedBox(height: 16),

          // appearance — the cross-platform home of the theme toggle
          // (the desktop title bar and tray menu expose the same control).
          StaggerIn(
            index: 3,
            child: SectionCard(
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
          ),
          const SizedBox(height: 16),

          // permission matrix — grouped so the split is obvious at a glance
          StaggerIn(
            index: 4,
            child: SectionCard(
              icon: Icons.key_outlined,
              title: 'Permission matrix',
              subtitle:
                  'Compare access levels before inviting your next team member.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // column headers
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 4),
                    child: Row(
                      children: [
                        const Expanded(flex: 6, child: SizedBox()),
                        Expanded(
                          flex: 2,
                          child: _MatrixHeader(
                            label: 'Employee',
                            icon: Icons.person_outline,
                            color: AppPalette.green,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _MatrixHeader(
                            label: 'Owner',
                            icon: Icons.shield_outlined,
                            color: AppPalette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _GroupLabel('Shared with every role'),
                  for (final cap in _matrix.where((c) => c.employee))
                    _MatrixRow(capability: cap.label, employee: true, owner: true),
                  const _GroupLabel('Owner-only'),
                  for (final cap in _matrix.where((c) => !c.employee))
                    _MatrixRow(
                        capability: cap.label, employee: false, owner: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // current session
          const StaggerIn(
            index: 5,
            child: _SessionCard(),
          ),
          const SizedBox(height: 16),

          // danger zone — wipe sample/business data (owner only)
          const StaggerIn(
            index: 6,
            child: _DangerZoneCard(),
          ),
        ],
      ),
    );
  }
}

/// Gradient security banner — replaces the old flat info box. Shows the
/// live protection summary: team size, owners, employees, audit logging.
class _SecurityHero extends StatelessWidget {
  final int members;
  final int owners;
  final int employees;

  const _SecurityHero({
    required this.members,
    required this.owners,
    required this.employees,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Density.compact(context);

    final stats = [
      _HeroStat(value: '$members', label: 'Members'),
      _HeroStat(value: '$owners', label: 'Owners'),
      _HeroStat(value: '$employees', label: 'Employees'),
    ];

    final headline = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.shield_outlined,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Role-based access is active',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 3),
              Text(
                'Every action is logged, and sensitive owner controls stay '
                'protected.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.78)),
              ),
            ],
          ),
        ),
      ],
    );

    final statRow = Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: stats[i]),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        boxShadow: AppShadow.card(
            opacity: AppPalette.dark ? 0.5 : 0.18),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 14),
                statRow,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: headline),
                const SizedBox(width: 18),
                SizedBox(width: 270, child: statRow),
              ],
            ),
    );
  }
}

/// Translucent stat tile used inside the security hero.
class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 1),
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white.withOpacity(0.72))),
        ],
      ),
    );
  }
}

// MATRIX -------------------------------------------------------------

/// Colored uppercase column header for the permission matrix.
class _MatrixHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MatrixHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: color)),
        ],
      ),
    );
  }
}

/// Tiny uppercase group caption between matrix sections.
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 11,
            decoration: BoxDecoration(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text(text.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppPalette.muted)),
        ],
      ),
    );
  }
}

/// One permission-matrix row: capability label + per-role check / dash.
class _MatrixRow extends StatelessWidget {
  final String capability;
  final bool employee;
  final bool owner;
  const _MatrixRow({
    required this.capability,
    required this.employee,
    required this.owner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppPalette.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(capability,
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
              child: employee ? const _CheckMark() : const _Dash(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: owner ? const _CheckMark() : const _Dash(),
            ),
          ),
        ],
      ),
    );
  }
}

// TEAM DIRECTORY -----------------------------------------------------

/// Team directory — every workspace member plus the Add-employee
/// action. This is the ONLY place employee accounts are created:
/// self-registration on the auth screen closes as soon as an owner
/// exists, so credentials are always issued by the owner.
class _TeamCard extends StatefulWidget {
  const _TeamCard();

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  String _query = '';

  Future<void> _openAddDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => const _AddEmployeeDialog(),
    );
    if (created == true && mounted) {
      setState(() => _query = '');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Employee account created — share the credentials securely.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openEditDialog(BuildContext context, Account member) async {
    final state = context.read<WorkspaceState>();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _EditMemberDialog(
        member: member,
        isSelf: member.userId == state.account?.userId,
        lockDemote: member.role == UserRole.owner && state.ownerCount <= 1,
      ),
    );
  }

  Future<void> _openResetDialog(BuildContext context, Account member) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _ResetPasswordDialog(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final compact = Density.compact(context);
    final team = state.team;
    final owners = team.where((m) => m.role == UserRole.owner).length;

    // search filter — matches name, email or job title
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? team
        : team
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q) ||
                m.title.toLowerCase().contains(q))
            .toList();

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
          PrimaryButton(
            label: 'Add employee',
            icon: Icons.person_add_alt_rounded,
            height: 36,
            fontSize: 12.5,
            onTap: _openAddDialog,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // toolbar — live count summary + search
                if (!compact)
                  Row(
                    children: [
                      Expanded(child: _TeamSummary(count: team.length, owners: owners)),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 230,
                        child: _TeamSearchField(
                          value: _query,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ],
                  )
                else ...[
                  _TeamSummary(count: team.length, owners: owners),
                  const SizedBox(height: 10),
                  _TeamSearchField(
                    value: _query,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
                const SizedBox(height: 12),

                // member rows
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                            q.isEmpty
                                ? Icons.groups_outlined
                                : Icons.search_off_rounded,
                            size: 18,
                            color: AppPalette.faint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.isEmpty
                                ? 'No team profiles loaded yet — tap Refresh. '
                                    'Create employee accounts with “Add employee”.'
                                : 'No members match “$_query”. Try another name, '
                                    'email or title.',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                color: AppPalette.muted),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _MemberRow(
                      member: visible[i],
                      isSelf: visible[i].userId == state.account?.userId,
                      onEdit: visible[i].userId.isNotEmpty &&
                              visible[i].userId != state.account?.userId
                          ? () => _openEditDialog(context, visible[i])
                          : null,
                      onReset: visible[i].userId.isNotEmpty &&
                              visible[i].userId != state.account?.userId &&
                              visible[i].role == UserRole.employee
                          ? () => _openResetDialog(context, visible[i])
                          : null,
                    ),
                  ],

                // dashed invite tile — the primary creation affordance
                const SizedBox(height: 10),
                _DashedAddTile(onTap: _openAddDialog),
              ],
            ),
    );
  }
}

/// "N members · N owners · N employees" live count line.
class _TeamSummary extends StatelessWidget {
  final int count;
  final int owners;
  const _TeamSummary({required this.count, required this.owners});

  @override
  Widget build(BuildContext context) {
    String text;
    if (count == 0) {
      text = 'No members loaded';
    } else {
      final employees = count - owners;
      text = '$count ${count == 1 ? 'member' : 'members'}'
          ' · $owners ${owners == 1 ? 'owner' : 'owners'}'
          ' · $employees ${employees == 1 ? 'employee' : 'employees'}';
    }
    return Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.muted));
  }
}

/// Rounded search input for the team directory.
class _TeamSearchField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TeamSearchField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search name, email or title',
        prefixIcon: Icon(Icons.search_rounded,
            size: 17, color: AppPalette.muted),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 34, minHeight: 34),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded,
                    size: 15, color: AppPalette.muted),
                onPressed: () => onChanged(''),
              ),
      ),
    );
  }
}

/// One member row: pastel initials avatar (owners get a shield badge),
/// name + "You" chip + role badge, title · email, hover-highlighted,
/// trailing edit / reset actions where allowed.
class _MemberRow extends StatefulWidget {
  final Account member;
  final bool isSelf;
  final VoidCallback? onEdit;
  final VoidCallback? onReset;

  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.onEdit,
    required this.onReset,
  });

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hover = false;

  static const _pastels = [
    AppColors.avatarIndigo,
    AppColors.avatarPurple,
    AppColors.avatarTeal,
    AppColors.avatarOrange,
    AppColors.avatarGreen,
    AppColors.avatarBlue,
  ];

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final isOwner = member.role == UserRole.owner;
    final hasActions = widget.onEdit != null || widget.onReset != null;

    return MouseRegion(
      cursor: hasActions ? SystemMouseCursors.basic : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hover ? AppPalette.fill.withOpacity(0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _MemberAvatar(
              initials: member.initials,
              color: _pastels[member.name.hashCode.abs() % _pastels.length],
              isOwner: isOwner,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.ink)),
                      ),
                      if (widget.isSelf) ...[
                        const SizedBox(width: 6),
                        _YouBadge(),
                      ],
                      const SizedBox(width: 8),
                      StatusBadge.custom(
                        label: member.role.label,
                        fg: isOwner ? AppPalette.primary : AppPalette.green,
                        bg: isOwner
                            ? AppPalette.primarySoft
                            : AppPalette.greenBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.title.isEmpty
                        ? member.email
                        : '${member.title} · ${member.email}',
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
            // per-member actions — everyone except yourself; password
            // reset applies to employees only (the owner rotates their
            // own password in Profile).
            if (hasActions) ...[
              const SizedBox(width: 6),
              if (widget.onEdit != null)
                IconButton(
                  tooltip: 'Role & title',
                  icon: Icon(Icons.edit_outlined,
                      size: 17, color: AppPalette.muted),
                  onPressed: widget.onEdit,
                ),
              if (widget.onReset != null)
                IconButton(
                  tooltip: 'Reset password',
                  icon:
                      Icon(Icons.key_rounded, size: 17, color: AppPalette.muted),
                  onPressed: widget.onReset,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pastel initials avatar with a small shield overlay for owners.
class _MemberAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final bool isOwner;

  const _MemberAvatar({
    required this.initials,
    required this.color,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InitialsAvatar(
              initials: initials, color: color, size: 38, fontSize: 13),
          if (isOwner)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppPalette.surface, width: 1.6),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 8, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tiny "You" chip next to your own name.
class _YouBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.blueBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('You',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppPalette.blue)),
    );
  }
}

/// Dashed “＋ Add employee” tile at the bottom of the directory — a big,
/// obvious creation affordance that tints toward the brand on hover.
class _DashedAddTile extends StatefulWidget {
  final VoidCallback onTap;
  const _DashedAddTile({required this.onTap});

  @override
  State<_DashedAddTile> createState() => _DashedAddTileState();
}

class _DashedAddTileState extends State<_DashedAddTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tint = _hover ? AppPalette.primary : AppPalette.faint;
    return PressableScale(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _hover ? AppPalette.primary : AppPalette.stroke,
              radius: 12,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_rounded,
                      size: 16, color: tint),
                  const SizedBox(width: 8),
                  Text('Add employee',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _hover
                              ? AppPalette.primary
                              : AppPalette.body)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hand-rolled dashed rounded-rect border (no dashed BorderSide in
/// Flutter) — used by the add-employee invite tile.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final len = min(dash, metric.length - d);
        canvas.drawPath(metric.extractPath(d, d + len), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
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
              _ErrorBox(text: _error!),
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

// SESSION ------------------------------------------------------------

/// The signed-in account on this device, with the sign-out action.
class _SessionCard extends StatelessWidget {
  const _SessionCard();

  static const _pastels = [
    AppColors.avatarIndigo,
    AppColors.avatarPurple,
    AppColors.avatarTeal,
    AppColors.avatarOrange,
    AppColors.avatarGreen,
    AppColors.avatarBlue,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final account = state.account;
    final isOwner = state.role == UserRole.owner;

    return SectionCard(
      icon: Icons.account_circle_outlined,
      title: 'Current session',
      subtitle: 'You are signed in on this device.',
      action: OutlineButton(
        label: 'Sign out',
        icon: Icons.logout_rounded,
        fg: AppPalette.red,
        onTap: () => state.signOut(),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: account?.initials ?? '—',
            color: account == null
                ? AppPalette.faint
                : _pastels[account.name.hashCode.abs() % _pastels.length],
            size: 40,
            fontSize: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(account?.name ?? '—',
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
                      label: state.role.label,
                      fg: isOwner ? AppPalette.primary : AppPalette.green,
                      bg: isOwner
                          ? AppPalette.primarySoft
                          : AppPalette.greenBg,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    'Signed in with ${account?.email ?? '—'} · rotate your '
                    'password anytime from Profile.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// DIALOGS ------------------------------------------------------------

/// OWNER ACTION — edit a member's role (promote/demote) and job title.
/// Role changes are refused for yourself and for the last remaining
/// owner; the cloud enforces owner-only document updates as the second
/// line of defence.
class _EditMemberDialog extends StatefulWidget {
  final Account member;
  final bool isSelf;
  final bool lockDemote;

  const _EditMemberDialog({
    required this.member,
    required this.isSelf,
    required this.lockDemote,
  });

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late UserRole _role = widget.member.role;
  late final _titleCtrl =
      TextEditingController(text: widget.member.title);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    final state = context.read<WorkspaceState>();
    final err = await state.updateTeamMember(
      widget.member,
      newRole: _role == widget.member.role ? null : _role,
      title: _titleCtrl.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.member.name}',
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ink)),
            const SizedBox(height: 4),
            RadioListTile<UserRole>(
              value: UserRole.employee,
              groupValue: _role,
              onChanged: widget.lockDemote
                  ? null
                  : (v) => setState(() => _role = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Employee — day-to-day operations',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: widget.lockDemote
                          ? AppPalette.faint
                          : AppPalette.body)),
              subtitle: widget.lockDemote
                  ? Text('Last owner — promote someone else first',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppPalette.muted))
                  : null,
            ),
            RadioListTile<UserRole>(
              value: UserRole.owner,
              groupValue: _role,
              onChanged: widget.isSelf
                  ? null
                  : (v) => setState(() => _role = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Owner — full business visibility',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: widget.isSelf
                          ? AppPalette.faint
                          : AppPalette.body)),
              subtitle: widget.isSelf
                  ? Text('You cannot change your own role',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppPalette.muted))
                  : null,
            ),
            const SizedBox(height: 8),
            Text('Job title',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ink)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Warehouse lead'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(text: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context),
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
              : const Text('Save changes',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ],
    );
  }
}

/// OWNER ACTION — reset an employee's password through the deployed
/// reset-password Appwrite Function. Suggests a strong temporary
/// password; the employee can rotate it from their own Profile.
class _ResetPasswordDialog extends StatefulWidget {
  final Account member;
  const _ResetPasswordDialog({required this.member});

  @override
  State<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _suggest() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    final pw = List.generate(
        12, (_) => chars[rnd.nextInt(chars.length)]).join();
    _passwordCtrl.text = pw;
    _confirmCtrl.text = pw;
    setState(() => _obscure = false);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() => _submitting = true);
    final state = context.read<WorkspaceState>();
    final err = await state.resetTeamMemberPassword(
        widget.member, _passwordCtrl.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset ${widget.member.name}\u2019s password',
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sets a new password for ${widget.member.email} right away. '
              'Share it securely — they sign in with it and can change it '
              'from Profile → Password.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  height: 1.5,
                  color: AppPalette.body),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlineButton(
                label: 'Suggest strong password',
                icon: Icons.auto_awesome_outlined,
                onTap: _suggest,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
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
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration:
                  const InputDecoration(hintText: 'Repeat password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(text: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context),
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
              : const Text('Reset password',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ],
    );
  }
}

// DANGER ZONE --------------------------------------------------------

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
            IconChipLite(
                icon: Icons.delete_sweep_outlined,
                color: AppPalette.red,
                bg: AppPalette.surface,
                size: 36),
            const SizedBox(width: 12),
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

// SHARED WIDGETS -----------------------------------------------------

/// Red-tinted inline error banner used by every team dialog.
class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppPalette.redBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppPalette.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 15, color: AppPalette.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.red)),
          ),
        ],
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

/// Selectable tile in the role-preview section.
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
                        color: AppPalette.primary.withOpacity(0.12),
                        blurRadius: 18,
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
