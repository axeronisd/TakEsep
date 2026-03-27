import 'package:dio/dio.dart';

/// Interceptor that adds JWT bearer token to all requests
/// and handles token refresh on 401 responses.
class AuthInterceptor extends Interceptor {
  String? _accessToken;
  String? _refreshToken;
  final Future<Map<String, String>?> Function(String refreshToken)?
      onTokenRefresh;

  AuthInterceptor({
    String? accessToken,
    String? refreshToken,
    this.onTokenRefresh,
  })  : _accessToken = accessToken,
        _refreshToken = refreshToken;

  void updateTokens({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken ?? _accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        _refreshToken != null &&
        onTokenRefresh != null) {
      try {
        final tokens = await onTokenRefresh!(_refreshToken!);
        if (tokens != null) {
          _accessToken = tokens['access_token'];
          _refreshToken = tokens['refresh_token'] ?? _refreshToken;

          // Retry the original request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $_accessToken';
          final response = await Dio().fetch(options);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // Token refresh failed
      }
    }
    handler.next(err);
  }
}
