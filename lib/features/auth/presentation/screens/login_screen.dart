// lib/features/auth/presentation/screens/login_screen.dart
//
// Giao diện đồng bộ với trang login web (frontend/app/(auth)/login):
// ảnh nền bg-login.jpg + overlay tối, glass panel kính mờ, logo 🔥 GAS MANAGER,
// input nền trong suốt viền sáng, nút gradient cyan→blue.
// Giữ nguyên logic đăng nhập thật (username/password + vân tay).

import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/providers/user_info_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/menu/providers/menu_provider.dart';
import '../../../../features/thong_bao/presentation/providers/thong_bao_provider.dart';
import '../../data/auth_repository.dart';
import '../../data/biometric_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Bảng màu đồng bộ với web login (glass panel tông tối)
  static const _bg = Color(0xFF0B1120); // nền tối
  static const _cyan = Color(0xFF06B6D4); // accent + gradient nút
  static const _blue = Color(0xFF3B82F6); // gradient nút
  static const _cyanBright = Color(0xFF22D3EE); // chữ "MANAGER"
  static const _textMuted = Color(0xFF94A3B8); // label/icon phụ
  static const _textSub = Color(0xFFCBD5E1); // phụ đề

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _biometricAvailable = false;
  bool _biometricReady = false;
  String? _error;
  String _versionText = '';

  final _repo = AuthRepository();
  final _biometric = BiometricService();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _usernameCtrl.text = 'admin';
      _passwordCtrl.text = 'diepSam@2026##';
    }
    _checkBiometric();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versionText = 'v${info.version}+${info.buildNumber}');
  }

  Future<void> _checkBiometric() async {
    final available = await _biometric.isAvailable();
    if (!available) return;

    // Sẵn sàng khi đã bật vân tay VÀ còn biometric token. Cố ý không xét jwt_token:
    // token phiên bị xoá lúc đăng xuất, trong khi vân tay phải dùng được sau đăng xuất.
    final ready = await _biometric.isReady();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = true;
      _biometricReady = ready;
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repo.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;

      final available = await _biometric.isAvailable();
      final enabled = await _biometric.isReady();
      final savedUsername = await _biometric.getSavedUsername();

      // Chỉ xử lý khi biết chắc tài khoản cũ là ai; savedUsername rỗng thì coi như
      // cùng tài khoản để không thu hồi nhầm vân tay đang dùng tốt.
      final khacTaiKhoan =
          savedUsername != null &&
          savedUsername.isNotEmpty &&
          savedUsername != response.username;

      if (available && enabled && khacTaiKhoan) {
        // Tài khoản khác vừa đăng nhập trên cùng máy: token vân tay đang trỏ về
        // tài khoản cũ. Thu hồi rồi hỏi lại, tránh quét vân tay ra nhầm tài khoản.
        await _disableBiometricForOtherUser();
        await _showEnableBiometricSheet(response.username);
      } else if (available && !enabled) {
        await _showEnableBiometricSheet(response.username);
      } else {
        await _biometric.saveUsername(response.username);
      }

      if (mounted) {
        ref.invalidate(menuProvider);
        ref.invalidate(userInfoProvider);
        ref.invalidate(soChuaDocProvider);
        context.go(AppRoutes.home);
      }
    } catch (e) {
      String msg;
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          msg = 'Không kết nối được đến máy chủ (${e.requestOptions.baseUrl})';
        } else if (e.response?.statusCode == 401 ||
            e.response?.statusCode == 400) {
          msg = 'Sai tên đăng nhập hoặc mật khẩu';
        } else {
          msg = 'Lỗi: ${e.message ?? e.type.name}';
        }
      } else {
        msg = 'Lỗi: $e';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = await _biometric.authenticate();
      if (!auth.success) {
        // Người dùng tự đóng hộp thoại thì im lặng, không hiện báo đỏ.
        setState(() {
          _error = auth.cancelled ? null : auth.errorMessage;
          _loading = false;
        });
        return;
      }

      final token = await _biometric.getBiometricToken();
      if (token == null || token.isEmpty) {
        await _biometric.clearBiometric();
        setState(() {
          _biometricReady = false;
          _error = 'Chưa thiết lập vân tay, vui lòng đăng nhập bằng mật khẩu';
          _loading = false;
        });
        return;
      }

      final deviceId = await _biometric.getOrCreateDeviceId();
      await _repo.loginWithBiometric(token, deviceId, 'mobile');

      if (mounted) {
        ref.invalidate(menuProvider);
        ref.invalidate(userInfoProvider);
        ref.invalidate(soChuaDocProvider);
        context.go(AppRoutes.home);
      }
    } on DioException catch (e) {
      // Chỉ 401 mới là token thực sự mất hiệu lực (bị thu hồi do đổi mật khẩu, hết
      // hạn, hoặc tắt từ thiết bị khác) → mới xoá cấu hình vân tay.
      // Lỗi mạng thì GIỮ NGUYÊN, nếu không người dùng mất sóng một lần là phải
      // thiết lập lại vân tay từ đầu.
      if (e.response?.statusCode == 401) {
        await _biometric.clearBiometric();
        if (mounted) {
          setState(() {
            _biometricReady = false;
            _error =
                'Đăng nhập vân tay đã hết hiệu lực, vui lòng nhập mật khẩu';
          });
        }
      } else {
        final msg =
            (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError)
            ? 'Không kết nối được đến máy chủ (${e.requestOptions.baseUrl})'
            : 'Lỗi: ${e.message ?? e.type.name}';
        if (mounted) setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Thu hồi vân tay của tài khoản trước đó trên máy này. Chạy khi một tài khoản
  /// khác đăng nhập; JWT hiện tại là của tài khoản mới nên server chỉ thu hồi được
  /// token thuộc tài khoản mới — vì vậy vẫn xoá bản cục bộ để token cũ không dùng lại.
  Future<void> _disableBiometricForOtherUser() async {
    try {
      final deviceId = await _biometric.getOrCreateDeviceId();
      await _repo.revokeBiometric(deviceId);
    } catch (_) {
      // Mất mạng cũng phải xoá cục bộ — ưu tiên không để đăng nhập nhầm tài khoản.
    }
    await _biometric.clearBiometric();
  }

  Future<void> _showEnableBiometricSheet(String username) async {
    if (!mounted) return;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint, size: 56, color: _cyan),
            const SizedBox(height: 12),
            const Text(
              'Bật đăng nhập bằng vân tay?',
              style: TextStyle(
                color: Color(0xFF1D2226),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lần sau bạn có thể đăng nhập nhanh mà không cần nhập mật khẩu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8E8E93),
                      side: const BorderSide(color: Color(0xFFE5E5EA)),
                    ),
                    child: const Text('Để sau'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: _blue),
                    child: const Text('Bật'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (enable != true) return;

    // Đăng ký ngay lúc này vì JWT vừa nhận còn hiệu lực. Token nhận được sẽ dùng
    // cho các lần đăng nhập vân tay sau, kể cả sau khi đăng xuất.
    try {
      final deviceId = await _biometric.getOrCreateDeviceId();
      final token = await _repo.registerBiometric(deviceId, 'mobile');
      await _biometric.saveBiometricToken(token);
      await _biometric.enableBiometric();
      await _biometric.saveUsername(username);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không bật được đăng nhập vân tay. Bạn có thể bật lại trong Cài đặt.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Lớp ảnh nền — phủ kín màn hình
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg-login.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Lớp overlay gradient tối (đậm bên phải, nhạt bên trái) — giống web
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    _bg.withValues(alpha: 0.95),
                    _bg.withValues(alpha: 0.40),
                    _bg.withValues(alpha: 0.10),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Nội dung — glass panel căn giữa
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _buildGlassPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Panel kính mờ chứa logo + form đăng nhập
  Widget _buildGlassPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF101928).withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 50,
                offset: Offset(0, 25),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ─────────────────────────────────────────────────
                Column(
                  children: [
                    // FittedBox + mainAxisSize.min: logo tự thu nhỏ khi màn hình hẹp
                    // thay vì tràn. BoxFit.scaleDown chỉ thu nhỏ, không phóng to nên
                    // máy rộng vẫn giữ đúng cỡ chữ thiết kế.
                    // Lưu ý: FittedBox đo con với bề rộng vô hạn nên Row BẮT BUỘC phải
                    // là MainAxisSize.min, để max sẽ ném assertion.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'GAS ',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: 'MANAGER',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w300,
                                    color: _cyanBright,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hệ thống Quản lý Khí đốt Thông minh',
                      style: TextStyle(fontSize: 13, color: _textSub),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Khối lỗi ─────────────────────────────────────────────
                if (_error != null) ...[
                  _ErrorBox(message: _error!),
                  const SizedBox(height: 20),
                ],

                // ── Tên đăng nhập ────────────────────────────────────────
                const _FieldLabel('TÊN ĐĂNG NHẬP'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _usernameCtrl,
                  hint: 'Nhập tên tài khoản...',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Mật khẩu ─────────────────────────────────────────────
                const _FieldLabel('MẬT KHẨU'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _passwordCtrl,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng nhập mật khẩu'
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: _obscure ? _textMuted : _cyan,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),

                // ── Đăng nhập vân tay ────────────────────────────────────
                // Chỉ hiện khi đã thiết lập xong: máy hỗ trợ vân tay VÀ đã bật kèm
                // token. Nhờ vậy không còn cảnh bấm vào rồi nhận thông báo phải
                // đăng nhập mật khẩu trước.
                if (_biometricAvailable && _biometricReady) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _loading ? null : _loginWithBiometric,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint, size: 20, color: _cyan),
                          SizedBox(width: 6),
                          // Flexible: tránh tràn khi người dùng bật cỡ chữ hệ thống lớn.
                          Flexible(
                            child: Text(
                              'Đăng nhập bằng vân tay',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: _cyan,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Nút ĐĂNG NHẬP ────────────────────────────────────────
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_cyan, _blue],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _cyan.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'ĐANG XÁC THỰC...',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'ĐĂNG NHẬP VÀO HỆ THỐNG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Footer ───────────────────────────────────────────────
                const Text(
                  '© 2026 Gas Manager Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  _versionText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Nhãn field dạng chữ hoa nhỏ (tông tối)
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }
}

// Ô nhập liệu glass (nền trong suốt, viền sáng mờ, focus viền cyan)
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF06B6D4);
    const muted = Color(0xFF94A3B8);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      cursorColor: cyan,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: muted),
        prefixIcon: Icon(prefixIcon, size: 18, color: muted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
      ),
    );
  }
}

// Khối hiển thị lỗi (nền đỏ mờ, tông tối)
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⚠', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
