// lib/features/khach_hang/presentation/screens/khach_hang_detail_screen.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:quan_ly_gas_app/core/map/osm_tile_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../data/models/khach_hang_model.dart';
import '../providers/khach_hang_provider.dart';

class KhachHangDetailScreen extends ConsumerStatefulWidget {
  final int id;
  /// Ngày mua cuối cùng (optional) — truyền vào từ danh sách "khách hàng lâu chưa mua".
  final DateTime? ngayMuaCuoiCung;
  const KhachHangDetailScreen({super.key, required this.id, this.ngayMuaCuoiCung});

  @override
  ConsumerState<KhachHangDetailScreen> createState() =>
      _KhachHangDetailScreenState();
}

class _KhachHangDetailScreenState
    extends ConsumerState<KhachHangDetailScreen> {
  bool _loadingLocation = false;
  bool _uploading = false;

  // Xây dựng URL ảnh từ đường dẫn tương đối trả về từ server
  String _buildImageUrl(String relativePath) {
    final uri = Uri.parse(AppConstants.resolvedApiUrl);
    final serverRoot = '${uri.scheme}://${uri.host}:${uri.port}';
    return '$serverRoot$relativePath';
  }

  // Mở dialog xem ảnh cửa hàng full màn hình, hỗ trợ zoom/pan
  void _showAnhFull(String relativePath) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: _buildImageUrl(relativePath),
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Xin quyền location, trả về true nếu được cấp
  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cần cấp quyền vị trí trong Cài đặt'),
          action: SnackBarAction(
            label: 'Mở cài đặt',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }

  // Xin quyền camera, trả về true nếu được cấp
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cần cấp quyền camera trong Cài đặt'),
          action: SnackBarAction(
            label: 'Mở cài đặt',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }

  // Lấy GPS hiện tại và lưu lên server
  Future<void> _updateLocation(KhachHangModel kh) async {
    final ok = await _requestLocationPermission();
    if (!ok) return;

    setState(() => _loadingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final repo = ref.read(khachHangRepositoryProvider);
      await repo.updateViTri(kh, pos.latitude, pos.longitude);
      ref.invalidate(khachHangDetailProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã cập nhật vị trí: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lấy vị trí: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  /// Hiện bottom sheet chọn nguồn ảnh — camera hoặc thư viện
  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Upload ảnh cửa hàng từ camera hoặc thư viện
  Future<void> _uploadAnh(KhachHangModel kh) async {
    final source = await _pickSource();
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      final ok = await _requestCameraPermission();
      if (!ok) return;
    }

    final picker = ImagePicker();
    final photo = await picker.pickImage(source: source, imageQuality: 85);
    if (photo == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(khachHangRepositoryProvider);
      await repo.uploadAnh(kh.id, File(photo.path));
      ref.invalidate(khachHangDetailProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật ảnh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Mở ứng dụng bản đồ native để chỉ đường đến khách hàng
  Future<void> _chiDuong(double lat, double lng) async {
    final Uri uri = Platform.isIOS
        ? Uri.parse('maps://?daddr=$lat,$lng')
        : Uri.parse('geo:$lat,$lng?q=$lat,$lng');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final fallback = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(khachHangDetailProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết khách hàng')),
      bottomNavigationBar: const AppBottomNavBar(),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(khachHangDetailProvider(widget.id)),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (kh) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildThongTin(kh),
            const SizedBox(height: 16),
            _buildAnhCuaHang(kh),
            const SizedBox(height: 16),
            _buildViTri(kh),
          ],
        ),
      ),
    );
  }

  // Section 1: Thông tin cơ bản
  Widget _buildThongTin(KhachHangModel kh) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                child: Text(
                  kh.tenKhachHang.isNotEmpty
                      ? kh.tenKhachHang[0].toUpperCase()
                      : 'K',
                  style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kh.maKhachHang,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(kh.tenKhachHang,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kh.isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kh.isActive ? 'Hoạt động' : 'Ngừng KD',
                  style: TextStyle(
                      color: kh.isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const Divider(height: 24),
            if (widget.ngayMuaCuoiCung != null)
              _InfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Mua cuối',
                  value: DateFormat('dd/MM/yyyy')
                      .format(widget.ngayMuaCuoiCung!.toLocal())),
            if (kh.diaChi != null)
              _InfoRow(icon: Icons.location_on_outlined, label: 'Địa chỉ', value: kh.diaChi!),
            if (kh.soDienThoai != null)
              _InfoRow(icon: Icons.phone_outlined, label: 'SĐT', value: kh.soDienThoai!),
            if (kh.email != null)
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: kh.email!),
          ],
        ),
      ),
    );
  }

  // Section 2: Ảnh cửa hàng
  Widget _buildAnhCuaHang(KhachHangModel kh) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ảnh cửa hàng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            kh.anhCuaHang != null
                ? GestureDetector(
                    onTap: () => _showAnhFull(kh.anhCuaHang!),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: _buildImageUrl(kh.anhCuaHang!),
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    size: 28, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.zoom_out_map,
                              size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Chưa có ảnh cửa hàng',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : () => _uploadAnh(kh),
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_uploading
                    ? 'Đang upload...'
                    : 'Cập nhật ảnh cửa hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section 3: Vị trí bản đồ
  Widget _buildViTri(KhachHangModel kh) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vị trí cửa hàng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (kh.hasLocation) ...[
              Text(
                '${kh.latitude!.toStringAsFixed(5)}, ${kh.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 280,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(kh.latitude!, kh.longitude!),
                      initialZoom: 15,
                    ),
                    children: [
                      osmTileLayer(),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(kh.latitude!, kh.longitude!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingLocation ? null : () => _updateLocation(kh),
                    icon: _loadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Cập nhật vị trí'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _chiDuong(kh.latitude!, kh.longitude!),
                    icon: const Icon(Icons.directions),
                    label: const Text('Chỉ đường'),
                  ),
                ),
              ]),
            ] else ...[
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off_outlined, size: 36, color: Colors.grey),
                    SizedBox(height: 6),
                    Text('Chưa có tọa độ', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loadingLocation ? null : () => _updateLocation(kh),
                  icon: _loadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_loadingLocation
                      ? 'Đang lấy vị trí...'
                      : 'Thu thập vị trí GPS'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
