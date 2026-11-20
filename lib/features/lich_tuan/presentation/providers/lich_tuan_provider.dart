// lib/features/lich_tuan/presentation/providers/lich_tuan_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/lich_tuan_remote_datasource.dart';
import '../../domain/entities/lich_tuan_entity.dart';

final lichTuanDatasourceProvider = Provider<LichTuanRemoteDatasource>(
  (ref) => LichTuanRemoteDatasource(),
);

/// Trả khoảng Thứ 2 → Chủ nhật của tuần chứa ngày [d]
DateTimeRange weekOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final start = day.subtract(Duration(days: day.weekday - 1));
  return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
}

/// Khoảng ngày đang xem — dùng chung cho mọi tab, mặc định tuần hiện tại
final lichTuanRangeProvider = StateProvider.autoDispose<DateTimeRange>(
  (ref) => weekOf(DateTime.now()),
);

/// Danh sách lịch theo loại (mỗi tab cache riêng), sắp theo giờ bắt đầu
final lichTuanProvider = FutureProvider.autoDispose
    .family<List<LichTuanEntity>, LichTuanLoai>((ref, loai) async {
  final range = ref.watch(lichTuanRangeProvider);
  final models = await ref.read(lichTuanDatasourceProvider).fetchLichTuan(
        start: range.start,
        end: range.end,
        loai: loai,
      );
  return models.map((m) => m.toEntity()).toList()
    ..sort((a, b) => a.ngayGioBDBase.compareTo(b.ngayGioBDBase));
});

/// Gom nhóm lịch theo ngày để hiển thị header từng ngày
final lichTuanGroupedProvider = Provider.autoDispose
    .family<AsyncValue<Map<DateTime, List<LichTuanEntity>>>, LichTuanLoai>(
        (ref, loai) {
  return ref.watch(lichTuanProvider(loai)).whenData((list) {
    final map = <DateTime, List<LichTuanEntity>>{};
    for (final item in list) {
      final d = item.ngayGioBDBase;
      map.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(item);
    }
    return map;
  });
});
