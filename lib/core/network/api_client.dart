// lib/core/network/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'mtls_client.dart';

const _wafSignatures = [
  'The requested URL was rejected',
  'Please consult with your administrator',
  'Your support ID is',
];

bool _isF5WafBlock(dynamic data) {
  if (data is! String) return false;
  return _wafSignatures.any((sig) => data.contains(sig));
}

String _extractSupportId(String body) {
  final match = RegExp(r'Your support ID is[:\s]+(\d+)', caseSensitive: false).firstMatch(body);
  return match != null ? match.group(1)! : '';
}

DioException _wafException(RequestOptions opts, String body) {
  final supportId = _extractSupportId(body);
  final msg = supportId.isNotEmpty
      ? 'Yêu cầu bị tường lửa (F5 WAF) chặn. Mã hỗ trợ: $supportId'
      : 'Yêu cầu bị tường lửa (F5 WAF) chặn. Vui lòng liên hệ quản trị viên.';
  return DioException(
    requestOptions: opts,
    type: DioExceptionType.badResponse,
    message: msg,
  );
}

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  // Single-flight lock: nhiều request 401 đồng thời chỉ trigger 1 lần refresh duy nhất,
  // tránh nhiều request cùng ghi đè jwt_token/refresh_token vào secure storage không đồng bộ.
  Future<bool>? _refreshingFuture;

  // Callback được set bởi app_router khi cần navigate về login
  static void Function(String route)? _navigateToLogin;
  static void setNavigateToLogin(void Function(String) cb) => _navigateToLogin = cb;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.resolvedApiUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    _applyMtls(_dio);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Phát hiện F5 WAF trả về HTML với status 200
        if (_isF5WafBlock(response.data)) {
          handler.reject(_wafException(response.requestOptions, response.data as String));
          return;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        // Retry tự động khi mất kết nối (stale keep-alive / backend restart)
        final isConnectionIssue =
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout;

        if (isConnectionIssue) {
          final retries = (error.requestOptions.extra['_retries'] as int?) ?? 0;
          if (retries < 2) {
            await Future.delayed(Duration(milliseconds: 600 * (retries + 1)));
            error.requestOptions.extra['_retries'] = retries + 1;
            try {
              final resp = await _dio.fetch(error.requestOptions);
              handler.resolve(resp);
              return;
            } catch (_) {
              // retry thất bại → fall through xử lý bình thường
            }
          }
        }

        // Phát hiện F5 WAF trả về HTML kèm status lỗi (403, v.v.)
        final responseData = error.response?.data;
        if (_isF5WafBlock(responseData)) {
          handler.next(_wafException(error.requestOptions, responseData as String));
          return;
        }

        if (error.response?.statusCode == 401) {
          // Dùng chung 1 Future refresh cho mọi request 401 đến đồng thời — tránh nhiều
          // request cùng gọi /api/auth/refresh và ghi đè lẫn nhau vào secure storage.
          final refreshed = await (_refreshingFuture ??= _tryRefresh().whenComplete(() {
            _refreshingFuture = null;
          }));
          if (refreshed) {
            // Retry với token mới
            final token = await _storage.read(key: 'jwt_token');
            final opts = error.requestOptions
              ..headers['Authorization'] = 'Bearer $token';
            try {
              final resp = await _dio.fetch(opts);
              handler.resolve(resp);
              return;
            } catch (_) {}
          }
          // Refresh thất bại → xóa session + về login
          await _storage.deleteAll();
          _navigateToLogin?.call('/login');
        }
        handler.next(error);
      },
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;

  // Gắn client certificate (mTLS) vào HttpClient của Dio, dùng cache đã preload từ
  // main() (xem preloadMtlsContext trong mtls_client.dart). Nếu cache chưa sẵn sàng
  // (preload thất bại hoặc chưa gọi) → fallback HttpClient thường, không chặn app,
  // vì JWT vẫn là lớp xác thực chính.
  void _applyMtls(Dio dio) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
        () => HttpClient(context: cachedMtlsSecurityContext);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;
    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.resolvedApiUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      _applyMtls(refreshDio);
      final resp = await refreshDio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
      final data = resp.data as Map<String, dynamic>;
      await _storage.write(key: 'jwt_token',     value: data['accessToken'] as String);
      await _storage.write(key: 'refresh_token', value: data['refreshToken'] as String);
      if (data['menus'] != null) {
        await _storage.write(key: 'user_menus', value: jsonEncode(data['menus']));
      }
      if (data['rights'] != null) {
        await _storage.write(key: 'user_rights', value: jsonEncode(data['rights']));
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
