// lib/features/lo_trinh/data/repositories/lo_trinh_repository.dart
import '../../../../core/network/api_client.dart';
import '../models/lo_trinh_model.dart';

class LoTrinhRepository {
  /// Bắt đầu lộ trình mới (server trả lộ trình đang ghi nếu đã có).
  Future<LoTrinhModel> batDau({String? ten}) async {
    final res = await ApiClient.instance.dio.post('/api/lo-trinh/bat-dau', data: {'ten': ten});
    return LoTrinhModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Đẩy batch điểm GPS, trả về số điểm server đã lưu.
  Future<int> themDiem(int id, List<LoTrinhDiemModel> diem) async {
    final res = await ApiClient.instance.dio.post(
      '/api/lo-trinh/$id/diem',
      data: {'diem': diem.map((e) => e.toJson()).toList()},
    );
    return (res.data as Map)['soDiem'] as int? ?? 0;
  }

  /// Kết thúc lộ trình.
  Future<void> ketThuc(int id) => ApiClient.instance.dio.post('/api/lo-trinh/$id/ket-thuc');

  /// Lộ trình đang ghi của user hiện tại (null nếu không có).
  Future<LoTrinhModel?> getDangGhi() async {
    final res = await ApiClient.instance.dio.get('/api/lo-trinh/dang-ghi');
    if (res.statusCode == 204 || res.data == null || res.data == '') return null;
    return LoTrinhModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Danh sách lộ trình theo khoảng ngày.
  Future<List<LoTrinhModel>> getList({DateTime? tuNgay, DateTime? denNgay}) async {
    final params = <String, dynamic>{};
    if (tuNgay != null) params['tuNgay'] = tuNgay.toIso8601String();
    if (denNgay != null) params['denNgay'] = denNgay.toIso8601String();
    final res = await ApiClient.instance.dio.get('/api/lo-trinh', queryParameters: params);
    return (res.data as List).map((e) => LoTrinhModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Chi tiết lộ trình kèm điểm.
  Future<LoTrinhModel> getById(int id) async {
    final res = await ApiClient.instance.dio.get('/api/lo-trinh/$id');
    return LoTrinhModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Đặt / đổi tên lộ trình (null hoặc rỗng = xoá tên).
  Future<void> doiTen(int id, String? ten) =>
      ApiClient.instance.dio.post('/api/lo-trinh/$id/doi-ten', data: {'ten': ten});

  /// Xoá lộ trình.
  Future<void> delete(int id) => ApiClient.instance.dio.post('/api/lo-trinh/$id/delete');
}
