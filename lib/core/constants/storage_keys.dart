// lib/core/constants/storage_keys.dart
//
// Phân biệt rõ hai nhóm key trong flutter_secure_storage:
//
//  - sessionKeys   : thuộc về PHIÊN đăng nhập → xoá khi đăng xuất / refresh thất bại.
//  - biometricKeys : thuộc về THIẾT BỊ → phải sống sót qua đăng xuất, nếu không
//                    người dùng đăng xuất xong sẽ không đăng nhập vân tay lại được.
//
// Trước đây cả hai nhóm bị xoá chung bằng `_storage.deleteAll()`, chính là nguyên
// nhân lỗi "Vui lòng đăng nhập bằng mật khẩu trước để kích hoạt vân tay".
class StorageKeys {
  StorageKeys._();

  /// Đúng các key được ghi trong AuthRepository._saveSession.
  static const List<String> sessionKeys = [
    'jwt_token',
    'refresh_token',
    'user_menus',
    'user_rights',
    'role_code',
    'full_name',
    'username',
    'user_id',
    'nhan_vien_id',
    'avatar_url',
  ];

  static const String biometricEnabled = 'biometric_enabled';
  static const String savedUsername    = 'saved_username';
  static const String biometricToken   = 'biometric_token';
  static const String deviceId         = 'device_id';

  /// Xoá khi người dùng tắt vân tay hoặc token bị server thu hồi.
  /// KHÔNG bao gồm deviceId — định danh thiết bị nên giữ nguyên để lần đăng ký
  /// sau vẫn trỏ về đúng thiết bị cũ trên server.
  static const List<String> biometricKeys = [
    biometricEnabled,
    savedUsername,
    biometricToken,
  ];
}
