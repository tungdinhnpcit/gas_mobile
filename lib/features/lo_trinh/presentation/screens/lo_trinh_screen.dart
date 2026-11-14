// lib/features/lo_trinh/presentation/screens/lo_trinh_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lo_trinh_model.dart';
import '../../services/lo_trinh_tracking_service.dart';
import '../providers/lo_trinh_provider.dart';
import '../widgets/hoan_tat_lo_trinh_sheet.dart';
import '../widgets/lo_trinh_polyline.dart';

/// Màn hình ghi lộ trình (root navigator — có Scaffold/AppBar riêng, không hiện bottom tabs):
/// bản đồ vị trí hiện tại, polyline đang ghi, nút Bắt đầu / Kết thúc.
class LoTrinhScreen extends ConsumerStatefulWidget {
  const LoTrinhScreen({super.key});

  @override
  ConsumerState<LoTrinhScreen> createState() => _LoTrinhScreenState();
}

class _LoTrinhScreenState extends ConsumerState<LoTrinhScreen> {
  final _mapController = MapController();
  LatLng? _viTriHienTai;
  StreamSubscription<Position>? _xemViTri;
  Timer? _dongHo;
  bool _theoDoi = true; // tự động đưa bản đồ theo vị trí

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(loTrinhTrackingProvider.notifier).khoiPhuc());
    _layViTri();
    // Cập nhật đồng hồ thời lượng mỗi giây khi đang ghi
    _dongHo = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(loTrinhTrackingProvider).dangGhi) setState(() {});
    });
  }

  @override
  void dispose() {
    _xemViTri?.cancel();
    _dongHo?.cancel();
    super.dispose();
  }

  /// Lấy vị trí hiện tại và theo dõi vị trí khi đang mở màn hình (để hiện chấm xanh).
  Future<void> _layViTri() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _capNhatViTri(LatLng(pos.latitude, pos.longitude));
      _xemViTri = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((p) => _capNhatViTri(LatLng(p.latitude, p.longitude)));
    } catch (e) {
      debugPrint('[LO_TRINH] lấy vị trí lỗi: $e');
    }
  }

  void _capNhatViTri(LatLng v) {
    if (!mounted) return;
    setState(() => _viTriHienTai = v);
    if (_theoDoi) _mapController.move(v, _mapController.camera.zoom);
  }

  /// Bấm Bắt đầu: tạo lộ trình + bật ghi nền.
  Future<void> _batDau() async {
    final loi = await ref.read(loTrinhTrackingProvider.notifier).batDau();
    if (loi != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi), backgroundColor: Colors.red));
    }
  }

  /// Bấm Kết thúc: xác nhận rồi dừng ghi, mở chi tiết lộ trình vừa ghi.
  Future<void> _ketThuc() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc lộ trình?'),
        content: const Text('Ứng dụng sẽ dừng ghi vị trí và lưu lộ trình.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kết thúc')),
        ],
      ),
    );
    if (ok != true) return;
    final id = await ref.read(loTrinhTrackingProvider.notifier).ketThuc();
    if (id == null || !mounted) return;

    // Bước hoàn tất: nhập tên, ghi chú, bổ sung ảnh (bỏ qua được — lộ trình đã được lưu)
    await showHoanTatLoTrinhSheet(context, id, tieuDe: 'Hoàn tất lộ trình');
    if (!mounted) return;
    ref.invalidate(loTrinhListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu lộ trình'), backgroundColor: Colors.green));
    // Mở chi tiết lộ trình vừa ghi thay cho màn ghi
    context.pushReplacement(AppRoutes.loTrinhDetail(id));
  }

  /// Bấm Huỷ: xác nhận rồi dừng ghi và xoá lộ trình đang ghi, quay về danh sách.
  Future<void> _huy() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ lộ trình?'),
        content: const Text('Lộ trình đang ghi và toàn bộ điểm đã ghi sẽ bị xoá, không thể khôi phục.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Huỷ lộ trình'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final loi = await ref.read(loTrinhTrackingProvider.notifier).huy();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (loi != null) {
      messenger.showSnackBar(SnackBar(content: Text(loi), backgroundColor: Colors.red));
      return;
    }
    ref.invalidate(loTrinhListProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Đã huỷ lộ trình')));
    _veDanhSach();
  }

  /// Quay về màn danh sách lộ trình.
  void _veDanhSach() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.loTrinh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(loTrinhTrackingProvider);
    final center = _viTriHienTai ?? const LatLng(21.0285, 105.8542); // mặc định Hà Nội

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi lộ trình'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.loTrinh);
          }
        }),
      ),
      body: Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16,
                  // Người dùng kéo bản đồ → ngừng tự động bám theo vị trí
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _theoDoi) setState(() => _theoDoi = false);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.npc.quan_ly_gas',
                  ),
                  if (st.diem.length >= 2)
                    PolylineLayer(polylines: dungPolylineLoTrinh(st.diem)),
                  MarkerLayer(markers: [
                    if (st.diem.isNotEmpty)
                      Marker(
                        point: st.diem.first.latLng,
                        width: 28,
                        height: 28,
                        child: const Icon(Icons.flag, color: Colors.green, size: 28),
                      ),
                    if (_viTriHienTai != null)
                      Marker(
                        point: _viTriHienTai!,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(children: [
                  FloatingActionButton.small(
                    heroTag: 'lo_trinh_vi_tri',
                    tooltip: 'Về vị trí hiện tại',
                    onPressed: () {
                      setState(() => _theoDoi = true);
                      if (_viTriHienTai != null) _mapController.move(_viTriHienTai!, 16);
                    },
                    child: Icon(_theoDoi ? Icons.my_location : Icons.location_searching),
                  ),
                ]),
              ),
            ],
          ),
        ),
        _BangDieuKhien(st: st, onBatDau: _batDau, onKetThuc: _ketThuc, onHuy: _huy),
      ],
      ),
    );
  }
}

/// Thanh dưới: thông số lộ trình đang ghi + nút Bắt đầu / Kết thúc.
class _BangDieuKhien extends StatelessWidget {
  final LoTrinhTrackingState st;
  final VoidCallback onBatDau;
  final VoidCallback onKetThuc;
  final VoidCallback onHuy;
  const _BangDieuKhien({
    required this.st,
    required this.onBatDau,
    required this.onKetThuc,
    required this.onHuy,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (st.dangGhi) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ThongSo(label: 'Thời gian', value: fmtThoiLuong(st.loTrinh!.thoiLuong)),
                    _ThongSo(label: 'Quãng đường', value: fmtQuangDuong(st.quangDuongM)),
                    _ThongSo(label: 'Chờ gửi', value: '${st.soDiemCho} điểm'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                if (st.dangGhi) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: st.dangXuLy ? null : onHuy,
                        icon: const Icon(Icons.close),
                        label: const Text('Huỷ lộ trình'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: st.dangGhi ? Colors.red : Colors.green,
                  ),
                  onPressed: st.dangXuLy ? null : (st.dangGhi ? onKetThuc : onBatDau),
                  icon: st.dangXuLy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(st.dangGhi ? Icons.stop : Icons.play_arrow),
                  label: Text(st.dangGhi ? 'Kết thúc' : 'Bắt đầu ghi lộ trình'),
                ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThongSo extends StatelessWidget {
  final String label;
  final String value;
  const _ThongSo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
}
