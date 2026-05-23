import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.darkText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            '9:41',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          // Signal bars
          Icon(Icons.signal_cellular_alt, size: 16, color: color),
          const SizedBox(width: 4),
          // WiFi
          Icon(Icons.wifi, size: 16, color: color),
          const SizedBox(width: 4),
          // Battery
          Icon(Icons.battery_full, size: 16, color: color),
        ],
      ),
    );
  }
}
