// lib/core/config/device_config.dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../constants/local_dev_config.dart';

class DeviceConfig {
  /// Trả về base API URL phù hợp với thiết bị đang chạy.
  /// Release mode → luôn production.
  /// Debug mode:
  ///   - Nếu Android emulator → dùng 10.0.2.2 (localhost của host)
  ///   - Nếu real device hoặc iOS → dùng localUrl (IP máy dev)
  static Future<String> resolveApiUrl({
    required String localUrl,
    required String prodUrl,
  }) async {
    if (kReleaseMode) return prodUrl;

    // Debug nhưng muốn test với API internet (bật cờ trong local_dev_config.dart)
    if (LocalDevConfig.useInternetInDebug) return prodUrl;

    // Debug mode
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final fingerprint = androidInfo.fingerprint.toLowerCase();

        // Phát hiện emulator: chứa "generic", "unknown", "sdk", "vbox", "qemu"
        final isEmulator = fingerprint.contains('generic') ||
            fingerprint.contains('unknown') ||
            fingerprint.contains('sdk') ||
            fingerprint.contains('vbox') ||
            fingerprint.contains('qemu');

        if (isEmulator) {
          // Emulator: dùng 10.0.2.2 để gọi localhost của host, qua nginx gateway
          // (đúng mô hình production: app → nginx :8202/apimanager → backend)
          return 'http://10.0.2.2:8202/apimanager';
        }
      } catch (e) {
        debugPrint('[DeviceConfig] Error detecting emulator: $e');
      }
    }

    // Real device hoặc iOS: dùng IP máy dev
    return localUrl;
  }
}
