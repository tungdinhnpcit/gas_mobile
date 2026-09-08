// lib/features/cai_dat/presentation/screens/cai_dat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/auth/data/biometric_service.dart';
import '../../../../features/menu/providers/menu_provider.dart';
import '../../../../core/providers/user_info_provider.dart';
import '../../../../features/thong_bao/presentation/providers/thong_bao_provider.dart';

/// Màn hình Cài đặt — danh sách các chức năng cài đặt tài khoản.
/// Nằm trong ShellRoute nên KHÔNG bọc Scaffold/AppBar (xem rules mobile_screen_navigation).
class CaiDatScreen extends ConsumerStatefulWidget {
  const CaiDatScreen({super.key});

  @override
  ConsumerState<CaiDatScreen> createState() => _CaiDatScreenState();
}

class _CaiDatScreenState extends ConsumerState<CaiDatScreen> {
  final _biometric = BiometricService();
  final _repo = AuthRepository();

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await _biometric.isAvailable();
    final enabled = available && await _biometric.isReady();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  /// Bật vân tay: xác thực vân tay trước rồi mới xin token — tránh người khác cầm
  /// máy đang mở khoá bật lén. Tắt: thu hồi token trên server rồi xoá cục bộ.
  Future<void> _toggleBiometric(bool value) async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);

    try {
      if (value) {
        final auth = await _biometric.authenticate(
          reason: 'Xác thực để bật đăng nhập bằng vân tay',
        );
        if (!auth.success) {
          // Huỷ chủ động thì không cần báo gì, switch tự trở về trạng thái cũ.
          if (!auth.cancelled) {
            _showMessage(auth.errorMessage ?? 'Xác thực vân tay thất bại');
          }
          return;
        }

        final deviceId = await _biometric.getOrCreateDeviceId();
        final token = await _repo.registerBiometric(deviceId, 'mobile');
        await _biometric.saveBiometricToken(token);
        await _biometric.enableBiometric();

        // Ghi lại tài khoản gắn với vân tay, để lần đăng nhập mật khẩu sau nhận ra
        // đúng chủ sở hữu và không thu hồi nhầm (xem LoginScreen._submit).
        final username = ref.read(userInfoProvider).valueOrNull?.username;
        if (username != null && username.isNotEmpty) {
          await _biometric.saveUsername(username);
        }

        if (mounted) setState(() => _biometricEnabled = true);
        _showMessage('Đã bật đăng nhập bằng vân tay');
      } else {
        final deviceId = await _biometric.getOrCreateDeviceId();
        await _repo.revokeBiometric(deviceId);
        await _biometric.clearBiometric();

        if (mounted) setState(() => _biometricEnabled = false);
        _showMessage('Đã tắt đăng nhập bằng vân tay');
      }
    } catch (e) {
      _showMessage('Không thực hiện được, vui lòng thử lại');
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.person_outline,
          title: 'Thông tin tài khoản',
          subtitle: 'Xem thông tin cá nhân',
          onTap: () => context.push(AppRoutes.thongTinTaiKhoan),
        ),
        const Divider(height: 1, indent: 56),
        if (_biometricAvailable) ...[
          SwitchListTile(
            secondary: Icon(
              Icons.fingerprint,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Đăng nhập bằng vân tay'),
            subtitle: Text(
              _biometricEnabled
                  ? 'Đang bật — đăng nhập nhanh không cần mật khẩu'
                  : 'Bật để đăng nhập nhanh bằng vân tay',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _biometricEnabled,
            onChanged: _biometricBusy ? null : _toggleBiometric,
          ),
          const Divider(height: 1, indent: 56),
        ],
        _SettingTile(
          icon: Icons.lock_outline,
          title: 'Đổi mật khẩu',
          subtitle: 'Thay đổi mật khẩu đăng nhập',
          onTap: () async {
            await context.push(AppRoutes.doiMatKhau);
            // Đổi mật khẩu làm server thu hồi biometric token → đồng bộ lại switch.
            if (mounted) _loadBiometricState();
          },
        ),
        const Divider(height: 1, indent: 56),
        _SettingTile(
          icon: Icons.sync_rounded,
          title: 'Đồng bộ dữ liệu',
          subtitle: 'Tải danh mục xe, hàng, khách hàng về máy',
          onTap: () => context.push(AppRoutes.dongBo),
        ),
        const Divider(height: 1, indent: 56),
        _SettingTile(
          icon: Icons.logout,
          title: 'Đăng xuất',
          subtitle: 'Thoát khỏi tài khoản',
          iconColor: Theme.of(context).colorScheme.error,
          titleColor: Theme.of(context).colorScheme.error,
          onTap: () => _logout(context, ref),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthRepository().logout();
    ref.invalidate(menuProvider);
    ref.invalidate(userInfoProvider);
    ref.invalidate(soChuaDocProvider);
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? defaultColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
