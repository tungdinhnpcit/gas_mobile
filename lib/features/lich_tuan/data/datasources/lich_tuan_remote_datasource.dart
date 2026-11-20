// lib/features/lich_tuan/data/datasources/lich_tuan_remote_datasource.dart
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/lich_tuan_entity.dart';
import '../models/lich_tuan_model.dart';

class LichTuanRemoteDatasource {
  LichTuanRemoteDatasource()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

  final Dio _dio;
  final _fmt = DateFormat('yyyy-MM-dd');

  /// Lấy lịch theo loại: cá nhân → LichtuanNVJson (nvid); 1–4 → LichtuanJson (loai).
  Future<List<LichTuanModel>> fetchLichTuan({
    required DateTime start,
    required DateTime end,
    required LichTuanLoai loai,
  }) async {
    final isCaNhan = loai == LichTuanLoai.caNhan;
    final response = await _dio.get(
      isCaNhan ? AppConstants.lichTuanApiUrl : AppConstants.lichTuanChungApiUrl,
      queryParameters: {
        'Madviqly': AppConstants.lichTuanMaDviqly,
        'start': _fmt.format(start),
        'end': _fmt.format(end),
        if (isCaNhan) 'nvid': AppConstants.lichTuanNvid else 'loai': loai.code,
        'xacthuc': AppConstants.lichTuanXacThuc,
      },
    );
    final list = (response.data as List<dynamic>?) ?? const [];
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      return loai == LichTuanLoai.xe
          ? LichTuanModel.fromXeJson(json, rangeStart: start)
          : LichTuanModel.fromJson(json);
    }).toList();
  }
}
