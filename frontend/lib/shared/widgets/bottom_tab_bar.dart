import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _leftTabs = [
    _Tab(icon: Icons.home_rounded, label: 'HOME', path: '/home/dashboard'),
    _Tab(icon: Icons.bar_chart_rounded, label: 'STATS', path: '/home/stats'),
  ];

  static const _rightTabs = [
    _Tab(icon: Icons.track_changes_rounded, label: 'SAVINGS', path: '/home/savings'),
    _Tab(icon: Icons.person_rounded, label: 'PROFILE', path: '/home/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                ..._leftTabs.map((tab) {
                  final active = location.startsWith(tab.path);
                  return Expanded(child: _buildTab(context, tab, active));
                }),
                _buildScanButton(context),
                ..._rightTabs.map((tab) {
                  final active = location.startsWith(tab.path);
                  return Expanded(child: _buildTab(context, tab, active));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, _Tab tab, bool active) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(tab.path),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tab.icon, size: 22, color: active ? AppColors.primary : AppColors.muted),
          const SizedBox(height: 3),
          Text(
            tab.label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    return Expanded(
      child: _buildTab(
        context,
        const _Tab(
          icon: Icons.camera_alt_rounded,
          label: 'SCAN',
          path: '/home/transactions/scan',
        ),
        false,
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
