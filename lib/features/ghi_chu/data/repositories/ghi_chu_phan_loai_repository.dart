// lib/features/ghi_chu/data/repositories/ghi_chu_phan_loai_repository.dart
import '../../../../core/network/api_client.dart';
import '../models/ghi_chu_phan_loai_model.dart';

/// CRUD phân loại ghi chú của user hiện tại.
class GhiChuPhanLoaiRepository {
  /// Lấy toàn bộ phân loại của user (kèm số ghi chú mỗi loại).
  Future<List<GhiChuPhanLoaiModel>> getAll() async {
    final res = await ApiClient.instance.dio.get('/api/ghi-chu-phan-loai');
    return (res.data as List)
        .map((e) => GhiChuPhanLoaiModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tạo (id == null) hoặc cập nhật phân loại, trả về bản ghi đã lưu.
  Future<GhiChuPhanLoaiModel> save({int? id, required String ten, String? mau}) async {
    final data = {'ten': ten.trim(), 'mau': mau};
    final res = id == null
        ? await ApiClient.instance.dio.post('/api/ghi-chu-phan-loai', data: data)
        : await ApiClient.instance.dio.put('/api/ghi-chu-phan-loai/$id', data: data);
    return GhiChuPhanLoaiModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Xoá phân loại — ghi chú thuộc loại này chuyển về "không phân loại".
  Future<void> delete(int id) =>
      ApiClient.instance.dio.post('/api/ghi-chu-phan-loai/$id/delete');
}
