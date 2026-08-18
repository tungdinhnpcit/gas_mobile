// lib/features/chuyen_xe/data/repositories/chuyen_xe_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/chuyen_xe_model.dart';
import '../models/kiem_ke_model.dart';
import '../models/kiem_ke_doi_chieu_model.dart';

class ChuyenXeRepository {
  /// Lấy danh sách phụ xe
  Future<List<Map<String, dynamic>>> searchPhuXeAPI(String keyword) async {

    try {
      // 1. Đổi endpoint từ '/api/chuyen-xe' sang endpoint quản lý nhân viên
      final res = await ApiClient.instance.dio.get(
        '/api/nhan-vien', // Thay đổi đường dẫn này cho khớp với Backend
        queryParameters: {
          'keyword': keyword,     // Tham số tìm kiếm theo tên hoặc mã
          'chucVu': 'Phụ xe',     // Backend filter: x.ChucVu.TenChucVu.Contains(chucVu)
          'page': 1,
          'pageSize': 20,         // Chỉ nên lấy top kết quả để UI không bị giật
        },
      );

      // 2. Parse dữ liệu trả về
      final data = res.data;

      // Thường backend .NET sẽ bọc array trong một object (ví dụ: data['items'] hoặc data['data'])
      // Nếu BE trả thẳng mảng JSON thì nó sẽ rơi vào trường hợp 'data as List'
      final list = (data is Map ? (data['items'] ?? data['data']) : data) as List? ?? [];

      // 3. Ép kiểu về List<Map<String, dynamic>> để dùng chung với pattern của UI hiện tại
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  /// Lấy danh sách chuyến xe của lái xe theo nhanVienId, hỗ trợ lọc trạng thái, khoảng ngày, xe và phân trang.
  Future<List<ChuyenXeModel>> getList({
    required int nhanVienId,
    int? xeId,
    String? trangThai,
    DateTime? tuNgay,
    DateTime? denNgay,
    int page = 1,
    int pageSize = 50,
  }) async {
    debugPrint('[ChuyenXe] getList() nhanVienId=$nhanVienId xeId=$xeId trangThai=$trangThai tuNgay=$tuNgay denNgay=$denNgay');
    try {
      final res = await ApiClient.instance.dio.get(
        '/api/chuyen-xe',
        queryParameters: {
          'nhanVienId': nhanVienId,
          if (xeId    != null) 'xeId':     xeId,
          if (trangThai != null) 'trangThai': trangThai,
          if (tuNgay  != null) 'tuNgay':  tuNgay.toIso8601String(),
          if (denNgay != null) 'denNgay': denNgay.toIso8601String(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      debugPrint('[ChuyenXe] response status=${res.statusCode} data=${res.data.runtimeType}');
      final data = res.data;
      final list = (data is Map ? data['items'] : data) as List? ?? [];
      debugPrint('[ChuyenXe] parsed ${list.length} items');
      return list
          .map((e) => ChuyenXeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[ChuyenXe] DioException: ${e.type} | status=${e.response?.statusCode} | message=${e.message}');
      debugPrint('[ChuyenXe] response body: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[ChuyenXe] ERROR: $e');
      rethrow;
    }
  }

  /// Lấy danh sách chuyến xe theo trạng thái, không giới hạn lái xe — dùng cho
  /// màn hình kế toán lập kiểm kê (không truyền nhanVienId, backend trả tất cả).
  Future<List<ChuyenXeModel>> getListByTrangThai({
    required String trangThai,
    DateTime? tuNgay,
    DateTime? denNgay,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/api/chuyen-xe',
        queryParameters: {
          'trangThai': trangThai,
          if (tuNgay  != null) 'tuNgay':  tuNgay.toIso8601String(),
          if (denNgay != null) 'denNgay': denNgay.toIso8601String(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      final data = res.data;
      final list = (data is Map ? data['items'] : data) as List? ?? [];
      return list
          .map((e) => ChuyenXeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[ChuyenXe] DioException getListByTrangThai: ${e.type} | status=${e.response?.statusCode} | message=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[ChuyenXe] ERROR getListByTrangThai: $e');
      rethrow;
    }
  }

  /// Lấy danh sách chuyến xe không giới hạn lái xe, lọc theo khoảng ngày — dùng cho màn Tổng quan.
  Future<List<ChuyenXeModel>> getListAll({
    DateTime? tuNgay,
    DateTime? denNgay,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/api/chuyen-xe',
        queryParameters: {
          if (tuNgay  != null) 'tuNgay':  tuNgay.toIso8601String(),
          if (denNgay != null) 'denNgay': denNgay.toIso8601String(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      final data = res.data;
      final list = (data is Map ? data['items'] : data) as List? ?? [];
      return list.map((e) => ChuyenXeModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[ChuyenXe] DioException getListAll: ${e.type} | status=${e.response?.statusCode} | message=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[ChuyenXe] ERROR getListAll: $e');
      rethrow;
    }
  }

  /// Lấy chi tiết chuyến xe theo ID kèm danh sách hàng hóa và ảnh đã upload.
  Future<ChuyenXeModel> getById(int id) async {
    debugPrint('[ChuyenXe] GET ${AppConstants.resolvedApiUrl}/api/chuyen-xe/$id');
    try{
      final res = await ApiClient.instance.dio.get('/api/chuyen-xe/$id');
      return ChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      debugPrint('[ChuyenXe] DioException getById: ${e.type} | status=${e.response?.statusCode} | message=${e.message}');
      debugPrint('[ChuyenXe] response body: ${e.response?.data}');
      rethrow;
    }
    catch (e) {
      debugPrint('[ChuyenXe] ERROR getById: $e');
      rethrow;
    }
  }

  /// Kiểm tra chuyến xe đang thực hiện hôm nay của lái xe.
  /// Trả null nếu chưa có (HTTP 204).
  Future<ChuyenXeModel?> getActiveTripToday(int nhanVienId) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/api/chuyen-xe/active-today',
        queryParameters: {'nhanVienId': nhanVienId},
      );
      if (res.statusCode == 204 || res.data == null) return null;
      return ChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      rethrow;
    }
  }

  /// Tạo chuyến xe mới từ mobile (loai='mobile').
  Future<ChuyenXeModel> createTrip({
    required DateTime ngayXuat,
    required int xeId,
    required int nhanVienId,
    int? phuXeId,
  }) async {
    final res = await ApiClient.instance.dio.post('/api/chuyen-xe', data: {
      'ngayXuat': ngayXuat.toIso8601String(),
      'xeId': xeId,
      'nhanVienId': nhanVienId,
      if (phuXeId != null) 'phuXeId': phuXeId,
      'loai': 'mobile',
      'trangThai': 'dang-giao',
      'isActive': true,
      'chiTiet': [],
    });
    return ChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Cập nhật phụ xe cho chuyến (null = bỏ phụ xe). Lưu ngay khi chọn ở màn chi tiết.
  Future<void> capNhatPhuXe(int chuyenXeId, int? phuXeId) async {
    await ApiClient.instance.dio.post(
      '/api/chuyen-xe/$chuyenXeId/phu-xe',
      data: {'phuXeId': phuXeId},
    );
  }

  /// Lấy danh sách bán hàng lái xe đã nhập cho chuyến xe.
  Future<List<BanHangKhachHangModel>> getBanHang(int chuyenXeId) async {
    final res = await ApiClient.instance.dio
        .get('/api/chuyen-xe/$chuyenXeId/ban-hang');
    final list = res.data as List? ?? [];
    return list
        .map((e) => BanHangKhachHangModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lưu entry bán hàng lên server (không kiểm tra tồn kho ở đây).
  Future<BanHangKhachHangModel> createBanHang(
      int chuyenXeId, Map<String, dynamic> data) async {
    final res = await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang', data: data);
    return BanHangKhachHangModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Sửa entry bán hàng.
  Future<BanHangKhachHangModel> updateBanHang(
      int chuyenXeId, int banHangId, Map<String, dynamic> data) async {
    final res = await ApiClient.instance.dio
        .put('/api/chuyen-xe/$chuyenXeId/ban-hang/$banHangId', data: data);
    return BanHangKhachHangModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xóa entry bán hàng.
  Future<void> deleteBanHang(int chuyenXeId, int banHangId) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang/$banHangId/delete');
  }

  /// Xóa 1 dòng mua gas dư.
  Future<void> deleteBanHangGasDu(int chuyenXeId, int gasDuId) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang-gas-du/$gasDuId/delete');
  }

  /// Xóa 1 dòng nợ vỏ.
  Future<void> deleteBanHangNoVo(int chuyenXeId, int noVoId) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang-no-vo/$noVoId/delete');
  }

  /// Xóa 1 dòng thanh toán (cascade tự xóa hết dòng chi tiết mặt hàng liên quan).
  Future<void> deleteBanHangThanhToan(int chuyenXeId, int thanhToanId) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang-thanh-toan/$thanhToanId/delete');
  }

  /// Thêm 1 dòng mua gas dư (dùng khi admin sửa giữ nguyên chữ ký xác nhận).
  Future<int> createGasDu(int chuyenXeId, Map<String, dynamic> data) async {
    final res = await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang-gas-du', data: data);
    return res.data['id'] as int;
  }

  /// Sửa 1 dòng mua gas dư (dùng khi admin sửa giữ nguyên chữ ký xác nhận).
  Future<void> updateGasDu(
      int chuyenXeId, int gasDuId, Map<String, dynamic> data) async {
    await ApiClient.instance.dio
        .put('/api/chuyen-xe/$chuyenXeId/ban-hang-gas-du/$gasDuId', data: data);
  }

  /// Thêm 1 dòng nợ vỏ (dùng khi admin sửa giữ nguyên chữ ký xác nhận).
  Future<int> createNoVo(int chuyenXeId, Map<String, dynamic> data) async {
    final res = await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ban-hang-no-vo', data: data);
    return res.data['id'] as int;
  }

  /// Sửa 1 dòng nợ vỏ (dùng khi admin sửa giữ nguyên chữ ký xác nhận).
  Future<void> updateNoVo(
      int chuyenXeId, int noVoId, Map<String, dynamic> data) async {
    await ApiClient.instance.dio
        .put('/api/chuyen-xe/$chuyenXeId/ban-hang-no-vo/$noVoId', data: data);
  }

  /// Sửa thông tin thanh toán tại chỗ, KHÔNG đụng chữ ký xác nhận
  /// (dùng khi admin sửa giữ nguyên ảnh & chữ ký xác nhận).
  Future<void> updateThanhToan(
      int chuyenXeId, int thanhToanId, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put(
        '/api/chuyen-xe/$chuyenXeId/ban-hang-thanh-toan/$thanhToanId',
        data: data);
  }

  /// Xóa chuyến xe (chỉ dùng khi chuyến chưa kết thúc / kỳ chưa chốt).
  Future<void> deleteTrip(int chuyenXeId) async {
    await ApiClient.instance.dio.post('/api/chuyen-xe/$chuyenXeId/delete');
  }

  /// Mobile: lái xe kết thúc chuyến — đổi trangThai sang hoan-thanh.
  Future<void> ketThucMobile(int chuyenXeId) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ket-thuc-mobile');
  }

  /// Ke toan phe duyet chuyen xe — tao KetThucChuyenXe record voi so lieu quyet toan.
  /// Goi cung endpoint voi web (POST /api/chuyen-xe/{id}/ket-thuc).
  Future<void> pheduyet(int chuyenXeId, Map<String, dynamic> body) async {
    await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/ket-thuc', data: body);
  }

  /// Nhập đầy đủ thông tin bán hàng 1 khách hàng: sản phẩm + gas dư + thanh toán.
  /// Nhập bán hàng khách hàng — trả xacNhanId (xác nhận khách hàng được tạo tự động)
  Future<int> nhapKhachHang(int chuyenXeId, Map<String, dynamic> body) async {
    final token = await const FlutterSecureStorage().read(key: 'jwt_token');
    debugPrint('[NHAP_KH] POST ${ApiClient.instance.dio.options.baseUrl}/api/chuyen-xe/$chuyenXeId/nhap-khach-hang');
    debugPrint('[NHAP_KH] token: ${token != null ? '${token.substring(0, 20)}...(len=${token.length})' : 'NULL'}');
    debugPrint('[NHAP_KH] body: ${const JsonEncoder.withIndent('  ').convert(body)}');
    final res = await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/nhap-khach-hang', data: body);
    return res.data['xacNhanId'] as int? ?? 0;
  }

  /// Nén ảnh xuống ≤ 1MB bằng cách giảm dần quality (85 → 20, bước 10).
  Future<XFile> _compressToUnder1MB(XFile photo) async {
    const maxBytes = 1 * 1024 * 1024;
    if (await photo.length() <= maxBytes) return photo;

    final tmpDir = Directory.systemTemp;
    var quality = 85;
    XFile? result;

    while (quality >= 20) {
      final outPath =
          '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      result = await FlutterImageCompress.compressAndGetFile(
        photo.path,
        outPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result != null && await result.length() <= maxBytes) return result;
      quality -= 10;
    }

    return result ?? photo;
  }

  /// Upload ảnh giao hàng cho chuyến xe. Tự động nén xuống ≤ 1MB trước khi gửi.
  Future<String> uploadPhoto(int chuyenXeId, XFile photo) async {
    final compressed = await _compressToUnder1MB(photo);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        compressed.path,
        filename: compressed.name,
      ),
    });
    final res = await ApiClient.instance.dio.post(
      '/api/chuyen-xe/$chuyenXeId/photos',
      data: formData,
    );
    return res.data['url'] as String;
  }

  /// Lấy danh sách ảnh bản kê xác nhận (bản kê giấy đã ký, chụp lại sau khi kế toán phê duyệt).
  Future<List<AnhBanKeModel>> getBanKe(int chuyenXeId) async {
    final res = await ApiClient.instance.dio.get('/api/chuyen-xe/$chuyenXeId/ban-ke');
    return (res.data as List)
        .map((e) => AnhBanKeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload ảnh bản kê xác nhận — chỉ dùng được sau khi chuyến xe đã được phê duyệt/chốt số liệu.
  Future<String> uploadBanKe(int chuyenXeId, XFile photo) async {
    final compressed = await _compressToUnder1MB(photo);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        compressed.path,
        filename: compressed.name,
      ),
    });
    final res = await ApiClient.instance.dio.post(
      '/api/chuyen-xe/$chuyenXeId/ban-ke',
      data: formData,
    );
    return res.data['url'] as String;
  }

  /// Xóa ảnh bản kê xác nhận theo ID, backend xóa cả file vật lý trên server.
  Future<void> deleteBanKe(int chuyenXeId, int anhId) =>
      ApiClient.instance.dio.post('/api/chuyen-xe/$chuyenXeId/ban-ke/$anhId/delete');

  /// Lấy kiểm kê xuất hàng của chuyến xe. Trả null nếu chưa lập (HTTP 204).
  Future<KiemKeChuyenXeModel?> getKiemKe(int chuyenXeId) async {
    try {
      final res = await ApiClient.instance.dio.get('/api/chuyen-xe/$chuyenXeId/kiem-ke');
      if (res.statusCode == 204 || res.data == null) return null;
      return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      rethrow;
    }
  }

  /// Đối chiếu số bình/vỏ mang về (kế toán nhập vs suy ra từ bán hàng lái xe). Null nếu chưa lập kiểm kê.
  Future<KiemKeDoiChieuModel?> getKiemKeDoiChieu(int chuyenXeId) async {
    try {
      final res = await ApiClient.instance.dio.get('/api/chuyen-xe/$chuyenXeId/kiem-ke/doi-chieu');
      if (res.statusCode == 204 || res.data == null) return null;
      return KiemKeDoiChieuModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      rethrow;
    }
  }

  /// Lập mới hoặc thay thế toàn bộ chi tiết kiểm kê xuất hàng của chuyến xe.
  Future<KiemKeChuyenXeModel> upsertKiemKe(
    int chuyenXeId, {
    String? ghiChu,
    required List<Map<String, dynamic>> chiTiet,
  }) async {
    final res = await ApiClient.instance.dio.put(
      '/api/chuyen-xe/$chuyenXeId/kiem-ke',
      data: {
        'ghiChu': ghiChu,
        'chiTiet': chiTiet,
      },
    );
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Kiểm kê độc lập → liên kết muộn → chốt đối chiếu ───────────────────────

  /// Danh sách phiếu kiểm kê độc lập, lọc theo đã/chưa gắn chuyến và khoảng ngày lập.
  Future<List<KiemKeChuyenXeModel>> getPhieuKiemKeList({
    bool? daGanChuyen,
    DateTime? tuNgay,
    DateTime? denNgay,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '/api/kiem-ke',
      queryParameters: {
        if (daGanChuyen != null) 'daGanChuyen': daGanChuyen,
        if (tuNgay      != null) 'tuNgay':      tuNgay.toIso8601String(),
        if (denNgay     != null) 'denNgay':     denNgay.toIso8601String(),
      },
    );
    final list = res.data as List? ?? [];
    return list
        .map((e) => KiemKeChuyenXeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tạo phiếu kiểm kê độc lập (chưa gắn chuyến) — kế toán nhập số bình/vỏ xuất trước.
  Future<KiemKeChuyenXeModel> createPhieuKiemKe({
    String? ghiChu,
    required List<Map<String, dynamic>> chiTiet,
    DateTime? ngayLap, // ngày lập = ngày đang lọc ở danh sách; null → backend dùng giờ VN
    int? xeId, // xe chuẩn bị hàng — tùy chọn, chỉ mang tính tham khảo
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/api/kiem-ke',
      data: {
        'ghiChu': ghiChu,
        'chiTiet': chiTiet,
        if (ngayLap != null) 'ngayLap': ngayLap.toIso8601String(),
        'xeId': xeId,
      },
    );
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Sua phieu kiem ke doc lap (chua chot) - replace ghiChu + chiTiet.
  /// ngayLap khac null => cap nhat lai ngay lap phieu; null => giu nguyen ngay cu.
  Future<KiemKeChuyenXeModel> updatePhieuKiemKe(
    int kiemKeId, {
    String? ghiChu,
    required List<Map<String, dynamic>> chiTiet,
    DateTime? ngayLap,
    int? xeId,
  }) async {
    final res = await ApiClient.instance.dio.put(
      '/api/kiem-ke/$kiemKeId',
      data: {
        'ghiChu': ghiChu,
        'chiTiet': chiTiet,
        if (ngayLap != null) 'ngayLap': ngayLap.toIso8601String(),
        'xeId': xeId,
      },
    );
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xoa phieu kiem ke doc lap (chua chot) theo kiemKeId.
  Future<void> deletePhieuKiemKe(int kiemKeId) async {
    await ApiClient.instance.dio.post('/api/kiem-ke/$kiemKeId/delete');
  }

  /// Lấy 1 phiếu kiểm kê theo định danh (kèm chi tiết) — dùng cho màn nhập số mang về.
  Future<KiemKeChuyenXeModel> getPhieuKiemKeById(int kiemKeId) async {
    final res = await ApiClient.instance.dio.get('/api/kiem-ke/$kiemKeId');
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Kế toán nhập số bình còn lại / vỏ mang về cho phiếu (theo kiemKeId, trước khi gắn chuyến).
  Future<KiemKeChuyenXeModel> updateSoMangVe(int kiemKeId, List<Map<String, dynamic>> chiTiet) async {
    final res = await ApiClient.instance.dio.put(
      '/api/kiem-ke/$kiemKeId/so-mang-ve',
      data: {'chiTiet': chiTiet},
    );
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Gán 1 chuyến xe đã hoàn thành vào phiếu kiểm kê độc lập.
  Future<KiemKeChuyenXeModel> lienKetChuyen(int kiemKeId, int chuyenXeId) async {
    final res = await ApiClient.instance.dio.put(
      '/api/kiem-ke/$kiemKeId/lien-ket-chuyen',
      data: {'chuyenXeId': chuyenXeId},
    );
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xóa toàn bộ biên bản kiểm kê xuất hàng của chuyến xe (kế toán lập sai, muốn làm lại).
  Future<void> deleteKiemKe(int chuyenXeId) async {
    await ApiClient.instance.dio.post('/api/chuyen-xe/$chuyenXeId/kiem-ke/delete');
  }

  /// Kế toán chốt đối chiếu kiểm kê của chuyến → ghi bút toán điều chỉnh tồn kho (idempotent).
  /// Backend tự validate chuyến đã hoàn thành; có chênh lệch vẫn cho chốt.
  Future<KiemKeChuyenXeModel> chotDoiChieuKiemKe(int chuyenXeId) async {
    final res = await ApiClient.instance.dio
        .post('/api/chuyen-xe/$chuyenXeId/kiem-ke/chot');
    return KiemKeChuyenXeModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Upload xác nhận khách hàng (ảnh biên lai ký tay hoặc chữ ký trên app)
  Future<String> uploadXacNhan(
    int xacNhanId, {
    required File file,
    required String loaiXacNhan,  // 'anh' | 'ky'
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
      'loaiXacNhan': loaiXacNhan,
    });
    final res = await ApiClient.instance.dio.post(
      '/api/xac-nhan-khach-hang/$xacNhanId/upload',
      data: formData,
    );
    return res.data['url'] as String;
  }

  /// Get-or-create xác nhận khách hàng — dùng khi lái xe muốn xác nhận sau hoặc lại lỡ bỏ qua
  Future<int> getOrCreateXacNhan(int chuyenXeId, int khachHangId) async {
    final res = await ApiClient.instance.dio.post(
      '/api/xac-nhan-khach-hang/chuyen-xe/$chuyenXeId/khach-hang/$khachHangId',
    );
    return res.data['xacNhanId'] as int;
  }
}
