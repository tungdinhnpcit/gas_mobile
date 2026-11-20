// lib/core/services/session_replaced_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/storage_keys.dart';
import '../../features/vi_tri/services/chia_se_vi_tri_service.dart' show ChiaSeViTriService, viTriTaskKey;

/// Xử lý khi tài khoản đăng nhập trên điện thoại khác → máy này bị đăng xuất.
/// Nguồn kích hoạt: FCM "SESSION_REPLACED" hoặc API trả 401 kèm header X-Session-Replaced.
/// Màn đăng nhập đọc cờ [_prefKey] để hiện thông báo cho người dùng.
class SessionReplacedHandler {
  SessionReplacedHandler._();

  static const _prefKey = 'session_replaced';
  static const code = 'SESSION_REPLACED';
  static const thongBao = 'Tài khoản của bạn vừa đăng nhập trên thiết bị khác. Bạn đã bị đăng xuất.';

  static bool _dangXuLy = false;
  static void Function(String route)? _navigateToLogin;

  /// Router đăng ký callback chuyển về màn đăng nhập.
  static void setNavigateToLogin(void Function(String route) cb) => _navigateToLogin = cb;

  /// Kiểm tra response lỗi có phải do phiên mobile bị thay thế không.
  static bool laBiThayThe(int? statusCode, Map<String, List<String>>? headers, dynamic data) {
    if (statusCode != 401) return false;
    final h = headers?['x-session-replaced']?.firstOrNull;
    if (h == '1') return true;
    return data is Map && data['code'] == code;
  }

  /// Xử lý ở isolate chính (app đang mở): dừng chia sẻ vị trí, xoá phiên, về màn đăng nhập.
  static Future<void> xuLy() async {
    if (_dangXuLy) return;
    _dangXuLy = true;
    try {
      debugPrint('[SESSION] Bị đăng xuất do đăng nhập trên thiết bị khác');
      try {
        await ChiaSeViTriService.instance.dung(baoServer: false);
      } catch (_) {}
      await _xoaPhien();
      _navigateToLogin?.call('/login');
    } finally {
      _dangXuLy = false;
    }
  }

  /// Xử lý ở isolate nền (FCM background / Workmanager): không có UI, chỉ xoá phiên + tắt task nền.
  /// Lần mở app sau sẽ vào màn đăng nhập và hiện thông báo.
  static Future<void> xuLyNen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chia_se_vi_tri', false); // cùng key cờ của ChiaSeViTriService
      await Workmanager().cancelByUniqueName(viTriTaskKey);
    } catch (_) {}
    await _xoaPhien();
  }

  /// Xoá key phiên (giữ cấu hình vân tay) và bật cờ để màn đăng nhập hiện thông báo.
  static Future<void> _xoaPhien() async {
    const storage = FlutterSecureStorage();
    for (final key in StorageKeys.sessionKeys) {
      await storage.delete(key: key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Màn đăng nhập gọi: true nếu vừa bị đăng xuất do máy khác (đọc xong xoá cờ).
  static Future<bool> layVaXoaCo() async {
    final prefs = await SharedPreferences.getInstance();
    final co = prefs.getBool(_prefKey) ?? false;
    if (co) await prefs.remove(_prefKey);
    return co;
  }
}
