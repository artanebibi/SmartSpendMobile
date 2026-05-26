import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/services/exchange_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/transactions/providers/transaction_provider.dart';
// MAKE SURE TO IMPORT YOUR SAVINGS PROVIDER HERE:
import '../../../features/savings/providers/savings_provider.dart';
import '../../../shared/widgets/tx_row.dart';
import '../../savings/screens/total_saved_progress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshBalances();
      context.read<TransactionProvider>().load();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final exchangeSvc = context.watch<ExchangeRateService>();
    final savingsProvider = context.watch<SavingsProvider>();

    final user = auth.user;
    final currency = user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);

    // Balance data
    final balance = exchangeSvc.convertFromMkd(user?.balance ?? 0.0, currency);
    final savingGoal = exchangeSvc.convertFromMkd(user?.monthlySavingGoal ?? 0.0, currency);
    final (intPart, decPart) = CurrencyFormatter.splitAmount(balance);

    // Savings data
    final saved = exchangeSvc.convertFromMkd(savingsProvider.totalSaved, currency);
    final target = exchangeSvc.convertFromMkd(savingsProvider.totalTarget, currency);
    final pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    // Income / Expense data
    final txs = txProvider.transactions;
    final totalIncome = exchangeSvc.convertFromMkd(txs.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.price), currency);
    final totalExpense = exchangeSvc.convertFromMkd(txs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.price), currency);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(user?.fullName ?? 'there', user?.initials ?? ''),
                  const SizedBox(height: 16),

                  // THE SMART CHOICE: One master card to rule them all
                  _buildCombinedBalanceCard(
                    intPart: intPart,
                    decPart: decPart,
                    symbol: symbol,
                    savingGoal: savingGoal,
                    savedLabel: CurrencyFormatter.format(saved, symbol: symbol),
                    targetLabel: CurrencyFormatter.format(target, symbol: symbol),
                    pct: pct,
                    pctLabel: pctLabel,
                  ),

                  const SizedBox(height: 12),
                  _buildIncomeExpenseRow(income: totalIncome, expense: totalExpense, symbol: symbol),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildRecentHeader(context),
                  const SizedBox(height: 8),
                  _buildRecentTransactions(context, txProvider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedBalanceCard({
    required String intPart,
    required String decPart,
    required String symbol,
    required double savingGoal,
    required String savedLabel,
    required String targetLabel,
    required double pct,
    required String pctLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Header
            Text(
              'TOTAL BALANCE',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(symbol, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(width: 2),
                Text(intPart, style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('.$decPart', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              savingGoal > 0
                  ? '↑ ${CurrencyFormatter.format(savingGoal, symbol: symbol)} monthly saving goal'
                  : '↑ Set a monthly saving goal in Profile',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SAVINGS GOALS',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1),
                ),
                Text(
                  pctLabel,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$savedLabel saved of $targetLabel target',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildGreeting(String name, String initials) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_greeting()}, $name 👋',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.text,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.balanceGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String intPart,
    required String decPart,
    required String symbol,
    required double savingGoal,
    required String currency,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL BALANCE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  symbol,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  intPart,
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '.$decPart',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              savingGoal > 0
                  ? '↑ ${CurrencyFormatter.format(savingGoal, symbol: symbol)} monthly saving goal'
                  : '↑ Set a monthly saving goal in Profile',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseRow({
    required double income,
    required double expense,
    required String symbol,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.success,
              label: 'Income',
              amount: CurrencyFormatter.format(income, symbol: symbol),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.error,
              label: 'Expenses',
              amount: CurrencyFormatter.format(expense, symbol: symbol),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.add_rounded, color: AppColors.primary, label: 'Add',
          onTap: () => context.push('/home/transactions/add')),
      _QuickAction(icon: Icons.credit_card_rounded, color: AppColors.orange, label: 'Transfers',
          onTap: () => context.go('/home/transactions')),
      _QuickAction(icon: Icons.flag_rounded, color: AppColors.success, label: 'Goal',
          onTap: () => context.push('/home/savings/create')),
      _QuickAction(icon: Icons.account_balance_wallet_rounded, color: AppColors.purple, label: 'Wallet',
          onTap: () => context.go('/home/wallets')),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: actions
              .map(
                (a) => Expanded(
              child: GestureDetector(
                onTap: a.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        a.icon,
                        color: a.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Recent Transactions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.text,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/home/transactions'),
            child: Text(
              'See All',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, TransactionProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final recent = provider.recent;

    if (recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'No transactions yet. Tap Add to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recent.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
          itemBuilder: (_, i) => TxRow(
            transaction: recent[i],
            onTap: () =>
                context.push('/home/transactions/${recent[i].id}'),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final bg = Color.alphaBlend(
      iconColor.withValues(alpha: 0.10),
      context.colors.card,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}