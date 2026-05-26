import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/user_model.dart';
import 'dart:io';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  final _dio = ApiClient.instance;
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  bool get supportsAppleSignIn => Platform.isIOS || Platform.isMacOS;

  Future<void> tryRestoreSession() async {
    try {
      // Reject session if refresh token is already expired
      final prefs = await SharedPreferences.getInstance();
      final expiryStr = prefs.getString('refresh_token_expiry') ?? '';
      if (expiryStr.isNotEmpty) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          await ApiClientX.clearTokens();
          _isInitialized = true;
          notifyListeners();
          return;
        }
      }

      final token = await ApiClientX.getAccessToken();
      if (token == null) {
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // The interceptor will auto-refresh a stale access token on 401
      final res = await _dio.get(ApiEndpoints.userMe);
      final data = res.data['data'];
      if (data != null && data is Map<String, dynamic>) {
        _user = UserModel.fromJson(data);
      }
    } on DioException catch (e) {
      // Only invalidate the session for auth failures, not network errors.
      // A timeout or connection refused keeps the user logged in so they
      // aren't forced to re-authenticate every time the backend is briefly unavailable.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await ApiClientX.clearTokens();
      } else {
        // Network error — assume tokens are still valid, let the user in
        _user = null;
      }
    } catch (_) {
      // Unexpected error — don't clear tokens, fail open
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _setLoading(false);
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Missing Google ID token');

      final res = await _dio.post(
        ApiEndpoints.authGoogle,
        data: {'id_token': idToken},
      );

      await _handleAuthResponse(res.data);
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      debugPrint('[Auth] DioException: status=${e.response?.statusCode} body=${e.response?.data}');
      _error = e.response?.data?['message'] ?? 'Google sign-in failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    _setLoading(true);
    try {
      // Apple Sign In will be wired up per-platform
      // Placeholder — real implementation uses sign_in_with_apple package
      _error = 'Apple sign-in not yet configured on this platform';
      _setLoading(false);
      return false;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _dio.post(ApiEndpoints.authLogout);
    } catch (_) {}
    await _googleSignIn.signOut();
    await ApiClientX.clearTokens();
    _user = null;
    _setLoading(false);
  }

  void updatePreferredCurrency(String currency) {
    if (_user == null) return;
    _user = _user!.copyWith(preferredCurrency: currency);
    notifyListeners();
  }

  Future<void> refreshBalances() async {
    if (_user == null) return;
    try {
      final res = await _dio.get(ApiEndpoints.userBalances);
      final data = res.data['data'] as Map<String, dynamic>;
      _user = _user!.copyWith(
        balance: (data['balance'] as num).toDouble(),
        monthlySavingGoal: (data['monthly_saving_goal'] as num).toDouble(),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> body) async {
    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw Exception('Invalid auth response: missing tokens');
    }

    await ApiClientX.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'refresh_token_expiry',
      body['refresh_token_expiry_date']?.toString() ?? '',
    );

    // Backend uses 'user_data' key (not 'data')
    final data = body['user_data'] ?? body['data'];
    debugPrint('[Auth] user_data from auth response: $data');

    if (data != null && data is Map<String, dynamic>) {
      _user = UserModel.fromJson(data);
    } else {
      debugPrint('[Auth] user_data null — falling back to GET ${ApiEndpoints.userMe}');
      try {
        final res = await _dio.get(ApiEndpoints.userMe);
        debugPrint('[Auth] GET userMe → status ${res.statusCode} body: ${res.data}');
        final meData = res.data['data'] ?? res.data['user_data'];
        if (meData != null && meData is Map<String, dynamic>) {
          _user = UserModel.fromJson(meData);
        }
      } on DioException catch (e) {
        debugPrint('[Auth] GET userMe DioException: type=${e.type} status=${e.response?.statusCode} body=${e.response?.data} message=${e.message}');
        // Tokens are saved — don't block login, user data will load on next app launch
      }
    }

    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    if (v) _error = null;
    notifyListeners();
  }
}
