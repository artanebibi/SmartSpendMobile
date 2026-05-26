import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/services/exchange_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/saving_model.dart';
import '../providers/savings_provider.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SavingsProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final exchangeSvc = context.watch<ExchangeRateService>();

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            if (provider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverToBoxAdapter(child: _buildTotalCard(provider, symbol, exchangeSvc, currency)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (provider.savings.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No goals yet. Tap + to create one.',
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
                        child: _GoalCard(
                          goal: provider.savings[i],
                          symbol: symbol,
                          exchangeSvc: exchangeSvc,
                          currency: currency,
                          onTap: () => context
                              .push('/home/savings/${provider.savings[i].id}'),
                        ),
                      ),
                      childCount: provider.savings.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: [
          Text(
            'Savings Goals',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.text,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/home/savings/create'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(SavingsProvider provider, String symbol,
      ExchangeRateService exchangeSvc, String currency) {
    final saved = exchangeSvc.convertFromMkd(provider.totalSaved, currency);
    final target = exchangeSvc.convertFromMkd(provider.totalTarget, currency);
    final pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient,
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
                  CurrencyFormatter.format(saved, symbol: symbol),
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
                    '/ ${CurrencyFormatter.format(target, symbol: symbol)}',
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
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.symbol,
    required this.exchangeSvc,
    required this.currency,
    required this.onTap,
  });
  final SavingModel goal;
  final String symbol;
  final ExchangeRateService exchangeSvc;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 1. Calculate percentage using currentAmount vs targetAmount
    final currentProgress = goal.currentAmount ?? 0.0;
    final target = goal.targetAmount;

    final pct = target > 0 ? (currentProgress / target).clamp(0.0, 1.0) : 0.0;
    final isDone = currentProgress >= target && target > 0;

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
                // Icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.track_changes_rounded,
                    color: goal.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + deadline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                      if (goal.deadline != null)
                        Text(
                          'Due ${DateFormatter.dayMonthYear(goal.deadline!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Done badge or percentage
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        AppColors.success.withValues(alpha: 0.12),
                        context.colors.card,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 11, color: AppColors.success),
                        const SizedBox(width: 3),
                        Text(
                          'DONE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: context.colors.bg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? AppColors.success : goal.color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Saved / Target labels
            Row(
              children: [
                Text(
                  '${CurrencyFormatter.format(exchangeSvc.convertFromMkd(currentProgress, currency), symbol: symbol)} saved',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.muted),
                ),
                const Spacer(),
                Text(
                  'Target ${CurrencyFormatter.format(exchangeSvc.convertFromMkd(target, currency), symbol: symbol)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}