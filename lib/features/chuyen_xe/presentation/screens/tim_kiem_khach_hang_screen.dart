// lib/features/chuyen_xe/presentation/screens/tim_kiem_khach_hang_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/utils/vietnamese_text.dart';
import '../../../khach_hang/data/repositories/khach_hang_repository.dart';

/// Màn hình tìm kiếm khách hàng — trả về Map khách hàng đã chọn qua context.pop().
class TimKiemKhachHangScreen extends StatefulWidget {
  const TimKiemKhachHangScreen({super.key});

  @override
  State<TimKiemKhachHangScreen> createState() => _TimKiemKhachHangScreenState();
}

class _TimKiemKhachHangScreenState extends State<TimKiemKhachHangScreen> {
  final _db = LocalDatabase.instance;
  final _repo = KhachHangRepository();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Tải danh sách khách hàng:
  /// - Gọi API /api/khach-hang/all để lấy danh sách mới nhất (bao gồm khách
  ///   vừa thêm trên web), đồng thời cập nhật lại cache SQLite.
  /// - API lỗi: dùng cache danh mục đã đồng bộ khi mở app.
  /// Danh sách hiển thị luôn đọc lại từ cache để giữ nguyên format Map.
  Future<void> _load() async {
    try {
      final list = await _repo.getAll();
      await _db.upsertKhachHangList(list.map((kh) => {
            'server_id': kh.id,
            'ma_khach_hang': kh.maKhachHang,
            'ten_khach_hang': kh.tenKhachHang,
            'dia_chi': kh.diaChi,
            'so_dien_thoai': kh.soDienThoai,
            'email': kh.email,
            'latitude': kh.latitude,
            'longitude': kh.longitude,
            'is_active': kh.isActive ? 1 : 0,
            'is_offline_created': 0,
            'is_synced': 1,
          }).toList());
    } catch (_) {
      // Lỗi API → dùng cache hiện có, không chặn người dùng
    }

    final list = await _db.getKhachHangList();
    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _onSearch() {
    // Bỏ dấu tiếng Việt cả query lẫn dữ liệu để "tuan" khớp "Tuấn Hạnh"
    final q = removeDiacritics(_searchCtrl.text.trim());
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((kh) {
          final ten = removeDiacritics(kh['ten_khach_hang'] as String? ?? '');
          final sdt = removeDiacritics(kh['so_dien_thoai'] as String? ?? '');
          final dc  = removeDiacritics(kh['dia_chi'] as String? ?? '');
          return ten.contains(q) || sdt.contains(q) || dc.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn khách hàng'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          // ── Search box ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, SĐT, địa chỉ...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // ── Đếm kết quả ────────────────────────────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} khách hàng',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // ── Danh sách ──────────────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Không tìm thấy khách hàng',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) => _KhachHangItem(
                  kh: _filtered[i],
                  onTap: () => context.pop(_filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card từng khách hàng — reverse geocode địa chỉ tọa độ bất đồng bộ ─────

class _KhachHangItem extends StatefulWidget {
  final Map<String, dynamic> kh;
  final VoidCallback onTap;

  const _KhachHangItem({required this.kh, required this.onTap});

  @override
  State<_KhachHangItem> createState() => _KhachHangItemState();
}

class _KhachHangItemState extends State<_KhachHangItem> {
  // Cache static: tránh gọi API lại khi list rebuild
  static final Map<String, String> _geoCache = {};

  String? _locationName;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final lat = widget.kh['latitude'] as double?;
    final lng = widget.kh['longitude'] as double?;
    if (lat == null || lng == null) return;

    final key =
        '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

    if (_geoCache.containsKey(key)) {
      if (mounted) setState(() => _locationName = _geoCache[key]);
      return;
    }

    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
      )).get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'accept-language': 'vi',
          'zoom': 16,
        },
        options: Options(
          headers: {'User-Agent': 'QuanLyGasApp/1.0 (gas management)'},
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final data = res.data;
      // Ưu tiên tên địa điểm ngắn gọn: road + suburb/city
      String? name;
      if (data is Map) {
        final addr = data['address'] as Map?;
        if (addr != null) {
          final parts = <String>[];
          final road     = addr['road'] as String?;
          final suburb   = addr['suburb'] as String?;
          final city     = addr['city'] as String?
                        ?? addr['town'] as String?
                        ?? addr['district'] as String?;
          if (road   != null) parts.add(road);
          if (suburb != null) parts.add(suburb);
          if (city   != null) parts.add(city);
          name = parts.isNotEmpty ? parts.join(', ') : data['display_name'] as String?;
        } else {
          name = data['display_name'] as String?;
        }
      }
      if (name != null && name.isNotEmpty) {
        _geoCache[key] = name;
        if (mounted) setState(() => _locationName = name);
      }
    } catch (_) {
      // Không hiện lỗi — fallback sang tọa độ text
    }
  }

  @override
  Widget build(BuildContext context) {
    final kh  = widget.kh;
    final ten = kh['ten_khach_hang'] as String? ?? '';
    final sdt = kh['so_dien_thoai'] as String?;
    final dc  = kh['dia_chi'] as String?;
    final lat = kh['latitude'] as double?;
    final lng = kh['longitude'] as double?;
    final hasCoord = lat != null && lng != null;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar chữ cái đầu
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFF00897B).withValues(alpha: 0.12),
              child: Text(
                ten.isNotEmpty ? ten[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên
                  Text(ten,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),

                  // Số điện thoại
                  if (sdt != null && sdt.isNotEmpty)
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        text: sdt,
                        color: Colors.grey.shade700),

                  // Địa chỉ
                  if (dc != null && dc.isNotEmpty)
                    _InfoRow(
                        icon: Icons.home_outlined,
                        text: dc,
                        color: Colors.grey.shade700,
                        maxLines: 1),

                  // Vị trí từ tọa độ
                  if (hasCoord)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      color: const Color(0xFF00897B),
                      text: _locationName != null
                          ? _locationName!
                          : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      trailing: _locationName == null
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFF00897B)),
                            )
                          : null,
                      maxLines: 2,
                    ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final int maxLines;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    this.maxLines = 1,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
