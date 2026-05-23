import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class ProfileProvider extends ChangeNotifier {
  List<String> _currencies = [];
  bool _isLoading = false;

  List<String> get currencies => _currencies;
  bool get isLoading => _isLoading;

  final _dio = ApiClient.instance;

  Future<void> loadCurrencies() async {
    try {
      final res = await _dio.get(ApiEndpoints.currency);
      _currencies = List<String>.from(res.data['data'] as List? ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateCurrency(String currency) async {
    try {
      await _dio.patch(
        ApiEndpoints.userUpdate,
        data: {'preferred_currency': currency},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? username,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _dio.patch(ApiEndpoints.userUpdate, data: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (username != null) 'username': username,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
