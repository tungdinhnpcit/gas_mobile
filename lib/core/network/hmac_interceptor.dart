// lib/core/network/hmac_interceptor.dart
// Ký mọi request bằng HMAC-SHA256 trước khi gửi — cộng thêm lớp chống giả mạo/replay
// khi server không dùng HTTPS (không đảm bảo confidentiality, chỉ integrity + chống
// replay). Backend chỉ enforce khi request đi qua gateway /apiv2/ (nginx gắn header
// X-Gateway-Route: apiv2 — xem BE/nginx/quanlygasapp.conf + HmacSigningMiddleware).
//
// Secret nhúng qua compile-time define, KHÔNG hardcode trong source (giống pattern
// MTLS_P12_PASSWORD): flutter build apk --dart-define=HMAC_MOBILE_SECRET=xxx
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const _hmacSecret = String.fromEnvironment('HMAC_MOBILE_SECRET', defaultValue: '');

String _generateNonce() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return base64Url.encode(bytes);
}

class HmacInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_hmacSecret.isEmpty) {
      // Chưa cấu hình secret (build không truyền --dart-define) — bỏ qua, request
      // vẫn gửi được nhưng sẽ bị backend từ chối nếu đi qua /apiv2 (đúng ý đồ:
      // build thiếu secret không nên vô tình pass được gateway có enforce HMAC).
      handler.next(options);
      return;
    }

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _generateNonce();

    // QUAN TRỌNG: dùng options.path (chuỗi relative path gốc truyền vào dio.post(...),
    // ví dụ '/api/auth/login') — KHÔNG dùng options.uri.path (đã ghép baseUrl, sẽ có
    // thêm prefix '/apiv2'). nginx location /apiv2/ strip prefix trước khi proxy tới
    // backend, nên backend nhận đúng path relative này, không có '/apiv2' — phải khớp
    // tuyệt đối với chuỗi backend dùng để tính lại HMAC (HmacSigningMiddleware).
    final method = options.method.toUpperCase();
    final path = options.path.startsWith('/') ? options.path : '/${options.path}';
    final body = options.data == null
        ? ''
        : (options.data is String ? options.data as String : jsonEncode(options.data));

    final dataToSign = '$method|$path|$timestamp|$nonce|$body';
    final signature = Hmac(sha256, utf8.encode(_hmacSecret))
        .convert(utf8.encode(dataToSign))
        .toString();

    options.headers['X-Timestamp']   = timestamp;
    options.headers['X-Nonce']       = nonce;
    options.headers['X-Signature']   = signature;
    options.headers['X-Client-Type'] = 'mobile';

    handler.next(options);
  }
}
