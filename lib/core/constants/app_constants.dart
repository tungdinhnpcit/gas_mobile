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
  // mTLS bật ở nginx (BE/nginx/quanlygasapp.conf) — bắt buộc https + client certificate
  // nhúng trong assets/certs/client-mobile.p12 (xem core/network/mtls_client.dart)
  static const String prodApiUrl  = 'https://apimba.npc.com.vn:8202/apimanager';
  // Được set bởi DeviceConfig.resolveApiUrl() trong main() trước khi runApp
  static String resolvedApiUrl = prodApiUrl;
  static const String lichTuanApiUrl =
      'https://lichtuan.npc.com.vn/LT_WebAPI/api/PageBase/LichtuanNVJson';
  static const String lichTuanMaDviqly = 'NPCIT';
  static const String lichTuanXacThuc = 'Auth';
  static const int lichTuanNvid = 1303;
}
