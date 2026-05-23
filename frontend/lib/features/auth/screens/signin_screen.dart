import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_status_bar.dart';
import '../providers/auth_provider.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppStatusBar(),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.darkText),
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
                        color: AppColors.secondaryBg,
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
                        color: AppColors.darkText,
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
                          color: const Color(0xFFFEF2F2),
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
                      icon: const Icon(Icons.g_mobiledata_rounded,
                          size: 24, color: Color(0xFF4285F4)),
                      label: 'Continue with Google',
                      bgColor: Colors.white,
                      textColor: AppColors.darkText,
                      borderColor: AppColors.border,
                    ),
                    const SizedBox(height: 12),

                    // Apple button
                    _AuthButton(
                      onTap: () async {
                        final ok = await auth.signInWithApple();
                        if (ok && context.mounted) {
                          context.go('/home/dashboard');
                        }
                      },
                      isLoading: false,
                      icon: const Icon(Icons.apple_rounded,
                          size: 24, color: Colors.white),
                      label: 'Continue with Apple',
                      bgColor: AppColors.darkText,
                      textColor: Colors.white,
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
