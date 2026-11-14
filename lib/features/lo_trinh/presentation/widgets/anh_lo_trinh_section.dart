// lib/features/lo_trinh/presentation/widgets/anh_lo_trinh_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/lo_trinh_model.dart';
import '../providers/lo_trinh_provider.dart';

/// Rút gọn thông báo lỗi từ server (DioException có body {message}).
String _loiAnh(Object e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
  } catch (_) {}
  return 'Lỗi tải ảnh lên, vui lòng thử lại';
}

/// Lấy vị trí hiện tại (nhanh: dùng vị trí cuối đã biết nếu có); null nếu không có quyền / lỗi.
Future<LatLng?> _layViTriNhanh() async {
  try {
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// Hỏi nguồn ảnh (camera / thư viện), chụp/chọn rồi upload vào lộ trình [loTrinhId].
/// [viTri] = vị trí lúc chụp; null thì tự lấy vị trí hiện tại. Trả về ảnh đã lưu, null nếu huỷ / lỗi.
Future<AnhLoTrinhModel?> chupVaLuuAnhLoTrinh(
  BuildContext context,
  WidgetRef ref,
  int loTrinhId, {
  LatLng? viTri,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('Chụp ảnh'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Chọn từ thư viện'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;

  final photo = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1920);
  if (photo == null || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Đang tải ảnh lên...'), duration: Duration(seconds: 30)));
  try {
    final vt = viTri ?? await _layViTriNhanh();
    final anh = await ref
        .read(loTrinhRepositoryProvider)
        .uploadAnh(loTrinhId, photo, lat: vt?.latitude, lng: vt?.longitude);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã lưu ảnh'), backgroundColor: Colors.green));
    return anh;
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_loiAnh(e)), backgroundColor: Colors.red));
    return null;
  }
}

/// Mở ảnh toàn màn hình, có thể phóng to/thu nhỏ.
void xemAnhLoTrinh(BuildContext context, AnhLoTrinhModel anh) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: CachedNetworkImage(
              imageUrl: anh.fullUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 24,
          child: Text(
            DateFormat('HH:mm dd/MM/yyyy').format(anh.chupLuc),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ),
      ]),
    ),
  );
}

/// Khu vực ảnh của lộ trình ở màn chi tiết: nút thêm ảnh, dải thumbnail cuộn ngang,
/// bấm để xem lớn, nhấn giữ để xoá.
class AnhLoTrinhSection extends ConsumerWidget {
  final LoTrinhModel loTrinh;
  const AnhLoTrinhSection({super.key, required this.loTrinh});

  /// Chụp/chọn ảnh mới rồi làm mới chi tiết lộ trình.
  Future<void> _themAnh(BuildContext context, WidgetRef ref) async {
    final anh = await chupVaLuuAnhLoTrinh(context, ref, loTrinh.id);
    if (anh != null) ref.invalidate(loTrinhDetailProvider(loTrinh.id));
  }

  /// Xác nhận rồi xoá ảnh, làm mới chi tiết lộ trình.
  Future<void> _xoaAnh(BuildContext context, WidgetRef ref, AnhLoTrinhModel anh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ảnh?'),
        content: const Text('Ảnh sẽ bị xoá khỏi lộ trình, không thể khôi phục.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loTrinhRepositoryProvider).deleteAnh(loTrinh.id, anh.id);
      ref.invalidate(loTrinhDetailProvider(loTrinh.id));
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá ảnh')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_loiAnh(e)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = loTrinh.anh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('Ảnh (${ds.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _themAnh(context, ref),
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Thêm ảnh'),
          ),
        ]),
        if (ds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Chưa có ảnh nào.', style: TextStyle(color: Colors.grey)),
          )
        else
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => xemAnhLoTrinh(context, ds[i]),
                onLongPress: () => _xoaAnh(context, ref, ds[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ds[i].fullUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
