import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../state/workspace_state.dart';
import 'auth_scaffold.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';

/// Sign-up screen — the ONE-TIME owner bootstrap.
///
/// Creates the Appwrite account, signs it in and writes the owner
/// profile. Registration is refused once the workspace has an owner
/// (RegistrationClosedException → inline error): employee accounts are
/// created by the owner from the Owner Dashboard → Access & roles, so
/// credentials are always issued by the owner, never self-service.
class SignUpView extends StatefulWidget {
  final VoidCallback onBackToSignIn;
  const SignUpView({super.key, required this.onBackToSignIn});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  bool _obscure = true;
  bool _obscureConfirm = true;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<WorkspaceState>();
    setState(() => _formError = null);

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty) {
      setState(() => _formError = 'Enter your full name.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _formError = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _formError =
          'Password must be at least 8 characters (Appwrite requirement).');
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _formError = 'Passwords do not match.');
      return;
    }

    await state.signUpWithEmail(name, email, password);
    // Success flips AuthGate to the workspace shell; failures render
    // via state.authError below.
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final error = _formError ?? state.authError;

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
                icon: Icons.person_add_alt_1_outlined,
                color: AppPalette.primary,
                bg: AppPalette.primarySoft,
                size: 42),
            const SizedBox(height: 16),
            Text('CREATE THE OWNER ACCOUNT',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: AppPalette.muted,
                )),
            const SizedBox(height: 8),
            Text('Register your workspace',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
                'This one-time registration creates your OWNER account. '
                'Employee accounts are added later by you, from the '
                'Owner Dashboard → Access & roles.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),

            // Name
            const _FieldLabel('Full name'),
            const SizedBox(height: 7),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Tinsae Abeba',
                prefixIcon: Icon(Icons.badge_outlined,
                    size: 18, color: AppPalette.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40),
              ),
            ),
            const SizedBox(height: 14),

            // Email
            const _FieldLabel('Work email'),
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
            const SizedBox(height: 14),

            // Confirm
            const _FieldLabel('Confirm password'),
            const SizedBox(height: 7),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppPalette.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppPalette.muted,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (error != null) ...[
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
                      child: Text(error,
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
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add_alt_1_rounded,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 9),
                              Text(
                                'Create owner account',
                                style: TextStyle(
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text('Already have an account?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: AppPalette.body)),
                ),
                TextButton(
                  onPressed: widget.onBackToSignIn,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Sign in',
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
          color: AppPalette.ink,
        ));
  }
}
