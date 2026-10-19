import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'auth_scaffold.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';
import '../../core/app_locale.dart';

/// Password recovery — honest by design.
///
/// RentWise has no self-service email reset: employee accounts are
/// created by the workspace owner, and the owner resets employee
/// passwords from Access & roles (owner password rotates from
/// Profile → Session). This screen explains that instead of faking a
/// "reset link sent" success state.
class PasswordRecoveryView extends StatelessWidget {
  final VoidCallback onBack;
  const PasswordRecoveryView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'RentWise Workspace',
      card: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppPalette.raise,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.stroke),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B3E8F).withOpacity(0.10),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconChipLite(
                icon: Icons.lock_reset_outlined,
                color: AppPalette.primary,
                bg: AppPalette.primarySoft,
                size: 42),
            const SizedBox(height: 16),
            Text(AppLocale.t('Reset your password'),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Password resets are handled inside your workspace — '
              'there is no email self-reset.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.primarySoft.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.primaryTint),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResetRow(
                    icon: Icons.badge_outlined,
                    text:
                        'Employees — ask your workspace owner to reset it '
                        'from Access & roles → Team members.',
                  ),
                  SizedBox(height: 10),
                  _ResetRow(
                    icon: Icons.manage_accounts_outlined,
                    text:
                        'Owners — rotate your own password from '
                        'Profile → Session.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: Material(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onBack,
                  child: Center(
                    child: Text(AppLocale.t('Back to sign in'),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const AuthFooter(),
          ],
        ),
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ResetRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppPalette.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              height: 1.45,
              color: AppPalette.body,
            ),
          ),
        ),
      ],
    );
  }
}
