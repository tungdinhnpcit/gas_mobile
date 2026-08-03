// lib/features/auth/data/auth_repository.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/login_crypto.dart';
import '../../../core/services/background_polling_service.dart';
import 'auth_models.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();

  Future<LoginResponse> login(String username, String password) async {
    // Nếu build có LOGIN_AES_KEY (gateway /apiv2 mới) → mã hoá password trước khi
    // gửi. App cũ (không truyền define này) fallback gửi 'password' plaintext như
    // cũ, backend vẫn hiểu (xem AuthService.LoginAsync, ưu tiên encryptedPassword
    // nếu có).
    final encrypted = encryptLoginPassword(password);
    final response = await ApiClient.instance.dio.post(
      '/api/auth/login',
      data: {
        'username':   username,
        if (encrypted == null) 'password': password,
        if (encrypted != null) 'encryptedPassword': encrypted.cipherBase64,
        if (encrypted != null) 'iv': encrypted.ivBase64,
        'deviceInfo': 'mobile',
      },
    );
    debugPrint('[AUTH DEBUG] login raw response: ${response.data}');
    final result = LoginResponse.fromJson(response.data);
    debugPrint('[AUTH DEBUG] nhanVienId=${result.nhanVienId} userId=${result.userId}');
    await _saveSession(result);
    return result;  // FCM registration moved to post-login background task in app_router
  }

  Future<LoginResponse> refresh(String refreshToken) async {
    final response = await ApiClient.instance.dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final result = LoginResponse.fromJson(response.data);
    await _saveSession(result);
    return result;
  }

  Future<void> logout() async {
    // Huỷ background polling khi logout
    await BackgroundPollingService.cancelAll();

    final token = await _storage.read(key: 'refresh_token');
    if (token != null) {
      try {
        await ApiClient.instance.dio.post(
          '/api/auth/logout',
          data: {'refreshToken': token},
        );
      } catch (_) {}
    }
    await _clearSession();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getStoredRefreshToken() async {
    return _storage.read(key: 'refresh_token');
  }

  Future<List<MenuInfo>> getSavedMenus() async {
    final raw = await _storage.read(key: 'user_menus');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => MenuInfo.fromJson(e)).toList();
  }

  Future<List<RightInfo>> getSavedRights() async {
    final raw = await _storage.read(key: 'user_rights');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => RightInfo.fromJson(e)).toList();
  }

  Future<void> _saveSession(LoginResponse r) async {
    await _storage.write(key: 'jwt_token',     value: r.accessToken);
    await _storage.write(key: 'refresh_token', value: r.refreshToken);
    await _storage.write(key: 'user_menus',    value: jsonEncode(r.menus.map((m) => m.toJson()).toList()));
    await _storage.write(key: 'user_rights',   value: jsonEncode(r.rights.map((r) => r.toJson()).toList()));
    await _storage.write(key: 'role_code',     value: r.roleCode);
    await _storage.write(key: 'full_name',     value: r.fullName ?? r.username);
    await _storage.write(key: 'username',      value: r.username);
    await _storage.write(key: 'user_id',       value: r.userId.toString());
    await _storage.write(key: 'nhan_vien_id',  value: r.nhanVienId?.toString() ?? '');
    await _storage.write(key: 'avatar_url',    value: r.avatarUrl ?? '');
  }

  Future<void> _clearSession() async {
    await _storage.deleteAll();
  }

  /// Gọi API đổi mật khẩu. Trả true nếu thành công, false nếu mật khẩu hiện tại sai.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await ApiClient.instance.dio.post(
        '/api/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return false;
      rethrow;
    }
  }
}
