// lib/features/vi_tri/presentation/screens/vi_tri_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:quan_ly_gas_app/core/map/osm_tile_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/vi_tri_chia_se_model.dart';
import '../providers/vi_tri_provider.dart';

/// Vị trí của 1 điện thoại trên bản đồ OpenStreetMap (root navigator),
/// kèm vị trí của chính mình và nút chỉ đường bằng Google Maps.
class ViTriDetailScreen extends ConsumerStatefulWidget {
  final int viTriId;
  const ViTriDetailScreen({super.key, required this.viTriId});

  @override
  ConsumerState<ViTriDetailScreen> createState() => _ViTriDetailScreenState();
}

class _ViTriDetailScreenState extends ConsumerState<ViTriDetailScreen> {
  final _map = MapController();
  LatLng? _viTriToi; // vị trí điện thoại đang xem (của mình)

  @override
  void initState() {
    super.initState();
    _layViTriToi();
  }

  /// Lấy vị trí hiện tại của mình để hiển thị chấm xanh (bỏ qua nếu chưa có quyền).
  Future<void> _layViTriToi() async {
    try {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) setState(() => _viTriToi = LatLng(last.latitude, last.longitude));
      final cur = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      if (mounted) setState(() => _viTriToi = LatLng(cur.latitude, cur.longitude));
    } catch (_) {}
  }

  /// Mở Google Maps chỉ đường từ vị trí hiện tại đến vị trí điện thoại.
  Future<void> _chiDuong(ViTriChiaSeModel v) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${v.lat},${v.lng}&travelmode=driving');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được ứng dụng bản đồ')));
    }
  }

  /// Zoom bản đồ để thấy cả 2 vị trí (hoặc chỉ vị trí điện thoại).
  void _canGiua(ViTriChiaSeModel v) {
    if (_viTriToi == null) {
      _map.move(v.latLng, 16);
    } else {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([v.latLng, _viTriToi!]),
        padding: const EdgeInsets.all(60),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(viTriDetailProvider(widget.viTriId));
    final df = DateFormat('HH:mm dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.tenHienThi ?? 'Vị trí điện thoại'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.viTri);
          }
        }),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(viTriDetailProvider(widget.viTriId)),
          ),
        ],
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải vị trí: $e')),
        data: (v) => Column(children: [
          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(initialCenter: v.latLng, initialZoom: 16),
                children: [
                  osmTileLayer(),
                  if (v.doChinhXac != null && v.doChinhXac! > 0)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: v.latLng,
                        radius: v.doChinhXac!,
                        useRadiusInMeter: true,
                        color: Colors.red.withValues(alpha: 0.12),
                        borderColor: Colors.red.withValues(alpha: 0.4),
                        borderStrokeWidth: 1,
                      ),
                    ]),
                  MarkerLayer(markers: [
                    if (_viTriToi != null)
                      Marker(
                        point: _viTriToi!,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
                          ),
                        ),
                      ),
                    Marker(
                      point: v.latLng,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_pin, color: v.isCu ? Colors.grey : Colors.red, size: 44),
                    ),
                  ]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap')]),
                ],
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Căn giữa',
                  onPressed: () => _canGiua(v),
                  child: const Icon(Icons.center_focus_strong),
                ),
              ),
            ]),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(v.tenHienThi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (v.deviceInfo?.isNotEmpty == true)
                    Text(v.deviceInfo!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Cập nhật: ${df.format(v.thoiGianCapNhat)} (${v.capNhatLuc})',
                    style: TextStyle(color: v.isCu ? Colors.orange.shade800 : Colors.green.shade700),
                  ),
                  if (v.doChinhXac != null) Text('Sai số: ±${v.doChinhXac!.round()} m'),
                  if (_viTriToi != null)
                    Text('Khoảng cách từ bạn: ${_khoangCach(_viTriToi!, v.latLng)}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _chiDuong(v),
                      icon: const Icon(Icons.directions),
                      label: const Text('Chỉ đường bằng Google Maps'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Khoảng cách đường chim bay giữa 2 điểm, định dạng m / km.
  String _khoangCach(LatLng a, LatLng b) {
    final m = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }
}
