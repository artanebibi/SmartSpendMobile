import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _baseUrl = 'https://api.frankfurter.dev/v2';

  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  // Cache keyed as '{code}_MKD' → rate (how many MKD per 1 unit of code).
  // Only one direction is stored; convertFromMkd divides by this rate.
  final Map<String, double> _cache = {};
  // Track in-progress fetches to avoid duplicate concurrent requests
  final Map<String, Future<void>> _pending = {};

  bool isRateLoaded(String currency) {
    final code = currency.toUpperCase();
    return code == 'MKD' || _cache.containsKey('${code}_MKD');
  }

  /// Pre-fetches and caches MKD ↔ [currency] rates.
  /// Deduplicates concurrent calls for the same currency.
  Future<void> prefetchRate(String currency) async {
    final code = currency.toUpperCase();
    if (code == 'MKD' || _cache.containsKey('${code}_MKD')) return;
    _pending[code] ??= _fetch(code).whenComplete(() => _pending.remove(code));
    await _pending[code];
  }

  Future<void> _fetch(String code) async {
    try {
      final res = await _dio.get('$_baseUrl/rate/$code/MKD');
      final rate = (res.data['rate'] as num).toDouble();
      _cache['${code}_MKD'] = rate; // how many MKD per 1 unit of code
      notifyListeners();
    } catch (e) {
      debugPrint('[ExchangeRateService] Failed to fetch $code→MKD: $e');
    }
  }

  /// Synchronous — uses cached rate. Falls back to 1.0 if rate not yet loaded.
  double convertFromMkd(double amount, String currency) {
    final code = currency.toUpperCase();
    if (code == 'MKD') return amount;
    final r = _cache['${code}_MKD'] ?? 1.0;
    return amount / r; // exact inverse of convertToMkd
  }

  /// Synchronous — uses cached rate. Falls back to 1.0 if rate not yet loaded.
  double convertToMkd(double amount, String currency) {
    final code = currency.toUpperCase();
    if (code == 'MKD') return amount;
    return amount * (_cache['${code}_MKD'] ?? 1.0);
  }

  /// Converts [amount] from the user's preferred currency to MKD for DB storage.
  Future<double> exchangeForDbStore(
      double amount, String userPreferredCurrency) async {
    await prefetchRate(userPreferredCurrency);
    return convertToMkd(amount, userPreferredCurrency);
  }

  /// Converts [amount] from MKD to the user's preferred currency for UI display.
  Future<double> exchangeForUiDisplay(
      double amount, String userPreferredCurrency) async {
    await prefetchRate(userPreferredCurrency);
    return convertFromMkd(amount, userPreferredCurrency);
  }
}
