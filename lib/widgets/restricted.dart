import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/account.dart';
import '../state/workspace_state.dart';
import 'cards.dart';
import 'chips.dart';
import '../core/palette.dart';

/// Defensive guard rendered when an owner-only screen is somehow reached
/// without the owner role. Navigation already hides and blocks these
/// sections — this panel is the second line of defence.
class RestrictedPanel extends StatelessWidget {
  final String area;
  const RestrictedPanel({super.key, required this.area});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SectionCard(
            icon: Icons.lock_outline_rounded,
            title: '$area is owner-only',
            subtitle:
                'Employees do not have permission to open this area.',
            action: OutlineButton(
              label: 'Back to dashboard',
              icon: Icons.arrow_back_rounded,
              onTap: () => context
                  .read<WorkspaceState>()
                  .navigate(Section.dashboard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconChipLite(
                        icon: Icons.shield_outlined,
                        color: AppPalette.primary,
                        bg: AppPalette.primarySoft,
                        size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Owner access required',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink)),
                          const SizedBox(height: 3),
                          Text(
                              'Business finances, reports and team permissions '
                              'are managed by the workspace owner.',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: AppPalette.body)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppPalette.fill,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppPalette.stroke),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: state.account?.initials ?? '??',
                        color: state.isOwner
                            ? AppColors.avatarIndigo
                            : AppColors.avatarGreen,
                        size: 28,
                        fontSize: 11,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Signed in as ${state.account?.name ?? '—'} · ${state.role.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.ink),
                        ),
                      ),
                      StatusBadge.custom(
                        label: 'Restricted',
                        fg: AppPalette.red,
                        bg: AppPalette.redBg,
                        fontSize: 10.5,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                      ),
                    ],
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
