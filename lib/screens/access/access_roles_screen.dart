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
import '../../core/app_locale.dart';

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

  static List<_Capability> get _matrix => [
    _Capability(AppLocale.t('View dashboard & activity'), employee: true, owner: true),
    _Capability(AppLocale.t('Create and edit bookings'), employee: true, owner: true),
    _Capability(AppLocale.t('Record payments'), employee: true, owner: true),
    _Capability(AppLocale.t('Adjust stock on hand'), employee: true, owner: true),
    _Capability(AppLocale.t('Add inventory items'), employee: false, owner: true),
    _Capability(AppLocale.t('View financial reports'), employee: false, owner: true),
    _Capability(AppLocale.t('Create employee accounts'), employee: false, owner: true),
    _Capability(AppLocale.t('Manage team access'), employee: false, owner: true),
    _Capability(AppLocale.t('Change workspace settings'), employee: false, owner: true),
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
        child: RestrictedPanel(area: AppLocale.t('Access & roles')),
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
                    Text(AppLocale.t('Access & roles'),
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
              title: AppLocale.t('Role preview'),
              child: LayoutBuilder(builder: (context, box) {
                final employeeCard = _RoleCard(
                  icon: Icons.person_outline,
                  title: UserRole.employee.label,
                  subtitle: UserRole.employee.tagline,
                  selected: state.role == UserRole.employee,
                  onTap: () => state.switchRole(UserRole.employee),
                );
                final ownerCard = _RoleCard(
                  icon: Icons.shield_outlined,
                  title: UserRole.owner.label,
                  subtitle: UserRole.owner.tagline,
                  selected: state.role == UserRole.owner,
                  onTap: () => state.switchRole(UserRole.owner),
                );
                if (box.maxWidth < 560) {
                  // Stacked: NO Expanded — this column shrink-wraps
                  // inside the page scroll, so flex children crash.
                  return Column(
                    children: [
                      employeeCard,
                      const SizedBox(height: 12),
                      ownerCard,
                    ],
                  );
                }
                return Row(children: [
                  Expanded(child: employeeCard),
                  const SizedBox(width: 14),
                  Expanded(child: ownerCard),
                ]);
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
              title: AppLocale.t('Appearance'),
              child: Builder(builder: (context) {
                final pills = Row(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                );
                final hint = Text(AppLocale.t('Remembered on this device'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted));
                if (Density.compact(context)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [pills, const SizedBox(height: 8), hint],
                  );
                }
                return Row(children: [
                  pills,
                  const Spacer(),
                  Flexible(child: hint),
                ]);
              }),
            ),
          ),
          const SizedBox(height: 16),

          // permission matrix — grouped so the split is obvious at a glance
          StaggerIn(
            index: 4,
            child: SectionCard(
              icon: Icons.key_outlined,
              title: AppLocale.t('Permission matrix'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // column headers — role columns get flex 3 on phones
                  // ("EMPLOYEE" cannot fit a flex-2 slice of a ~328px card).
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 4),
                    child: Row(
                      children: [
                        const Expanded(flex: 5, child: SizedBox()),
                        Expanded(
                          flex: 3,
                          child: _MatrixHeader(
                            label: AppLocale.t('Employee'),
                            icon: Icons.person_outline,
                            color: AppPalette.green,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _MatrixHeader(
                            label: AppLocale.t('Owner'),
                            icon: Icons.shield_outlined,
                            color: AppPalette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GroupLabel(AppLocale.t('Shared with every role')),
                  for (final cap in _matrix.where((c) => c.employee))
                    _MatrixRow(capability: cap.label, employee: true, owner: true),
                  _GroupLabel(AppLocale.t('Owner-only')),
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
              Text(AppLocale.t('Role-based access is active'),
                  style: const TextStyle(
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
      child: headline,
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
          Flexible(
            child: Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: color)),
          ),
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
            flex: 5,
            child: Text(capability,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.ink)),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: employee ? const _CheckMark() : const _Dash(),
            ),
          ),
          Expanded(
            flex: 3,
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

/// Team dialogs open as centered dialogs on desktop, and as modal
/// bottom sheets on phones — the platform-idiomatic form surface,
/// with room for the on-screen keyboard.
Future<T?> showTeamDialog<T>(
    BuildContext context, WidgetBuilder builder) {
  if (Density.compact(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.surface,
      barrierColor: Colors.black.withOpacity(0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: builder,
  );
}

class _TeamCardState extends State<_TeamCard> {
  String _query = '';

  Future<void> _openAddDialog() async {
    final created = await showTeamDialog<bool>(
        context, (_) => const _AddEmployeeDialog());
    if (created == true && mounted) {
      setState(() => _query = '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppLocale.t('Employee account created — share the credentials securely.')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openEditDialog(BuildContext context, Account member) async {
    final state = context.read<WorkspaceState>();
    await showTeamDialog<void>(
      context,
      (_) => _EditMemberDialog(
        member: member,
        isSelf: member.userId == state.account?.userId,
        lockDemote: member.role == UserRole.owner && state.ownerCount <= 1,
      ),
    );
  }

  Future<void> _openResetDialog(BuildContext context, Account member) async {
    await showTeamDialog<void>(
        context, (_) => _ResetPasswordDialog(member: member));
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
      title: AppLocale.t('Team members'),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlineButton(
            label: AppLocale.t('Refresh'),
            icon: Icons.refresh_rounded,
            onTap: state.loadingTeam ? null : () => state.loadTeam(),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: AppLocale.t('Add employee'),
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
                                ? AppLocale.t(
                                        'No team profiles loaded yet — tap Refresh. Create employee accounts with “Add employee”.')
                                : AppLocale.t(
                                        'No members match “$_query”. Try another name, email or title.'),
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
      text = AppLocale.t('No members loaded');
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
        hintText: AppLocale.t('Search name, email or title'),
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
                  tooltip: AppLocale.t('Role & title'),
                  icon: Icon(Icons.edit_outlined,
                      size: 17, color: AppPalette.muted),
                  onPressed: widget.onEdit,
                ),
              if (widget.onReset != null)
                IconButton(
                  tooltip: AppLocale.t('Reset password'),
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
      child: Text(AppLocale.t('You'),
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
          ? AppLocale.t('Team member')
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
    final compact = Density.compact(context);
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Creates the sign-in account and the profile. '
          'Share the email + password with the employee — they sign '
          'in on the Sign in screen. Employees cannot sign up.',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              height: 1.5,
              color: AppPalette.body),
        ),
        const SizedBox(height: 14),
        _FieldLabel(AppLocale.t('Full name')),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          autofocus: !compact,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: AppLocale.t('Sam Staff')),
        ),
        const SizedBox(height: 12),
        _FieldLabel(AppLocale.t('Work email')),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration:
              const InputDecoration(hintText: 'sam@company.com'),
        ),
        const SizedBox(height: 12),
        _FieldLabel(AppLocale.t('Job title (optional)')),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.words,
          decoration:
              InputDecoration(hintText: AppLocale.t('Warehouse lead')),
        ),
        const SizedBox(height: 12),
        _FieldLabel(AppLocale.t('Temporary password')),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: AppLocale.t('At least 8 characters'),
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
    );
    final actions = [
      TextButton(
        onPressed:
            _submitting ? null : () => Navigator.pop(context, false),
        child: Text(AppLocale.t('Cancel'),
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
            : Text(AppLocale.t('Create account'),
                style: const TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
    ];
    if (compact) {
      return _SheetScaffold(
            title: AppLocale.t('Add employee'), actions: actions, child: fields);
    }
    return AlertDialog(
      title: Text(AppLocale.t('Add employee'),
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      actions: actions,
      content: SizedBox(width: 420, child: fields),
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
      title: AppLocale.t('Current session'),
      action: OutlineButton(
        label: AppLocale.t('Sign out'),
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
                    'Signed in with ${account?.email ?? '—'}',
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

/// Chrome for team forms opened as phone bottom sheets: drag handle,
/// title, scrollable body that lifts above the keyboard, and a
/// full-width thumb-friendly action pair.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const _SheetScaffold(
      {required this.title, required this.child, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.stroke,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink)),
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    final compact = Density.compact(context);
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocale.t('Role'),
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
          title: Text(AppLocale.t('Employee — day-to-day operations'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: widget.lockDemote
                      ? AppPalette.faint
                      : AppPalette.body)),
          subtitle: widget.lockDemote
              ? Text(AppLocale.t('Last owner — promote someone else first'),
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
          title: Text(AppLocale.t('Owner — full business visibility'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: widget.isSelf
                      ? AppPalette.faint
                      : AppPalette.body)),
          subtitle: widget.isSelf
              ? Text(AppLocale.t('You cannot change your own role'),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppPalette.muted))
              : null,
        ),
        const SizedBox(height: 8),
        Text(AppLocale.t('Job title'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppPalette.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
              hintText: AppLocale.t('Warehouse lead')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(text: _error!),
        ],
      ],
    );
    final actions = [
      TextButton(
        onPressed:
            _submitting ? null : () => Navigator.pop(context),
        child: Text(AppLocale.t('Cancel'),
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
            : Text(AppLocale.t('Save changes'),
                style: const TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
    ];
    if (compact) {
      return _SheetScaffold(
          title: 'Edit ${widget.member.name}',
          actions: actions,
          child: fields);
    }
    return AlertDialog(
      title: Text('Edit ${widget.member.name}',
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      actions: actions,
      content: SizedBox(width: 400, child: fields),
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
      setState(() => _error = AppLocale.t('Passwords do not match.'));
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
    final compact = Density.compact(context);
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.t(
              'Sets a new password for ${widget.member.email} right away. Share it securely.'),
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
            label: AppLocale.t('Suggest strong password'),
            icon: Icons.auto_awesome_outlined,
            onTap: _suggest,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: AppLocale.t('At least 8 characters'),
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
              InputDecoration(hintText: AppLocale.t('Repeat password')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(text: _error!),
        ],
      ],
    );
    final actions = [
      TextButton(
        onPressed:
            _submitting ? null : () => Navigator.pop(context),
        child: Text(AppLocale.t('Cancel'),
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
            : Text(AppLocale.t('Reset password'),
                style: const TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
    ];
    if (compact) {
      return _SheetScaffold(
          title: 'Reset ${widget.member.name}\u2019s password',
          actions: actions,
          child: fields);
    }
    return AlertDialog(
      title: Text('Reset ${widget.member.name}\u2019s password',
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      actions: actions,
      content: SizedBox(width: 400, child: fields),
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
    final compact = Density.compact(context);
    Widget confirmForm(BuildContext dialogCtx) {
      final fields = Column(
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
            AppLocale.t('There is no undo. Type RESET to confirm.'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.red),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: !compact,
            decoration: const InputDecoration(hintText: 'RESET'),
          ),
        ],
      );
      final actions = [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text(AppLocale.t('Cancel'),
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
          child: Text(AppLocale.t('Delete everything'),
              style: const TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ];
      if (compact) {
        return _SheetScaffold(
            title: AppLocale.t('Reset workspace data?'),
            actions: actions,
            child: fields);
      }
      return AlertDialog(
        title: Text(AppLocale.t('Reset workspace data?'),
            style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        content: SizedBox(width: 420, child: fields),
        actions: actions,
      );
    }

    final ok = await showTeamDialog<bool>(context, confirmForm);
    if (ok != true) return;
    setState(() => _running = true);
    try {
      await state.resetWorkspaceData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocale.t('Workspace data deleted — you are starting fresh.')),
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
      title: AppLocale.t('Danger zone'),
      subtitle:
          AppLocale.t('Remove the sample dataset (or everything) and start fresh.'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.redBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.red.withOpacity(0.35)),
        ),
        child: Builder(builder: (context) {
          final narrow = Density.compact(context);
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocale.t('Reset workspace data'),
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
                      '${AppLocale.t('Cannot be undone.')}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppPalette.body),
                ),
              ],
            ),
          );
          final action = SizedBox(
            height: 40,
            width: narrow ? double.infinity : null,
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
                        : Text(AppLocale.t('Reset data'),
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          );
          if (narrow) {
            // Copy gets the full width; the destructive button sits
            // alone underneath — nothing cramped or clipped.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconChipLite(
                      icon: Icons.delete_sweep_outlined,
                      color: AppPalette.red,
                      bg: AppPalette.surface,
                      size: 36),
                  const SizedBox(width: 12),
                  info,
                ]),
                const SizedBox(height: 12),
                action,
              ],
            );
          }
          return Row(children: [
            IconChipLite(
                icon: Icons.delete_sweep_outlined,
                color: AppPalette.red,
                bg: AppPalette.surface,
                size: 36),
            const SizedBox(width: 12),
            info,
            const SizedBox(width: 12),
            action,
          ]);
        }),
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
      AppThemeSetting.system => (Icons.brightness_auto_outlined, AppLocale.t('System')),
      AppThemeSetting.light => (Icons.light_mode_outlined, AppLocale.t('Light')),
      AppThemeSetting.dark => (Icons.dark_mode_outlined, AppLocale.t('Dark')),
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
