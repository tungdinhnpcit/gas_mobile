// lib/features/lo_trinh/presentation/screens/lo_trinh_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lo_trinh_model.dart';
import '../providers/lo_trinh_provider.dart';
import '../widgets/doi_ten_lo_trinh_dialog.dart';

/// Xem lại lộ trình trên bản đồ (root navigator): polyline, điểm đầu/cuối,
/// nút chỉ đường đến điểm kết thúc qua Google Maps.
class LoTrinhDetailScreen extends ConsumerWidget {
  final int loTrinhId;
  const LoTrinhDetailScreen({super.key, required this.loTrinhId});

  /// Mở Google Maps chỉ đường từ vị trí hiện tại đến điểm cuối lộ trình.
  Future<void> _chiDuong(BuildContext context, LoTrinhDiemModel dich) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${dich.lat},${dich.lng}&travelmode=driving');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được ứng dụng bản đồ')));
    }
  }

  /// Mở hộp thoại đổi tên, gọi API rồi làm mới chi tiết + danh sách.
  Future<void> _doiTen(BuildContext context, WidgetRef ref, String? tenHienTai) async {
    final ten = await showDoiTenLoTrinhDialog(context, tenHienTai: tenHienTai, tieuDe: 'Đổi tên lộ trình');
    if (ten == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loTrinhRepositoryProvider).doiTen(loTrinhId, ten);
      ref.invalidate(loTrinhDetailProvider(loTrinhId));
      ref.invalidate(loTrinhListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu tên lộ trình'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(loiDoiTen(e)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loTrinhDetailProvider(loTrinhId));
    final df = DateFormat('HH:mm dd/MM/yyyy');
    final ten = async.valueOrNull?.ten;

    return Scaffold(
      appBar: AppBar(
        title: Text(ten?.isNotEmpty == true ? ten! : 'Chi tiết lộ trình'),
        actions: [
          if (async.hasValue)
            IconButton(
              tooltip: 'Đổi tên',
              icon: const Icon(Icons.edit),
              onPressed: () => _doiTen(context, ref, ten),
            ),
        ],
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.loTrinh);
          }
        }),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải lộ trình: $e')),
        data: (lt) {
          final pts = lt.diem.map((e) => e.latLng).toList();
          return Column(children: [
            Expanded(
              child: pts.isEmpty
                  ? const Center(child: Text('Lộ trình chưa có điểm GPS nào.'))
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: pts.first,
                        initialZoom: 15,
                        initialCameraFit: pts.length >= 2
                            ? CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(40))
                            : null,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.npc.quan_ly_gas',
                        ),
                        PolylineLayer(polylines: [
                          Polyline(points: pts, strokeWidth: 5, color: Colors.blue),
                        ]),
                        MarkerLayer(markers: [
                          Marker(
                            point: pts.first,
                            width: 32,
                            height: 32,
                            child: const Icon(Icons.flag, color: Colors.green, size: 32),
                          ),
                          if (pts.length >= 2)
                            Marker(
                              point: pts.last,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                        ]),
                      ],
                    ),
            ),
            Material(
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lt.tenNhanVien != null)
                        Text(lt.tenNhanVien!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Bắt đầu: ${df.format(lt.batDauLuc)}'),
                      Text(lt.ketThucLuc != null ? 'Kết thúc: ${df.format(lt.ketThucLuc!)}' : 'Đang ghi'),
                      Text('Quãng đường: ${fmtQuangDuong(lt.tongQuangDuongM)} • '
                          'Thời gian: ${fmtThoiLuong(lt.thoiLuong)} • ${lt.diem.length} điểm'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: lt.diem.isEmpty ? null : () => _chiDuong(context, lt.diem.last),
                          icon: const Icon(Icons.directions),
                          label: const Text('Chỉ đường đến điểm kết thúc'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
