// lib/features/thu_vien_anh/data/thu_vien_anh_repository.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import 'thu_vien_anh_model.dart';

class ThuVienAnhRepository {
  // Dio riêng để tải ảnh tĩnh (URL tuyệt đối, không qua baseUrl /apimanager)
  final Dio _staticDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.bytes,
  ));

  /// Lấy 1 trang ảnh theo bộ lọc ngày / tìm kiếm / loại.
  Future<ThuVienAnhPage> getPage({
    DateTime? tuNgay,
    DateTime? denNgay,
    String? search,
    String? loai,
    int page = 1,
    int pageSize = 60,
  }) async {
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final res = await ApiClient.instance.dio.get('/api/thu-vien-anh', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (tuNgay != null) 'tuNgay': d(tuNgay),
      if (denNgay != null) 'denNgay': d(denNgay),
      if (search != null && search.isNotEmpty) 'search': search,
      if (loai != null && loai.isNotEmpty) 'loai': loai,
    });
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => AnhItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ThuVienAnhPage(items, data['totalCount'] as int? ?? 0, data['isQuanTri'] as bool? ?? false);
  }

  /// URL tuyệt đối của ảnh tĩnh.
  static String fullUrl(String url) => '${AppConstants.staticBaseUrl}$url';

  /// Kiểm tra / xin quyền lưu ảnh vào thư viện máy; trả false nếu bị từ chối.
  Future<bool> ensureGalleryAccess() async {
    if (await Gal.hasAccess()) return true;
    return Gal.requestAccess();
  }

  /// Tải 1 ảnh về và lưu vào album "GasManager" trong thư viện ảnh của máy.
  Future<void> saveToGallery(AnhItemModel item) async {
    final res = await _staticDio.get<List<int>>(fullUrl(item.url));
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) throw Exception('Ảnh rỗng');
    final ext = item.url.contains('.') ? item.url.split('.').last : 'jpg';
    final name = '${item.loai}_${item.ngay.millisecondsSinceEpoch}_${item.key.split(':').last}.$ext';
    await Gal.putImageBytes(Uint8List.fromList(bytes), album: 'GasManager', name: name);
  }
}
