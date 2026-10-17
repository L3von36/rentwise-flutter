import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'auth_scaffold.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';

/// Password recovery — email + send reset link (+ success state).
class PasswordRecoveryView extends StatefulWidget {
  final VoidCallback onBack;
  const PasswordRecoveryView({super.key, required this.onBack});

  @override
  State<PasswordRecoveryView> createState() => _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends State<PasswordRecoveryView> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String _sentTo = '';

  void _send() async {
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    setState(() {
      _sending = false;
      _sent = true;
      _sentTo = _emailCtrl.text.trim().isEmpty
          ? 'your email'
          : _emailCtrl.text.trim();
    });
  }

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
        child: _sent ? _buildSuccess(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconChipLite(
            icon: Icons.mail_outline_rounded,
            color: AppPalette.primary,
            bg: AppPalette.primarySoft,
            size: 42),
        const SizedBox(height: 16),
        Text('ACCOUNT RECOVERY',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: AppPalette.muted,
            )),
        const SizedBox(height: 8),
        Text('Reset your password',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          "We'll email you a secure link to get back into your workspace.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text('Work email',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppPalette.ink,
            )),
        const SizedBox(height: 7),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'you@company.com',
            prefixIcon:
                Icon(Icons.mail_outline_rounded, size: 18, color: AppPalette.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: Material(
            color: AppPalette.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sending ? null : _send,
              child: Center(
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 9),
                          Text('Send reset link',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: Icon(Icons.chevron_left_rounded,
                size: 18, color: AppPalette.primary),
            label: Text('Back to sign in',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                )),
          ),
        ),
        const SizedBox(height: 10),
        const AuthFooter(),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconChipLite(
            icon: Icons.mark_email_read_outlined,
            color: AppPalette.green,
            bg: AppPalette.greenBg,
            size: 42),
        const SizedBox(height: 16),
        Text('CHECK YOUR INBOX',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: AppPalette.muted,
            )),
        const SizedBox(height: 8),
        Text('Reset link sent',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'We sent a secure password reset link to $_sentTo. The link expires in 30 minutes.',
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
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppPalette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Didn't receive it? Check your spam folder or resend in a moment.",
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppPalette.body,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 46,
          child: Material(
            color: AppPalette.raise,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _send,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.primaryBorder),
                ),
                alignment: Alignment.center,
                child: Text('Resend link',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.primary,
                    )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: Icon(Icons.chevron_left_rounded,
                size: 18, color: AppPalette.primary),
            label: Text('Back to sign in',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                )),
          ),
        ),
      ],
    );
  }
}
