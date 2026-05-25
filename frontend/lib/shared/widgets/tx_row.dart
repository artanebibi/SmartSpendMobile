import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/transactions/models/transaction_model.dart';
import 'category_dot.dart';

class TxRow extends StatelessWidget {
  const TxRow({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final amountText =
        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.price, symbol: symbol)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CategoryDot(category: transaction.categoryName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${transaction.categoryName} · ${DateFormatter.shortDate(transaction.dateMade)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isIncome ? AppColors.success : AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
