import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../providers/auth_provider.dart';

const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
  <path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>
  <path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
  <path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303c-.792 2.237-2.231 4.166-4.087 5.571l6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>
</svg>
''';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: context.colors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.colors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your SmartSpend account',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Error message
                    if (auth.error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            AppColors.error.withValues(alpha: 0.12),
                            context.colors.card,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          auth.error!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Google button
                    _AuthButton(
                      onTap: () async {
                        final ok = await auth.signInWithGoogle();
                        if (ok && context.mounted) {
                          context.go('/home/dashboard');
                        }
                      },
                      isLoading: auth.isLoading,
                      icon: SvgPicture.string(_googleLogoSvg, width: 22, height: 22),
                      label: 'Continue with Google',
                      bgColor: context.colors.card,
                      textColor: context.colors.text,
                      borderColor: context.colors.border,
                    ),
                    const SizedBox(height: 12),

                    // Apple button
                    if (context.read<AuthProvider>().supportsAppleSignIn)
                      _AuthButton(
                        onTap: () async {
                          final ok = await auth.signInWithApple();
                          if (ok && context.mounted) {
                            context.go('/home/dashboard');
                          }
                        },
                        isLoading: false,
                        icon: const Icon(Icons.apple_rounded, size: 24, color: Colors.white),
                        label: 'Continue with Apple',
                        bgColor: context.colors.text,
                        textColor: context.colors.card,
                        borderColor: Colors.transparent,
                      ),

                    const SizedBox(height: 32),
                    Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.onTap,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });

  final VoidCallback onTap;
  final bool isLoading;
  final Widget icon;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
