import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, Colors.white, Colors.transparent),
      AppButtonVariant.secondary => (AppColors.secondaryBg, AppColors.primary, Colors.transparent),
      AppButtonVariant.danger => (const Color(0xFFFEF2F2), AppColors.error, Colors.transparent),
      AppButtonVariant.outline => (Colors.transparent, AppColors.primary, AppColors.primary),
    };

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: variant == AppButtonVariant.outline ? 2 : 0),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
