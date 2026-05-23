import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_status_bar.dart';
import '../../../shared/widgets/tx_row.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'all';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadForMonth());
  }

  void _loadForMonth() {
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);
    context.read<TransactionProvider>().load(from: from, to: to);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
      _loadForMonth();
    }
  }

  List<TransactionModel> _filtered(List<TransactionModel> txs) {
    return switch (_filter) {
      'income' => txs.where((t) => t.isIncome).toList(),
      'expense' => txs.where((t) => t.isExpense).toList(),
      _ => txs,
    };
  }

  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> txs) {
    final map = <String, List<TransactionModel>>{};
    for (final tx in txs) {
      final label = DateFormatter.groupLabel(tx.dateMade);
      (map[label] ??= []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final filtered = _filtered(provider.transactions);
    final grouped = _groupByDate(filtered);
    final groups = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: const AppStatusBar()),
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildFilterRow()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),

                if (provider.isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No transactions found.',
                        style: GoogleFonts.inter(color: AppColors.muted),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildGroup(ctx, groups[i], grouped[groups[i]]!),
                      childCount: groups.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // FAB
            Positioned(
              bottom: 88 + 16,
              right: 20,
              child: GestureDetector(
                onTap: () => context.push('/home/transactions/add'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
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
            'Transactions',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormatter.monthYear(_month),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = [
      ('all', 'All'),
      ('income', 'Income'),
      ('expense', 'Expense'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: filters.map((f) {
          final active = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                f.$2,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.darkText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroup(
      BuildContext context, String label, List<TransactionModel> txs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 68),
              itemBuilder: (_, i) => TxRow(
                transaction: txs[i],
                onTap: () =>
                    context.push('/home/transactions/${txs[i].id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
