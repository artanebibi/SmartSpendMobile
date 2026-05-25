import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletListScreen extends StatelessWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final wallets = provider.wallets;
    final totalOwed = provider.totalOwed;
    final totalOwedToMe = provider.totalOwedToMe;
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (totalOwed > 0 || totalOwedToMe > 0)
              SliverToBoxAdapter(
                child: _buildSettlementAlert(context, totalOwed, totalOwedToMe, symbol),
              ),
            if (totalOwed > 0 || totalOwedToMe > 0)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (wallets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No wallets yet. Tap + to create one.',
                    style: GoogleFonts.inter(color: AppColors.muted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WalletCard(
                        wallet: wallets[i],
                        symbol: symbol,
                        onTap: () =>
                            context.push('/home/wallets/${wallets[i].id}'),
                      ),
                    ),
                    childCount: wallets.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Shared Wallets',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.text,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/home/wallets/create'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementAlert(
      BuildContext context, double totalOwed, double totalOwedToMe, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(AppColors.orange.withValues(alpha: 0.10), context.colors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (totalOwed > 0)
                    Text(
                      'You owe ${CurrencyFormatter.format(totalOwed, symbol: symbol)} total',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  if (totalOwedToMe > 0)
                    Text(
                      '${CurrencyFormatter.format(totalOwedToMe, symbol: symbol)} owed to you',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/home/wallets/settle'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Settle Up',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.symbol, required this.onTap});
  final WalletModel wallet;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spent = wallet.totalSpent;
    final goal = wallet.monthlyGoal;
    final pct = goal != null && goal > 0
        ? (spent / goal).clamp(0.0, 1.0)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _AvatarStack(members: wallet.members),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                      Text(
                        '${wallet.members.length} members',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(spent, symbol: symbol),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    Text(
                      'total spent',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: context.colors.bg,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${CurrencyFormatter.format(spent, symbol: symbol)} of ${CurrencyFormatter.format(goal!, symbol: symbol)} goal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});
  final List<WalletMember> members;

  static const _size = 32.0;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(4).toList();
    final totalWidth = _size + (visible.length - 1) * (_size - _overlap);

    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        children: visible.asMap().entries.map((e) {
          final m = e.value;
          return Positioned(
            left: e.key * (_size - _overlap),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: m.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  m.initials,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
