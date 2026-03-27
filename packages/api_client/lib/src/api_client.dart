import 'package:dio/dio.dart';
import 'package:takesep_core/takesep_core.dart';
import 'auth_interceptor.dart';

/// Central API client for the TakEsep ecosystem.
/// All product apps use this to communicate with backend services.
class TakEsepApiClient {
  late final Dio _dio;

  TakEsepApiClient({
    String? baseUrl,
    AuthInterceptor? authInterceptor,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? TakEsepConstants.apiBaseUrlDev,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  Dio get dio => _dio;

  // ─── Auth endpoints ──────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── Generic CRUD helpers ────────────────────────────────
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? data}) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? data}) async {
    final response = await _dio.put(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }
}
