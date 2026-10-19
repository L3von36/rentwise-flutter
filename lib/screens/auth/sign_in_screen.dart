import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../state/workspace_state.dart';
import 'auth_scaffold.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';
import '../../core/app_locale.dart';

/// Sign-in screen — email/password against Appwrite Cloud.
///
/// There are no bundled accounts, quick-fill credentials or role
/// selection: the signed-in user's role is resolved server-side from
/// their `profiles` document. Failures surface in the inline error box
/// and the user retries.
class SignInView extends StatefulWidget {
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;
  const SignInView({
    super.key,
    required this.onForgotPassword,
    required this.onRegister,
  });

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  bool _obscure = true;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  Future<void> _submit() async {
    await context.read<WorkspaceState>().signInWithEmail(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    // Failures render in the inline error box via state.authError.
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final compact = MediaQuery.sizeOf(context).width < 1000;

    return AuthScaffold(
      eyebrow: 'RentWise Workspace',
      card: Stack(
        children: [
          Container(
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
                    icon: Icons.lock_outline_rounded,
                    color: AppPalette.primary,
                    bg: AppPalette.primarySoft,
                    size: 42),
                const SizedBox(height: 16),
                Text(AppLocale.t('Welcome back'),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(AppLocale.t('Sign in to continue to your workspace.'),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),

                // Email
                _FieldLabel(AppLocale.t('Work email')),
                const SizedBox(height: 7),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@company.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        size: 18, color: AppPalette.muted),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40),
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                _FieldLabel(AppLocale.t('Password')),
                const SizedBox(height: 7),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppPalette.muted),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40),
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(AppLocale.t('Forgot password?'),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.primary,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (state.authError != null) ...[
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
                          child: Text(state.authError!,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.red,
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // CTA
                SizedBox(
                  height: 48,
                  child: Material(
                    color: AppPalette.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: state.loadingAuth ? null : _submit,
                      child: Center(
                        child: state.loadingAuth
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.login_rounded,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 9),
                                  Text(
                                    AppLocale.t('Sign in'),
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(AppLocale.t('New to RentWise?'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: AppPalette.body)),
                    ),
                    TextButton(
                      onPressed: widget.onRegister,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(AppLocale.t('Create an account'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.primary)),
                    ),
                  ],
                ),
                Text(
                  AppLocale.t('Workspace access is managed by your company owner.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    color: AppPalette.faint,
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 18),
                  const AuthFooter(),
                ],
              ],
            ),
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
          color: AppPalette.ink,
        ));
  }
}
