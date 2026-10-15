import 'package:flutter/material.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/chips.dart';
import '../../core/app_colors.dart';
import 'sign_in_screen.dart';
import 'password_recovery_screen.dart';

/// Routes between sign-in and password recovery without a Navigator.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _recovery = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _recovery
          ? PasswordRecoveryView(
              key: const ValueKey('recovery'),
              onBack: () => setState(() => _recovery = false),
            )
          : SignInView(
              key: const ValueKey('signin'),
              onForgotPassword: () => setState(() => _recovery = true),
            ),
    );
  }
}

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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // gradient blobs
          Positioned(
            top: -140,
            right: -120,
            child: _Blob(size: 460, colors: [
              AppColors.blobA.withOpacity(0.85),
              AppColors.blobB.withOpacity(0.2),
            ]),
          ),
          Positioned(
            bottom: -180,
            left: -160,
            child: _Blob(size: 520, colors: [
              AppColors.blobB.withOpacity(0.9),
              AppColors.blobC.withOpacity(0.5),
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
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: 'Run every rental\n',
                  style: TextStyle(color: AppColors.textDark)),
              TextSpan(
                  text: 'with confidence.',
                  style: TextStyle(color: AppColors.primary)),
            ],
          ),
          style: TextStyle(
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
              color: AppColors.textBody.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            SizedBox(
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
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trusted by the whole team',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    )),
                SizedBox(height: 2),
                Text('Secure access for every shift.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: AppColors.textMuted,
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
          border: Border.all(color: Colors.white, width: 2.5),
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
    const lock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: AppColors.textMuted),
        SizedBox(width: 6),
        Text('Enterprise-grade workspace security',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textMuted,
            )),
      ],
    );
    const help = Text('Need help? support@rentwise.app',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: AppColors.textMuted,
        ));
    if (!wide) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [lock, SizedBox(height: 6), help],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(48, 0, 48, 22),
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
