// lib/features/auth/data/biometric_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/storage_keys.dart';

/// Kết quả xác thực vân tay — tách riêng lý do thất bại để màn hình hiển thị đúng
/// nguyên nhân, thay vì chỉ biết "thất bại".
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  /// Người dùng chủ động đóng hộp thoại — không phải lỗi, không nên hiện báo đỏ.
  final bool cancelled;

  const BiometricAuthResult.ok()
    : success = true,
      errorMessage = null,
      cancelled = false;
  const BiometricAuthResult.fail(this.errorMessage)
    : success = false,
      cancelled = false;
  const BiometricAuthResult.cancel()
    : success = false,
      errorMessage = null,
      cancelled = true;
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  /// Thiết bị có hỗ trợ và đã đăng ký sinh trắc học hay chưa.
  /// Cần cả `isDeviceSupported` (máy có khoá màn hình/phần cứng phù hợp) lẫn
  /// `canCheckBiometrics` — chỉ kiểm một trong hai sẽ báo nhầm trên máy chưa đặt khoá.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Hiện hộp thoại quét vân tay. Trả về lý do cụ thể khi thất bại.
  Future<BiometricAuthResult> authenticate({String? reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason ?? 'Xác thực vân tay để đăng nhập Gas Manager',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      // ok == false ở đây nghĩa là người dùng đóng hộp thoại, không phải sự cố.
      return ok
          ? const BiometricAuthResult.ok()
          : const BiometricAuthResult.cancel();
    } on PlatformException catch (e) {
      // Luôn log mã lỗi gốc: chính vì thiếu dòng này mà no_fragment_activity từng bị
      // che thành thông báo chung chung, mất rất nhiều thời gian dò nguyên nhân.
      debugPrint('[BIOMETRIC] code=${e.code} message=${e.message}');

      final msg = switch (e.code) {
        auth_error.notEnrolled =>
          'Thiết bị chưa đăng ký vân tay. Vui lòng thêm vân tay trong Cài đặt của máy.',
        auth_error.lockedOut =>
          'Đã thử sai quá nhiều lần. Vui lòng đợi một lát rồi thử lại.',
        auth_error.permanentlyLockedOut =>
          'Vân tay đã bị khoá. Vui lòng mở khoá máy bằng mật khẩu trước.',
        auth_error.notAvailable => 'Thiết bị không hỗ trợ xác thực vân tay.',
        // Lỗi cấu hình: MainActivity phải kế thừa FlutterFragmentActivity.
        'no_fragment_activity' =>
          'Ứng dụng chưa được cấu hình đúng cho xác thực vân tay (no_fragment_activity).',
        _ => 'Xác thực vân tay thất bại (${e.code})',
      };
      return BiometricAuthResult.fail(msg);
    } catch (e) {
      debugPrint('[BIOMETRIC] lỗi không xác định: $e');
      return const BiometricAuthResult.fail('Xác thực vân tay thất bại');
    }
  }

  // ---------------- Trạng thái bật/tắt ----------------

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: StorageKeys.biometricEnabled);
    return val == 'true';
  }

  Future<void> enableBiometric() async {
    await _storage.write(key: StorageKeys.biometricEnabled, value: 'true');
  }

  /// Xoá toàn bộ cấu hình vân tay (giữ lại device_id để lần đăng ký sau vẫn trỏ
  /// về đúng thiết bị này trên server).
  Future<void> clearBiometric() async {
    for (final key in StorageKeys.biometricKeys) {
      await _storage.delete(key: key);
    }
  }

  // ---------------- Biometric token ----------------

  Future<void> saveBiometricToken(String token) async {
    await _storage.write(key: StorageKeys.biometricToken, value: token);
  }

  Future<String?> getBiometricToken() async {
    return _storage.read(key: StorageKeys.biometricToken);
  }

  /// Đã sẵn sàng đăng nhập bằng vân tay chưa: vừa bật cờ, vừa còn token.
  Future<bool> isReady() async {
    if (!await isBiometricEnabled()) return false;
    final token = await getBiometricToken();
    return token != null && token.isNotEmpty;
  }

  // ---------------- Định danh thiết bị ----------------

  /// Định danh ổn định của máy, do app tự sinh và lưu bền. Không bị xoá khi đăng
  /// xuất nên server luôn nhận ra cùng một thiết bị.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: StorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = const Uuid().v4();
    await _storage.write(key: StorageKeys.deviceId, value: id);
    return id;
  }

  // ---------------- Tên đăng nhập đã lưu ----------------

  Future<String?> getSavedUsername() async {
    return _storage.read(key: StorageKeys.savedUsername);
  }

  Future<void> saveUsername(String username) async {
    await _storage.write(key: StorageKeys.savedUsername, value: username);
  }
}
