import 'package:flutter/material.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/chips.dart';
import '../../core/app_colors.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'password_recovery_screen.dart';
import '../../core/palette.dart';

/// Routes between sign-in, sign-up and password recovery without a
/// Navigator.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthView _view = _AuthView.signIn;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: switch (_view) {
        _AuthView.recovery => PasswordRecoveryView(
            key: const ValueKey('recovery'),
            onBack: () => setState(() => _view = _AuthView.signIn),
          ),
        _AuthView.signUp => SignUpView(
            key: const ValueKey('signup'),
            onBackToSignIn: () => setState(() => _view = _AuthView.signIn),
          ),
        _AuthView.signIn => SignInView(
            key: const ValueKey('signin'),
            onForgotPassword: () => setState(() => _view = _AuthView.recovery),
            onRegister: () => setState(() => _view = _AuthView.signUp),
          ),
      },
    );
  }
}

enum _AuthView { signIn, signUp, recovery }

/// Split hero + card layout shared by both auth screens.
class AuthScaffold extends StatelessWidget {
  final String eyebrow;
  final Widget card;
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1000;

    return Scaffold(
      backgroundColor: AppPalette.dark ? AppPalette.canvas : Colors.white,
      body: Stack(
        children: [
          // gradient blobs
          Positioned(
            top: -140,
            right: -120,
            child: _Blob(size: 460, colors: [
              AppPalette.blobA.withOpacity(0.85),
              AppPalette.blobB.withOpacity(0.2),
            ]),
          ),
          Positioned(
            bottom: -180,
            left: -160,
            child: _Blob(size: 520, colors: [
              AppPalette.blobB.withOpacity(0.9),
              AppPalette.blobC.withOpacity(0.5),
            ]),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 48 : 20, wide ? 22 : 16, 24, 0),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLockup(markSize: 24, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, heroConstraints) =>
                                    SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      48, 0, 32, 40),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight:
                                            heroConstraints.maxHeight),
                                    child: _Hero(eyebrow: eyebrow),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 460,
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 24),
                                  child: card,
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: card),
                        ),
                ),
                if (wide) const _Footer(wide: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String eyebrow;
  const _Hero({required this.eyebrow});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppPalette.muted,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: 'Run every rental\n',
                  style: TextStyle(color: AppPalette.ink)),
              TextSpan(
                  text: 'with confidence.',
                  style: TextStyle(color: AppPalette.primary)),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            'One calm, connected place for inventory, orders, customers, and the people who keep your events moving.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.5,
              height: 1.5,
              color: AppPalette.body.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const SizedBox(
              width: 92,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _HeroAvatar(
                      initials: 'JM',
                      color: AppColors.avatarGreen,
                      position: 0),
                  _HeroAvatar(
                      initials: 'AW',
                      color: AppColors.avatarPurple,
                      position: 1),
                  _HeroAvatar(
                      initials: 'MC',
                      color: AppColors.avatarBlue,
                      position: 2),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trusted by the whole team',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    )),
                const SizedBox(height: 2),
                Text('Secure access for every shift.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: AppPalette.muted,
                    )),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final int position;
  const _HeroAvatar({
    required this.initials,
    required this.color,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position * 23.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: AppPalette.dark ? AppPalette.raise : Colors.white,
              width: 2.5),
        ),
        child: InitialsAvatar(
            initials: initials, color: color, size: 32, fontSize: 11),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final List<Color> colors;
  const _Blob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: colors),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool wide;
  const _Footer({required this.wide});

  @override
  Widget build(BuildContext context) {
    final lock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: AppPalette.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text('Enterprise-grade workspace security',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppPalette.muted,
              )),
        ),
      ],
    );
    final help = Text('Need help? support@rentwise.app',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: AppPalette.muted,
        ));
    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [lock, const SizedBox(height: 6), help],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [lock, help],
      ),
    );
  }
}

/// Public footer so auth cards can reuse it on mobile.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key});

  @override
  Widget build(BuildContext context) => const _Footer(wide: false);
}
