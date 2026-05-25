import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletDetailScreen extends StatelessWidget {
  const WalletDetailScreen({super.key, required this.walletId});
  final String walletId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final wallet = provider.findById(walletId);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(backgroundColor: context.colors.bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final netBalances = provider.myNetBalances;
    final relevantBalances = netBalances.values
        .where((e) =>
            wallet.members.any((m) => m.name == e.member.name))
        .toList();
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, wallet)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                    child: _buildSummaryCard(wallet, symbol)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (relevantBalances.isNotEmpty)
                  SliverToBoxAdapter(
                      child: _buildBalanceAlert(
                          context, relevantBalances, provider, symbol)),
                if (relevantBalances.isNotEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildExpensesHeader()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (wallet.expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'No expenses yet.',
                            style:
                                GoogleFonts.inter(color: AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: wallet.expenses.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 60),
                          itemBuilder: (_, i) {
                            final exp = wallet.expenses.reversed
                                .toList()[i];
                            return _ExpenseRow(expense: exp, symbol: symbol);
                          },
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () =>
                    context.push('/home/wallets/$walletId/add-expense'),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Add Expense',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WalletModel wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              wallet.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(WalletModel wallet, String symbol) {
    final spent = wallet.totalSpent;
    final goal = wallet.monthlyGoal;
    final pct =
        goal != null && goal > 0 ? (spent / goal).clamp(0.0, 1.0) : null;

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
            Row(
              children: [
                _AvatarRow(members: wallet.members),
                const Spacer(),
                Text(
                  '${wallet.members.length} members',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TOTAL SPENT',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(spent, symbol: symbol),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (goal != null) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '/ ${CurrencyFormatter.format(goal, symbol: symbol)} goal',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (pct != null) ...[
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceAlert(BuildContext context,
      List<dynamic> balances, WalletProvider provider, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(AppColors.orange.withValues(alpha: 0.10), context.colors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balances',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ...balances.map((e) {
              final isOwed = e.amount > 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isOwed
                      ? '${e.member.name} owes you ${CurrencyFormatter.format(e.amount, symbol: symbol)}'
                      : 'You owe ${e.member.name} ${CurrencyFormatter.format(e.amount.abs(), symbol: symbol)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isOwed
                        ? AppColors.success
                        : const Color(0xFFD97706),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Expenses',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.members});
  final List<WalletMember> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    return Row(
      children: visible
          .map(
            (m) => Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: m.color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
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
          )
          .toList(),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.symbol});
  final WalletExpense expense;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final perPerson =
        expense.amount / expense.splitWith.length;
    final isMePayer = expense.payer.name == kMockMe.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: expense.payer.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                expense.payer.initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: expense.payer.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                ),
                Text(
                  '${expense.payer.name} paid · ${DateFormatter.groupLabel(expense.date)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(expense.amount, symbol: symbol),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.text,
                ),
              ),
              Text(
                isMePayer
                    ? '+${CurrencyFormatter.format(perPerson * (expense.splitWith.length - 1), symbol: symbol)}'
                    : '-${CurrencyFormatter.format(perPerson, symbol: symbol)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isMePayer ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
