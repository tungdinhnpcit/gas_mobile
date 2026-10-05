// lib/core/services/sync_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/local_database.dart';
import '../network/api_client.dart';

class SyncResult {
  final int matHangMoi;
  final int nhaCCMoi;
  final int khachHangMoi;
  final int xeMoi;
  final int nhanVienMoi;
  final int taiKhoanMoi;
  int get totalSynced => matHangMoi + nhaCCMoi + khachHangMoi + xeMoi + nhanVienMoi;
  bool get hasNewItems => totalSynced > 0;
  String get summary {
    final parts = <String>[];
    if (matHangMoi > 0) parts.add('$matHangMoi mặt hàng mới');
    if (nhaCCMoi > 0) parts.add('$nhaCCMoi nhà CC mới');
    if (khachHangMoi > 0) parts.add('$khachHangMoi khách hàng mới');
    if (xeMoi > 0) parts.add('$xeMoi xe mới');
    if (nhanVienMoi > 0) parts.add('$nhanVienMoi nhân viên mới');
    return parts.isEmpty ? 'Catalog đã cập nhật' : 'Cập nhật: ${parts.join(', ')}';
  }

  const SyncResult({
    this.matHangMoi = 0,
    this.nhaCCMoi = 0,
    this.khachHangMoi = 0,
    this.xeMoi = 0,
    this.nhanVienMoi = 0,
    this.taiKhoanMoi = 0,
  });
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _db = LocalDatabase.instance;
  Dio get _dio => ApiClient.instance.dio;

  // ── Catalog sync (chạy mỗi lần mở app / app quay lại foreground) ─────────

  static const _lastSyncKey = 'last_catalog_sync_at';

  /// Đọc thời điểm đồng bộ danh mục gần nhất (null nếu chưa từng đồng bộ).
  Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_lastSyncKey) ?? '');
  }

  /// Kéo giá bán đã cấu hình của một ngày về cache. Mặt hàng chưa cấu hình
  /// sẽ không có bản ghi ⇒ khi bán hàng ô đơn giá để trống.
  Future<void> syncGiaBanNgay(DateTime ngay) async {
    final ngayStr = ngay.toIso8601String().substring(0, 10);
    try {
      final res = await _dio.get(
        '/api/gia-ban-theo-ngay/mobile',
        queryParameters: {'ngay': ngayStr},
      );
      final items = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('[SYNC] gia-ban-theo-ngay $ngayStr: ${items.length} items');
      await _db.upsertGiaBanNgay(
        ngayStr,
        items
            .map((e) => {
                  'mat_hang_id': e['matHangId'],
                  'ngay': ngayStr,
                  'gia_ban': (e['giaBan'] ?? 0).toDouble(),
                })
            .toList(),
      );
    } catch (e) {
      debugPrint('[SYNC] LỖI gia-ban-theo-ngay $ngayStr: $e');
    }
  }

  /// Kéo catalog từ server về SQLite. Trả về số lượng bản ghi mới/cập nhật.
  Future<SyncResult> syncCatalog() async {
    int matHangMoi = 0, nhaCCMoi = 0, khachHangMoi = 0, xeMoi = 0, nhanVienMoi = 0, taiKhoanMoi = 0;
    debugPrint('[SYNC] Bắt đầu sync catalog, baseUrl=${ApiClient.instance.dio.options.baseUrl}');

    try {
      // Mặt hàng — dùng /all để lấy toàn bộ, tránh bị cap pageSize
      final mhRes = await _dio.get('/api/mat-hang/all');
      debugPrint('[SYNC] mat-hang: ${(mhRes.data as List?)?.length ?? 0} items');
      final mhItems = (mhRes.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mhItems.isNotEmpty) {
        final existingMh = await _db.getMatHangList();
        final existingIds = existingMh.map((e) => e['server_id']).toSet();
        matHangMoi = mhItems.where((e) => !existingIds.contains(e['id'])).length;
        await _db.upsertMatHangList(mhItems.map((e) => {
          'server_id': e['id'],
          'ma_mat_hang': e['maMatHang'] ?? '',
          'ten_mat_hang': e['tenMatHang'] ?? '',
          'don_vi_tinh': e['donViTinh'],
          'nha_cung_cap_id': e['nhaCungCapId'],
          'ten_nha_cc': e['tenNhaCungCap'],
          'don_gia': (e['donGia'] ?? 0).toDouble(),
          'is_active': (e['isActive'] == true) ? 1 : 0,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI mat-hang: $e'); }

    // Giá bán cấu hình cho hôm nay (mặt hàng chưa cấu hình sẽ không có trong cache)
    await syncGiaBanNgay(DateTime.now());

    try {
      // Mapping bình → vỏ (để tự thêm dòng vỏ khi bán bình)
      final voRes = await _dio.get('/api/mat-hang/vo-mapping/all');
      final voItems = (voRes.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('[SYNC] vo-mapping: ${voItems.length} items');
      await _db.upsertMatHangVoList(voItems.map((e) => {
        'binh_server_id': e['binhMatHangId'],
        'vo_server_id': e['voMatHangId'],
      }).toList());
    } catch (e) { debugPrint('[SYNC] LỖI vo-mapping: $e'); }

    try {
      // Nhà cung cấp
      final nccRes = await _dio.get('/api/nha-cung-cap/all');
      debugPrint('[SYNC] nha-cung-cap: ${(nccRes.data as List?)?.length ?? 0} items');
      final nccItems = (nccRes.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (nccItems.isNotEmpty) {
        final existingNcc = await _db.getNhaCungCapList();
        final existingIds = existingNcc.map((e) => e['server_id']).toSet();
        nhaCCMoi = nccItems.where((e) => !existingIds.contains(e['id'])).length;
        await _db.upsertNhaCungCapList(nccItems.map((e) => {
          'server_id': e['id'],
          'ma_ncc': e['maNCC'] ?? '',
          'ten_ncc': e['tenNCC'] ?? '',
          'is_active': 1,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI nha-cung-cap: $e'); }

    try {
      // Khách hàng — dùng /all để lấy toàn bộ, tránh bị cap pageSize
      final khRes = await _dio.get('/api/khach-hang/all');
      final khItems = ((khRes.data as List?)?.cast<Map<String, dynamic>>() ?? [])
          .where((e) => e['isActive'] != false)
          .toList();
      debugPrint('[SYNC] khach-hang: ${khItems.length} items');
      if (khItems.isNotEmpty) {
        final existingKh = await _db.getKhachHangList();
        final existingIds = existingKh
            .where((e) => e['server_id'] != null)
            .map((e) => e['server_id'])
            .toSet();
        khachHangMoi = khItems.where((e) => !existingIds.contains(e['id'])).length;
        await _db.upsertKhachHangList(khItems.map((e) => {
          'server_id': e['id'],
          'ma_khach_hang': e['maKhachHang'],
          'ten_khach_hang': e['tenKhachHang'] ?? '',
          'dia_chi': e['diaChi'],
          'so_dien_thoai': e['soDienThoai'],
          'email': e['email'],
          'latitude': e['latitude'],
          'longitude': e['longitude'],
          'is_active': (e['isActive'] == true) ? 1 : 0,
          'is_offline_created': 0,
          'is_synced': 1,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI khach-hang: $e'); }

    try {
      // Xe — dùng /all để lấy toàn bộ, tránh bị cap pageSize
      final xeRes = await _dio.get('/api/xe/all');
      final xeItems = ((xeRes.data as List?)?.cast<Map<String, dynamic>>() ?? [])
          .where((e) => e['isActive'] != false)
          .toList();
      debugPrint('[SYNC] xe: ${xeItems.length} items');
      if (xeItems.isNotEmpty) {
        final existingXe = await _db.getXeList();
        final existingIds = existingXe.map((e) => e['server_id']).toSet();
        xeMoi = xeItems.where((e) => !existingIds.contains(e['id'])).length;
        await _db.upsertXeList(xeItems.map((e) => {
          'server_id': e['id'],
          'bien_so_xe': e['bienSoXe'] ?? '',
          'loai_xe': e['loaiXe'],
          'nhan_vien_lai_xe_id': e['nhanVienLaiXeId'],
          'nhan_vien_phu_xe_id': e['nhanVienPhuXeId'],
          'is_active': (e['isActive'] == true) ? 1 : 0,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI xe: $e'); }

    try {
      // Nhân viên (lái xe)
      final nvRes = await _dio.get('/api/nhan-vien/lai-xe');
      final nvItems = (nvRes.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('[SYNC] nhan-vien: ${nvItems.length} items');
      if (nvItems.isNotEmpty) {
        // Xóa cache cũ để tránh data stale (is_lai_xe=0 từ version cũ)
        await _db.clearNhanVienCache();
        nhanVienMoi = nvItems.length;
        await _db.upsertNhanVienList(nvItems.map((e) => {
          'server_id':    e['id'],
          'ma_nhan_vien': e['maNhanVien'] ?? '',
          'ho_ten':       e['hoTen'] ?? '',
          'ten_chuc_vu':  null,
          'is_lai_xe':    1, // endpoint /lai-xe chỉ trả lái xe, luôn = 1
          'is_active':    1,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI nhan-vien: $e'); }

    try {
      // Tài khoản công ty (dùng cho dropdown chuyển khoản)
      final tkRes = await _dio.get('/api/tai-khoan');
      final tkItems = (tkRes.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('[SYNC] tai-khoan: ${tkItems.length} items');
      if (tkItems.isNotEmpty) {
        taiKhoanMoi = tkItems.length;
        await _db.upsertTaiKhoanList(tkItems.map((e) => {
          'server_id':     e['id'],
          'ma_tai_khoan':  e['maTaiKhoan'] ?? '',
          'ten_tai_khoan': e['tenTaiKhoan'] ?? '',
          'loai':          e['loai'] ?? '',
          'so_tai_khoan':  e['soTaiKhoan'],
          'ngan_hang':     e['nganHang'],
          'is_active':     (e['isActive'] == true) ? 1 : 0,
        }).toList());
      }
    } catch (e) { debugPrint('[SYNC] LỖI tai-khoan: $e'); }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return SyncResult(
      matHangMoi: matHangMoi,
      nhaCCMoi: nhaCCMoi,
      khachHangMoi: khachHangMoi,
      xeMoi: xeMoi,
      nhanVienMoi: nhanVienMoi,
      taiKhoanMoi: taiKhoanMoi,
    );
  }
}
