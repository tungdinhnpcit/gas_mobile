// lib/features/vi_tri/data/repositories/vi_tri_repository.dart
import '../../../../core/network/api_client.dart';
import '../models/vi_tri_chia_se_model.dart';

class ViTriRepository {
  /// Gửi vị trí hiện tại của máy lên server.
  Future<void> capNhat({
    required String deviceId,
    String? deviceInfo,
    required double lat,
    required double lng,
    double? doChinhXac,
    double? tocDo,
  }) =>
      ApiClient.instance.dio.post('/api/vi-tri/cap-nhat', data: {
        'deviceId': deviceId,
        'deviceInfo': deviceInfo,
        'lat': lat,
        'lng': lng,
        'doChinhXac': doChinhXac,
        'tocDo': tocDo,
      });

  /// Báo server máy này đã tắt chia sẻ.
  Future<void> tat(String deviceId) => ApiClient.instance.dio.post('/api/vi-tri/tat', data: {'deviceId': deviceId});

  /// Danh sách điện thoại đang chia sẻ vị trí.
  Future<List<ViTriChiaSeModel>> getList() async {
    final res = await ApiClient.instance.dio.get('/api/vi-tri');
    return (res.data as List).map((e) => ViTriChiaSeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Vị trí chi tiết của 1 điện thoại.
  Future<ViTriChiaSeModel> getById(int id) async {
    final res = await ApiClient.instance.dio.get('/api/vi-tri/$id');
    return ViTriChiaSeModel.fromJson(res.data as Map<String, dynamic>);
  }
}
