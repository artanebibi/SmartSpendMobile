import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

class ApiClient {
  ApiClient._();

  static final _dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'any',
      },
    ),
  )..interceptors.add(_AuthInterceptor());

  static Dio get instance => _dio;
}

class _AuthInterceptor extends QueuedInterceptor {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('[HTTP] ${options.method} ${options.path} — token attached (${token.substring(0, 20)}...)');
    } else {
      debugPrint('[HTTP] ${options.method} ${options.path} — NO TOKEN');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final accessToken = prefs.getString(_accessKey);
        final refreshToken = prefs.getString(_refreshKey);

        if (accessToken == null || refreshToken == null) {
          return handler.next(err);
        }

        final response = await Dio().post(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.tokenRotate}',
          options: Options(headers: {
            'Authorization': 'Bearer $accessToken',
            'Refresh-Token': refreshToken,
            'ngrok-skip-browser-warning': 'any',
          }),
        );

        final newToken = response.data['access_token'] as String;
        await prefs.setString(_accessKey, newToken);

        // Retry original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        opts.headers['ngrok-skip-browser-warning'] = 'any';
        final retried = await Dio().fetch(opts);
        return handler.resolve(retried);
      } catch (_) {
        // Token refresh failed — let caller handle sign-out
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}

// Convenience helpers
extension ApiClientX on Dio {
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}
