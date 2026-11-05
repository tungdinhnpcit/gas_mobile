// lib/features/cai_dat/presentation/screens/thong_tin_tai_khoan_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/user_info_provider.dart';

/// Màn hình Thông tin tài khoản — hiển thị thông tin user và cho phép thay đổi ảnh đại diện.
class ThongTinTaiKhoanScreen extends ConsumerStatefulWidget {
  const ThongTinTaiKhoanScreen({super.key});

  @override
  ConsumerState<ThongTinTaiKhoanScreen> createState() => _ThongTinTaiKhoanScreenState();
}

class _ThongTinTaiKhoanScreenState extends ConsumerState<ThongTinTaiKhoanScreen> {
  bool _uploading = false;

  static String get _staticBaseUrl =>
      AppConstants.staticBaseUrl;

  // nhanVienId > 0 → upload vào nhân viên (đồng bộ web); ngược lại (admin/không có NV) → avatar cấp user
  Future<void> _pickAndUpload(int nhanVienId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      // Đọc bytes gốc rồi nén in-memory (không cần path_provider)
      final rawBytes = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        quality: 80,
        minWidth: 512,
        minHeight: 512,
      );

      // Xác định extension từ path gốc
      final srcPath = picked.path;
      final ext     = srcPath.contains('.') ? srcPath.substring(srcPath.lastIndexOf('.')) : '.jpg';

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          compressed,
          filename: 'avatar$ext',
        ),
      });

      final endpoint = nhanVienId > 0
          ? '/api/nhan-vien/$nhanVienId/avatar'
          : '/api/auth/avatar';
      final resp = await ApiClient.instance.dio.post(endpoint, data: form);

      final avatarUrl = resp.data['avatarUrl'] as String?;
      if (avatarUrl != null) {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'avatar_url', value: avatarUrl);
        ref.invalidate(userInfoProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload ảnh: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userInfoProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (user) {
        final fullUrl = user.avatarUrl != null
            ? '$_staticBaseUrl${user.avatarUrl}'
            : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Avatar ──
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _AvatarWidget(fullUrl: fullUrl, initials: user.fullName, radius: 56),
                  if (_uploading)
                    Container(
                      width: 112, height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Nút upload (mọi tài khoản; admin lưu avatar cấp user) ──
            Center(
              child: TextButton.icon(
                onPressed: _uploading ? null : () => _pickAndUpload(user.nhanVienId),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Thay đổi ảnh đại diện'),
              ),
            ),

            const SizedBox(height: 20),

            // ── Thông tin ──
            _InfoCard(children: [
              _InfoRow(label: 'Họ và tên',     value: user.fullName),
              _InfoRow(label: 'Tên đăng nhập', value: user.username),
              _InfoRow(label: 'Vai trò',        value: _roleLabel(user.roleCode)),
            ]),
          ],
        );
      },
    );
  }

  String _roleLabel(String roleCode) {
    return switch (roleCode) {
      'Admin'   => 'Quản trị hệ thống',
      'GiamDoc' => 'Giám đốc',
      'KeToan'  => 'Kế toán',
      'LaiXe'   => 'Lái xe',
      'QuanLy'  => 'Quản lý',
      _         => roleCode,
    };
  }
}

/// Widget hiển thị avatar từ URL (nếu có) hoặc ký tự đầu tên.
class _AvatarWidget extends StatelessWidget {
  final String? fullUrl;
  final String initials;
  final double radius;

  const _AvatarWidget({required this.fullUrl, required this.initials, required this.radius});

  @override
  Widget build(BuildContext context) {
    final letter = initials.isNotEmpty ? initials[0].toUpperCase() : '?';
    if (fullUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: fullUrl!,
            width: radius * 2, height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (_, __, ___) => Text(letter,
                style: TextStyle(fontSize: radius * 0.6,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(letter,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: radius * 0.6,
              )),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : '—',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
