import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/category_dot.dart';
import '../models/transaction_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final tx = provider.transactions.where((t) => t.id == id).firstOrNull;

    if (tx == null) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(
          backgroundColor: context.colors.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: context.colors.text),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _DetailBody(tx: tx);
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.tx});
  final TransactionModel tx;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete transaction?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      final ok = await context.read<TransactionProvider>().delete(tx.id);
      if (context.mounted) {
        if (ok) {
          authProvider.refreshBalances();
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<TransactionProvider>().error ??
                    'Failed to delete transaction.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final amountStr =
        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.price)}';

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  Expanded(
                    child: Center(
                      child: Text(
                        'Transaction Detail',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Hero amount card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          CategoryDot(category: tx.categoryName, size: 60),
                          const SizedBox(height: 12),
                          Text(
                            amountStr,
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: isIncome
                                  ? AppColors.success
                                  : context.colors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                (isIncome ? AppColors.success : AppColors.error)
                                    .withValues(alpha: 0.12),
                                context.colors.card,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tx.type.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isIncome
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Detail rows
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(label: 'Title', value: tx.title),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _DetailRow(
                              label: 'Category', value: tx.categoryName),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _DetailRow(
                              label: 'Date',
                              value: DateFormatter.dayMonthYear(tx.dateMade)),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _DetailRow(
                              label: 'Amount',
                              value: CurrencyFormatter.format(tx.price)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Delete button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _delete(context),
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.alphaBlend(
                            AppColors.error.withValues(alpha: 0.12),
                            context.colors.card,
                          ),
                          foregroundColor: AppColors.error,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Edit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTransactionScreen(initial: tx),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Edit Transaction',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
