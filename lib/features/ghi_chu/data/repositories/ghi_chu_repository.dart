// lib/features/ghi_chu/data/repositories/ghi_chu_repository.dart
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_compress.dart';
import '../models/ghi_chu_model.dart';

/// Gọi API backend cho ghi chú bảo mật — mã hoá mật khẩu thực hiện ở server,
/// client chỉ gửi/nhận plaintext qua HTTPS.
class GhiChuRepository {
  /// Lấy toàn bộ ghi chú của user, lọc tuỳ chọn theo phân loại.
  Future<List<GhiChuModel>> getAll({int? phanLoaiId}) async {
    final res = await ApiClient.instance.dio.get(
      '/api/ghi-chu-bao-mat',
      queryParameters: {if (phanLoaiId != null) 'phanLoaiId': phanLoaiId},
    );
    return (res.data as List)
        .map((e) => GhiChuModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tạo mới (id == null) hoặc cập nhật ghi chú, trả về bản ghi server đã lưu.
  Future<GhiChuModel> save(GhiChuModel m) async {
    final data = {
      'tieuDe': m.tieuDe.trim(),
      'taiKhoan': m.taiKhoan.trim(),
      'matKhau': m.matKhau,
      'ghiChu': m.ghiChu.trim(),
      'phanLoaiId': m.phanLoaiId,
    };
    final res = m.id == null
        ? await ApiClient.instance.dio.post('/api/ghi-chu-bao-mat', data: data)
        : await ApiClient.instance.dio.put('/api/ghi-chu-bao-mat/${m.id}', data: data);
    return GhiChuModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xoá ghi chú (server xoá luôn ảnh đính kèm).
  Future<void> delete(int id) =>
      ApiClient.instance.dio.post('/api/ghi-chu-bao-mat/$id/delete');

  /// Upload 1 ảnh đính kèm (tự nén ≤ 1MB trước khi gửi).
  Future<GhiChuAnhModel> uploadAnh(int id, XFile photo) async {
    final compressed = await compressImageUnder(photo);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        compressed.path,
        filename: compressed.name,
        contentType: DioMediaType('image', compressed.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg'),
      ),
    });
    final res = await ApiClient.instance.dio.post('/api/ghi-chu-bao-mat/$id/anh', data: formData);
    return GhiChuAnhModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xoá 1 ảnh đính kèm.
  Future<void> deleteAnh(int id, int anhId) =>
      ApiClient.instance.dio.post('/api/ghi-chu-bao-mat/$id/anh/$anhId/delete');
}
