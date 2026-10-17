import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/account.dart';
import '../../state/workspace_state.dart';
import 'auth_scaffold.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';

/// Sign-in screen — role toggle, email/password.
///
/// The toggle pre-fills the matching Appwrite account. Sign-in runs
/// against Appwrite Cloud only — there is no offline/demo fallback;
/// failures surface in the inline error box and the user retries.
class SignInView extends StatefulWidget {
  final VoidCallback onForgotPassword;
  const SignInView({super.key, required this.onForgotPassword});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  UserRole _role = UserRole.employee;
  bool _remember = true;
  bool _obscure = true;
  final _emailCtrl =
      TextEditingController(text: 'jordan@riverside.events');
  final _passwordCtrl = TextEditingController(text: 'jordan@336');

  static const _quickCreds = {
    UserRole.employee: ('jordan@riverside.events', 'jordan@336'),
    UserRole.owner: ('selamvenda8@gmail.com', 'selam@336'),
  };

  void _applyQuickCreds(UserRole role) {
    final (email, password) = _quickCreds[role]!;
    _emailCtrl.text = email;
    _passwordCtrl.text = password;
  }

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
      eyebrow: 'Riverside Events Workspace',
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
                Text('SECURE WORKSPACE ACCESS',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: AppPalette.muted,
                    )),
                const SizedBox(height: 8),
                Text('Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Sign in to continue to Riverside Events.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),

                // Role toggle
                Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppPalette.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _RoleTab(
                        icon: Icons.person_outline,
                        label: 'Employee',
                        selected: _role == UserRole.employee,
                        onTap: () {
                          setState(() => _role = UserRole.employee);
                          _applyQuickCreds(UserRole.employee);
                        },
                      ),
                      _RoleTab(
                        icon: Icons.shield_outlined,
                        label: 'Owner',
                        selected: _role == UserRole.owner,
                        onTap: () {
                          setState(() => _role = UserRole.owner);
                          _applyQuickCreds(UserRole.owner);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Email
                const _FieldLabel('Work email'),
                const SizedBox(height: 7),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@riverside.events',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        size: 18, color: AppPalette.muted),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40),
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                const _FieldLabel('Password'),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => setState(() => _remember = !_remember),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 17,
                                height: 17,
                                child: Checkbox(
                                  value: _remember,
                                  onChanged: (v) =>
                                      setState(() => _remember = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text('Remember me',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      color: AppPalette.body,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: widget.onForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Forgot password?',
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
                                    _role == UserRole.employee
                                        ? 'Sign in as employee'
                                        : 'Sign in as owner',
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
                Text(
                  'By signing in, you agree to the workspace access policy.',
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

class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color:
            selected ? AppPalette.raise : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected
                        ? AppPalette.primary
                        : AppPalette.muted),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppPalette.primary
                          : AppPalette.muted,
                    )),
              ],
            ),
          ),
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
          color: AppPalette.ink,
        ));
  }
}
