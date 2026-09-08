// lib/features/cai_dat/presentation/screens/doi_mat_khau_screen.dart
import 'package:flutter/material.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/auth/data/biometric_service.dart';

/// Màn hình Đổi mật khẩu — form nhập mật khẩu hiện tại và mật khẩu mới.
class DoiMatKhauScreen extends StatefulWidget {
  const DoiMatKhauScreen({super.key});

  @override
  State<DoiMatKhauScreen> createState() => _DoiMatKhauScreenState();
}

class _DoiMatKhauScreenState extends State<DoiMatKhauScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _currentCtrl    = TextEditingController();
  final _newCtrl        = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool _loading         = false;
  bool _showCurrent     = false;
  bool _showNew         = false;
  bool _showConfirm     = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final ok = await AuthRepository().changePassword(
        _currentCtrl.text.trim(),
        _newCtrl.text.trim(),
      );
      if (ok) {
        // Server thu hồi mọi biometric token khi đổi mật khẩu → xoá luôn bản cục bộ
        // để trạng thái vân tay trong Cài đặt không hiển thị sai là "đang bật".
        await BiometricService().clearBiometric();
      }
      if (!mounted) return;
      if (ok) {
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mật khẩu hiện tại không đúng'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi kết nối, vui lòng thử lại'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PasswordField(
              controller:   _currentCtrl,
              label:        'Mật khẩu hiện tại',
              showPassword: _showCurrent,
              onToggle:     () => setState(() => _showCurrent = !_showCurrent),
              validator:    (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu hiện tại' : null,
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller:   _newCtrl,
              label:        'Mật khẩu mới',
              showPassword: _showNew,
              onToggle:     () => setState(() => _showNew = !_showNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nhập mật khẩu mới';
                if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller:   _confirmCtrl,
              label:        'Xác nhận mật khẩu mới',
              showPassword: _showConfirm,
              onToggle:     () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nhập lại mật khẩu mới';
                if (v != _newCtrl.text) return 'Mật khẩu không khớp';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width:  20,
                      child:  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool showPassword;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.showPassword,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:    controller,
      obscureText:   !showPassword,
      validator:     validator,
      decoration: InputDecoration(
        labelText:    label,
        border:       const OutlineInputBorder(),
        suffixIcon:   IconButton(
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
