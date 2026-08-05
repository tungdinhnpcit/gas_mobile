// lib/core/constants/app_constants.dart
import 'local_dev_config.dart';

class AppConstants {
  static const String notificationChannelId = 'quan_ly_gas_channel';
  static const String notificationChannelName = 'QuanLyGas Thông Báo';
  static const String notificationChannelDesc =
      'Thông báo chuyến xe và cập nhật từ hệ thống';
  // localApiUrl: IP máy dev (cho real device Android / iOS), lấy từ local_dev_config.dart
  // (file cá nhân, không commit — xem local_dev_config.dart.example)
  // Emulator Android sẽ tự động dùng 10.0.2.2:5001 (xem device_config.dart)
  static final String localApiUrl = LocalDevConfig.devApiUrl;
  // Ban release that dang chay cho user - KHONG mTLS, giu nguyen hanh vi on dinh.
  static const String prodApiUrl = 'http://apimba.npc.com.vn:8202/apimanager';
  // Gateway rieng /apiv2/ tren cung port 8202 co enforce mTLS (xem
  // BE/nginx/quanlygasapp.conf) - dung de test ban app moi, KHONG anh huong
  // prodApiUrl mac dinh. Truyen luc build: --dart-define=TEST_PROD_API_URL=...
  static const String _testProdOverride = String.fromEnvironment(
    'TEST_PROD_API_URL',
    defaultValue: '',
  );
  static String get effectiveProdApiUrl =>
      _testProdOverride.isEmpty ? prodApiUrl : _testProdOverride;
  // Được set bởi DeviceConfig.resolveApiUrl() trong main() trước khi runApp
  static String resolvedApiUrl = prodApiUrl;
  static const String lichTuanApiUrl =
      'https://lichtuan.npc.com.vn/LT_WebAPI/api/PageBase/LichtuanNVJson';
  static const String lichTuanMaDviqly = 'NPCIT';
  static const String lichTuanXacThuc = 'Auth';
  static const int lichTuanNvid = 1303;
}
