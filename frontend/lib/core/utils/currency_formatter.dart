import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static const _symbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'MKD': 'MKD ',
    'CHF': 'CHF ',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'BRL': 'R\$',
    'SEK': 'kr ',
    'NOK': 'kr ',
    'DKK': 'kr ',
    'PLN': 'zł ',
    'CZK': 'Kč ',
    'HUF': 'Ft ',
    'RON': 'lei ',
    'BGN': 'лв ',
    'HRK': 'kn ',
    'RSD': 'din ',
    'TRY': '₺',
    'RUB': '₽',
    'UAH': '₴',
    'KZT': '₸',
  };

  /// Returns the symbol for a given ISO 4217 currency code.
  /// Falls back to the code itself when the symbol is unknown.
  static String symbolFor(String code) =>
      _symbols[code.toUpperCase()] ?? '$code ';

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
