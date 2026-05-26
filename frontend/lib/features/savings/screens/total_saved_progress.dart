import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class TotalSavedProgress extends StatelessWidget {
  const TotalSavedProgress({
    super.key,
    required this.saved,
    required this.target,
    required this.pct,
    required this.pctLabel,
  });

  final String saved;
  final String target;
  final double pct;
  final String pctLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient, // Same gradient color
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL SAVED',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  saved,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '/ $target',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pctLabel of total goals reached',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}