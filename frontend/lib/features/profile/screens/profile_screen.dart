import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../savings/providers/savings_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildUserCard(context, auth)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildStatsRow(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionLabel('ACCOUNT')),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
            SliverToBoxAdapter(
              child: _buildSettingsGroup([
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.primary,
                  label: 'Edit Profile',
                  onTap: () => _showEditProfile(context, auth),
                ),
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  iconBg: Color.alphaBlend(AppColors.cyan.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.cyan,
                  label: 'Notification Settings',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  iconBg: Color.alphaBlend(AppColors.purple.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.purple,
                  label: 'Privacy',
                  onTap: () {},
                ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionLabel('PREFERENCES')),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
            SliverToBoxAdapter(
              child: _buildSettingsGroup([
                _SettingsRow(
                  icon: Icons.currency_exchange_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.primary,
                  label: 'Currency',
                  trailing: Text(
                    user?.preferredCurrency ?? 'USD',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => _showCurrencyPicker(context),
                ),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  iconBg: Color.alphaBlend(AppColors.orange.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.orange,
                  label: context.watch<ThemeProvider>().isDark ? 'Dark Mode' : 'Light Mode',
                  onTap: () => context.read<ThemeProvider>().toggle(),
                ),
                _SettingsRow(
                  icon: Icons.language_rounded,
                  iconBg: Color.alphaBlend(AppColors.success.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.success,
                  label: 'Language',
                  onTap: () {},
                ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionLabel('ABOUT')),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
            SliverToBoxAdapter(
              child: _buildSettingsGroup([
                _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  iconBg: Color.alphaBlend(AppColors.cyan.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.cyan,
                  label: 'Help & Support',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.star_outline_rounded,
                  iconBg: Color.alphaBlend(AppColors.amber.withValues(alpha: 0.12), context.colors.card),
                  iconColor: AppColors.amber,
                  label: 'Rate App',
                  onTap: () {},
                ),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  iconBg: context.colors.bg,
                  iconColor: AppColors.muted,
                  label: 'Terms & Privacy',
                  onTap: () {},
                ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
                child: _buildSignOutButton(context, auth)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          'Profile',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.colors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    final initials = user?.initials ?? 'U';
    final name = user?.fullName ?? 'User';
    final email = user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Premium Plan',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final txCount =
        context.watch<TransactionProvider>().transactions.length;
    final goalCount =
        context.watch<SavingsProvider>().savings.length;
    final walletCount =
        context.watch<WalletProvider>().wallets.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(value: txCount.toString(), label: 'Transactions'),
          const SizedBox(width: 12),
          _StatCard(value: goalCount.toString(), label: 'Goals'),
          const SizedBox(width: 12),
          _StatCard(value: walletCount.toString(), label: 'Wallets'),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> rows) {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 56),
          itemBuilder: (_, i) => rows[i],
        ),
      ),
    ));
  }

  Widget _buildSignOutButton(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) context.go('/');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEF2F2),
            foregroundColor: AppColors.error,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(
            'Sign Out',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    const currencies = ['USD', 'MKD', 'EUR', 'GBP'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool updating = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Currency',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 12),
                ...currencies.map(
                  (c) => ListTile(
                    title: Text(c,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: updating
                        ? null
                        : () async {
                            setSheetState(() => updating = true);
                            final ok = await ctx
                                .read<ProfileProvider>()
                                .updateCurrency(c);
                            if (ok && context.mounted) {
                              context
                                  .read<AuthProvider>()
                                  .updatePreferredCurrency(c);
                              context
                                  .read<ExchangeRateService>()
                                  .prefetchRate(c);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfile(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    final firstCtrl =
        TextEditingController(text: user?.firstName ?? '');
    final lastCtrl =
        TextEditingController(text: user?.lastName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            _sheetInput(firstCtrl, 'First name'),
            const SizedBox(height: 12),
            _sheetInput(lastCtrl, 'Last name'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<ProfileProvider>().updateProfile(
                        firstName: firstCtrl.text.trim(),
                        lastName: lastCtrl.text.trim(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Save',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetInput(TextEditingController ctrl, String label) {
    return Builder(
      builder: (context) => TextField(
        controller: ctrl,
        style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
          filled: true,
          fillColor: context.colors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.colors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text,
                ),
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
