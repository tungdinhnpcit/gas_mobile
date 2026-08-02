// lib/core/network/mtls_client.dart
// Nạp client certificate (mTLS) cho HttpClient dùng bởi Dio — cộng thêm lớp bảo mật
// tầng network ngoài JWT Bearer hiện có: dù JWT bị đánh cắp, request vẫn bị nginx
// backend từ chối (495) nếu không có certificate hợp lệ do CA nội bộ ký.
//
// Cert được đóng gói làm asset (assets/certs/client-mobile.p12 + ca.crt) — xem
// certs/README.md để biết cách sinh/rotate. Mật khẩu .p12 đọc qua compile-time
// define MTLS_P12_PASSWORD (truyền lúc build: flutter build apk
// --dart-define=MTLS_P12_PASSWORD=xxx), KHÔNG hardcode trong source.
//
// Lưu ý bảo mật: cert nhúng trong APK có thể bị trích xuất nếu app bị decompile —
// đây là rủi ro đã biết và chấp nhận vì mTLS chỉ là lớp phòng vệ phụ (giảm thiểu
// bằng build release với --obfuscate --split-debug-info).
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

const _p12AssetPath = 'assets/certs/client-mobile.p12';
const _caAssetPath = 'assets/certs/ca.crt';
const _p12Password = String.fromEnvironment('MTLS_P12_PASSWORD', defaultValue: 'changeit');

SecurityContext? _cachedContext;

// `IOHttpClientAdapter.createHttpClient` là callback đồng bộ (không thể async), nên
// certificate phải được nạp trước (preload) lúc app khởi động qua [preloadMtlsContext]
// gọi trong main() trước runApp. Getter đồng bộ này chỉ đọc cache đã sẵn sàng.
SecurityContext? get cachedMtlsSecurityContext => _cachedContext;

// Gọi 1 lần trong main() trước runApp() để nạp client certificate + CA nội bộ vào cache,
// đảm bảo có sẵn đồng bộ khi ApiClient tạo HttpClient qua createHttpClient.
Future<void> preloadMtlsContext() async {
  if (_cachedContext != null) return;
  try {
    final context = SecurityContext(withTrustedRoots: true);

    final p12Bytes = (await rootBundle.load(_p12AssetPath)).buffer.asUint8List();
    context.useCertificateChainBytes(p12Bytes, password: _p12Password);
    context.usePrivateKeyBytes(p12Bytes, password: _p12Password);

    final caBytes = (await rootBundle.load(_caAssetPath)).buffer.asUint8List();
    context.setTrustedCertificatesBytes(caBytes);

    _cachedContext = context;
  } catch (e) {
    // ignore: avoid_print
    print('[mTLS] Không nạp được client certificate lúc khởi động: $e');
  }
}
