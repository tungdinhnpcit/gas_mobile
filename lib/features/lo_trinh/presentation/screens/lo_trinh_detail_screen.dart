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
import '../widgets/anh_lo_trinh_section.dart';
import '../widgets/hoan_tat_lo_trinh_sheet.dart';
import '../widgets/lo_trinh_polyline.dart';

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

  /// Mở sheet sửa tên / ghi chú / ảnh; sheet tự lưu và làm mới chi tiết + danh sách.
  Future<void> _suaThongTin(BuildContext context) async {
    final ok = await showHoanTatLoTrinhSheet(context, loTrinhId, tieuDe: 'Sửa thông tin lộ trình');
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin lộ trình'), backgroundColor: Colors.green));
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
              tooltip: 'Sửa thông tin',
              icon: const Icon(Icons.edit),
              onPressed: () => _suaThongTin(context),
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
                        PolylineLayer(polylines: dungPolylineLoTrinh(lt.diem)),
                        // Ảnh có toạ độ → ghim icon camera, bấm để xem ảnh
                        MarkerLayer(markers: [
                          for (final a in lt.anh.where((a) => a.latLng != null))
                            Marker(
                              point: a.latLng!,
                              width: 34,
                              height: 34,
                              child: GestureDetector(
                                onTap: () => xemAnhLoTrinh(context, a),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
                                  ),
                                  child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
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
                      if (lt.ghiChu?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ghi chú: ${lt.ghiChu}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 8),
                      AnhLoTrinhSection(loTrinh: lt),
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
