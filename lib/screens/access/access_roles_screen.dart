import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../models/account.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';

class AccessRolesScreen extends StatelessWidget {
  const AccessRolesScreen({super.key});

  static const List<_Capability> _matrix = [
    _Capability('View dashboard & activity', employee: true, owner: true),
    _Capability('Create and edit bookings', employee: true, owner: true),
    _Capability('Record payments', employee: true, owner: true),
    _Capability('Export reports', employee: false, owner: true),
    _Capability('Manage team access', employee: false, owner: true),
    _Capability('Change workspace settings', employee: false, owner: true),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(
                  icon: Icons.verified_user_outlined,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  size: 40),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Workspace / Access & roles'),
                    SizedBox(height: 4),
                    Text('Access & roles',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppColors.textDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Control what employees can see and do across Riverside Events.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted)),
          const SizedBox(height: 22),

          // role-based access banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withOpacity(0.55),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.primaryTint),
            ),
            child: const Row(
              children: [
                IconChipLite(
                    icon: Icons.shield_outlined,
                    color: AppColors.primary,
                    bg: Colors.white,
                    size: 40),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role-based access is active',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      SizedBox(height: 3),
                      Text(
                          'Every action is logged, and sensitive owner controls stay protected.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              color: AppColors.textBody)),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                StatusBadge.custom(
                  label: 'Protected',
                  fg: AppColors.green,
                  bg: AppColors.greenBg,
                  dot: true,
                ),
              ],
            ),
          ),
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 12, left: 4, right: 4),
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
                                  color: AppColors.textMuted))),
                      Expanded(
                          flex: 2,
                          child: Text('EMPLOYEE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted))),
                      SizedBox(width: 16),
                      Expanded(
                          flex: 2,
                          child: Text('OWNER',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted))),
                    ],
                  ),
                ),
                for (final cap in _matrix)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.cardBorder)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Text(cap.label,
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark)),
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.cardBorder),
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
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(
                          'Signed in with ${state.account?.email ?? '—'}',
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => state.signOut(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 16, color: AppColors.red),
                        SizedBox(width: 6),
                        Text('Sign out',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      color: selected ? Colors.white : AppColors.card,
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
                color: selected ? AppColors.primary : AppColors.cardBorder,
                width: selected ? 1.6 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.10),
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
                      selected ? AppColors.primary : AppColors.textBody,
                  bg: selected
                      ? AppColors.primarySoft
                      : AppColors.subtleFill,
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
                                ? AppColors.primary
                                : AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color:
                    selected ? AppColors.primary : AppColors.textFaint,
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
      decoration: const BoxDecoration(
          color: AppColors.greenBg, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 13, color: AppColors.green),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return const Text('—',
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppColors.textFaint));
  }
}
