// lib/core/constants/app_constants.dart
import 'local_dev_config.dart';

class AppConstants {
  static const String notificationChannelId = 'quan_ly_gas_channel';
  static const String notificationChannelName = 'QuanLyGas Thông Báo';
  static const String notificationChannelDesc =
      'Thông báo chuyến xe và cập nhật từ hệ thống';
  // localApiUrl: IP máy dev (cho real device Android / iOS), lấy từ local_dev_config.dart
  // (file cá nhân, không commit — xem local_dev_config.dart.example)
  // Emulator Android sẽ tự động dùng 10.0.2.2:5001 (xem device_config.dart),
  // trừ khi LocalDevConfig.target = internet thì dùng thẳng prodApiUrl.
  static final String localApiUrl = LocalDevConfig.devApiUrl;
  // Bản release: HTTPS qua F5 → nginx_apimba_test (máy 147) → manager-api:5000 (từ 05/11/2026).
  // Trước đây: http://apimba.npc.com.vn:8202/apimanager (app cũ v1.0.3 vẫn gọi đường này).
  static const String prodApiUrl = 'https://apimba-test.npc.com.vn/apimanager';
  // Gateway /apiv2/ cùng tên miền, bắt buộc chữ ký HMAC — dùng để thử bản app mới,
  // KHÔNG ảnh hưởng prodApiUrl mặc định. Truyền lúc build:
  // --dart-define=TEST_PROD_API_URL=https://apimba-test.npc.com.vn/apiv2
  static const String _testProdOverride = String.fromEnvironment(
    'TEST_PROD_API_URL',
    defaultValue: '',
  );
  static String get effectiveProdApiUrl =>
      _testProdOverride.isEmpty ? prodApiUrl : _testProdOverride;
  // Được set bởi DeviceConfig.resolveApiUrl() trong main() trước khi runApp
  static String resolvedApiUrl = prodApiUrl;
  // Gốc cho ảnh/file tĩnh: bỏ tiền tố API (/apimanager hoặc /apiv2), ghép thêm '/uploads/...'
  static String get staticBaseUrl =>
      resolvedApiUrl.replaceFirst(RegExp(r'/(apimanager|apiv2)$'), '');
  static const String lichTuanApiUrl =
      'https://lichtuan.npc.com.vn/LT_WebAPI/api/PageBase/LichtuanNVJson';
  static const String lichTuanMaDviqly = 'NPCIT';
  static const String lichTuanXacThuc = 'Auth';
  static const int lichTuanNvid = 1303;
}
