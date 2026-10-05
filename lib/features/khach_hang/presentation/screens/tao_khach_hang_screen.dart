// lib/features/khach_hang/presentation/screens/tao_khach_hang_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';

class TaoKhachHangScreen extends ConsumerStatefulWidget {
  /// Callback tuy chon — goi voi Map khach hang vua tao truoc khi pop.
  /// Dung de man goi (vd NhapBanHangScreen) gan khach truc tiep, khong phu
  /// thuoc gia tri tra ve cua context.push (bi loi khi co PopScope canPop:false).
  final void Function(Map<String, dynamic>)? onCreated;

  const TaoKhachHangScreen({super.key, this.onCreated});

  @override
  ConsumerState<TaoKhachHangScreen> createState() => _TaoKhachHangScreenState();
}

class _TaoKhachHangScreenState extends ConsumerState<TaoKhachHangScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController();
  final _sdtCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  bool _saving = false;

  // Đánh dấu user đã bấm "Lấy vị trí" ít nhất 1 lần (để hiện lỗi đúng lúc)
  bool _locationTouched = false;

  @override
  void dispose() {
    _tenCtrl.dispose();
    _diaChiCtrl.dispose();
    _sdtCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // Lấy tọa độ GPS hiện tại của thiết bị
  Future<void> _getLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationTouched = true;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không có quyền truy cập vị trí. Vui lòng bật trong Cài đặt.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không lấy được vị trí: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _save() async {
    // Kiểm tra GPS trước form validate
    if (_latitude == null) {
      setState(() => _locationTouched = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng lấy tọa độ GPS trước khi lưu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final data = {
        'tenKhachHang': _tenCtrl.text.trim(),
        'diaChi': _diaChiCtrl.text.trim(),
        'soDienThoai': _sdtCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'isActive': true,
      };

      debugPrint('[TaoKhachHang] POST /api/khach-hang data=$data');
      final res = await ApiClient.instance.dio.post(
        '/api/khach-hang',
        data: data,
      );
      debugPrint('[TaoKhachHang] Response ${res.statusCode}: ${res.data}');
      final serverId = res.data['id'] as int;
      await LocalDatabase.instance.upsertKhachHangList([
        {
          'server_id': serverId,
          'ten_khach_hang': data['tenKhachHang'],
          'dia_chi': data['diaChi'],
          'so_dien_thoai': data['soDienThoai'],
          'email': data['email'],
          'latitude': _latitude,
          'longitude': _longitude,
          'is_active': 1,
          'is_offline_created': 0,
          'is_synced': 1,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo khách hàng'),
            backgroundColor: Colors.green,
          ),
        );
        // Trả về khách vừa tạo (cùng bộ key với màn tìm kiếm) để màn gọi tự chọn.
        // Ưu tiên callback (không phụ thuộc pop-result vốn bị lỗi với PopScope);
        // vẫn giữ pop kèm giá trị để tương thích các màn gọi cũ dùng return value.
        final khMap = <String, dynamic>{
          'server_id': serverId,
          'local_id': null,
          'ten_khach_hang': data['tenKhachHang'],
          'dia_chi': data['diaChi'],
          'so_dien_thoai': data['soDienThoai'],
          'email': data['email'],
          'latitude': _latitude,
          'longitude': _longitude,
        };
        widget.onCreated?.call(khMap);
        context.pop(khMap);
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('[TaoKhachHang] DioException type=${e.type}');
        debugPrint('[TaoKhachHang] status=${e.response?.statusCode}');
        debugPrint('[TaoKhachHang] response=${e.response?.data}');
        debugPrint('[TaoKhachHang] message=${e.message}');
        debugPrint('[TaoKhachHang] url=${e.requestOptions.uri}');
        final errMsg =
            e.response?.data?['message'] ?? e.message ?? e.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $errMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        debugPrint('[TaoKhachHang] Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;
    final locationError = _locationTouched && !hasLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo khách hàng'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tên khách hàng ──────────────────────────────────────
              TextFormField(
                controller: _tenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên khách hàng *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên'
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Địa chỉ (bắt buộc) ──────────────────────────────────
              TextFormField(
                controller: _diaChiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập địa chỉ'
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Số điện thoại (bắt buộc) ────────────────────────────
              TextFormField(
                controller: _sdtCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập số điện thoại'
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Tọa độ GPS (bắt buộc) ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: locationError
                        ? Colors.red
                        : hasLocation
                        ? const Color(0xFF00897B)
                        : Colors.grey.shade400,
                    width: locationError || hasLocation ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: locationError
                              ? Colors.red
                              : hasLocation
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tọa độ GPS *',
                          style: TextStyle(
                            fontSize: 12,
                            color: locationError
                                ? Colors.red
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Button lấy vị trí
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _gettingLocation ? null : _getLocation,
                        icon: _gettingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                hasLocation ? Icons.refresh : Icons.my_location,
                                size: 18,
                              ),
                        label: Text(
                          _gettingLocation
                              ? 'Đang lấy vị trí...'
                              : hasLocation
                              ? 'Lấy lại vị trí'
                              : 'Lấy vị trí hiện tại',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          side: const BorderSide(color: Color(0xFF00897B)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),

                    // Hiển thị kết quả tọa độ
                    if (hasLocation) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF00897B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else if (locationError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Vui lòng lấy tọa độ GPS',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Email (tùy chọn) ─────────────────────────────────────
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Nút lưu ─────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
