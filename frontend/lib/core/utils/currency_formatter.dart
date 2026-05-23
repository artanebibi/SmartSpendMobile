import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String symbol = '\$'}) {
    final formatted = NumberFormat('#,##0.00').format(amount.abs());
    return '$symbol$formatted';
  }

  static String compact(double amount, {String symbol = '\$'}) {
    if (amount.abs() >= 1000) {
      return '$symbol${(amount.abs() / 1000).toStringAsFixed(1)}k';
    }
    return format(amount, symbol: symbol);
  }

  /// Splits a dollar amount into integer and decimal parts for big display.
  static (String, String) splitAmount(double amount) {
    final parts = amount.abs().toStringAsFixed(2).split('.');
    return (parts[0], parts[1]);
  }
}
