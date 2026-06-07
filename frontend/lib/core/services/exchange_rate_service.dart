import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _baseUrl = 'https://api.frankfurter.dev/v2';

  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  // Cache keyed as 'MKD_USD' → rate and 'USD_MKD' → inverse rate
  final Map<String, double> _cache = {};
  // Track in-progress fetches to avoid duplicate concurrent requests
  final Map<String, Future<void>> _pending = {};

  bool isRateLoaded(String currency) {
    final code = currency.toUpperCase();
    return code == 'MKD' || _cache.containsKey('MKD_$code');
  }

  /// Pre-fetches and caches MKD ↔ [currency] rates.
  /// Deduplicates concurrent calls for the same currency.
  Future<void> prefetchRate(String currency) async {
    final code = currency.toUpperCase();
    if (code == 'MKD' || _cache.containsKey('MKD_$code')) return;
    _pending[code] ??= _fetch(code).whenComplete(() => _pending.remove(code));
    await _pending[code];
  }

  Future<void> _fetch(String code) async {
    try {
      final res = await _dio.get('$_baseUrl/rate/MKD/$code');
      final rate = (res.data['rate'] as num).toDouble();
      _cache['MKD_$code'] = rate;
      _cache['${code}_MKD'] = 1.0 / rate;
      notifyListeners();
    } catch (e) {
      debugPrint('[ExchangeRateService] Failed to fetch MKD→$code: $e');
    }
  }

  /// Synchronous — uses cached rate. Falls back to 1.0 if rate not yet loaded.
  double convertFromMkd(double amount, String currency) {
    final code = currency.toUpperCase();
    if (code == 'MKD') return amount;
    return amount * (_cache['MKD_$code'] ?? 1.0);
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
