// lib/core/network/login_crypto.dart
// Mã hoá AES-256-CBC cho trường password lúc login — giảm rủi ro lộ mật khẩu dạng
// cleartext khi server không dùng HTTPS. Backend giải mã bằng LoginCryptoService
// (OrderService.Infrastructure/Security/LoginCryptoService.cs), cùng cách derive key
// (SHA-256 của passphrase) để tương thích 2 chiều.
//
// Secret nhúng qua compile-time define, KHÔNG hardcode (giống pattern MTLS_P12_PASSWORD,
// HMAC_MOBILE_SECRET): flutter build apk --dart-define=LOGIN_AES_KEY=xxx
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:encrypt/encrypt.dart' as enc;

const _loginAesPassphrase = String.fromEnvironment('LOGIN_AES_KEY', defaultValue: '');

class EncryptedLoginPassword {
  final String cipherBase64;
  final String ivBase64;
  const EncryptedLoginPassword(this.cipherBase64, this.ivBase64);
}

/// Trả về null nếu chưa cấu hình LOGIN_AES_KEY — caller fallback gửi password
/// plaintext qua field cũ (tương thích app cũ gọi /apimanager, không đổi hành vi).
EncryptedLoginPassword? encryptLoginPassword(String plainPassword) {
  if (_loginAesPassphrase.isEmpty) return null;

  final keyBytes = Uint8List.fromList(sha256.convert(utf8.encode(_loginAesPassphrase)).bytes);
  final key = enc.Key(keyBytes);
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

  final encrypted = encrypter.encrypt(plainPassword, iv: iv);
  return EncryptedLoginPassword(encrypted.base64, iv.base64);
}
