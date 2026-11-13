// lib/features/lo_trinh/presentation/providers/lo_trinh_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lo_trinh_model.dart';
import '../../data/repositories/lo_trinh_repository.dart';

final loTrinhRepositoryProvider = Provider((_) => LoTrinhRepository());

/// Bộ lọc khoảng ngày cho danh sách lộ trình (mặc định 7 ngày gần nhất).
final loTrinhFilterProvider = StateProvider.autoDispose<({DateTime tuNgay, DateTime denNgay})>((ref) {
  final now = DateTime.now();
  return (tuNgay: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), denNgay: now);
});

/// Danh sách lộ trình theo bộ lọc.
final loTrinhListProvider = FutureProvider.autoDispose<List<LoTrinhModel>>((ref) {
  final f = ref.watch(loTrinhFilterProvider);
  return ref.read(loTrinhRepositoryProvider).getList(tuNgay: f.tuNgay, denNgay: f.denNgay);
});

/// Chi tiết lộ trình kèm điểm.
final loTrinhDetailProvider = FutureProvider.autoDispose.family<LoTrinhModel, int>(
  (ref, id) => ref.read(loTrinhRepositoryProvider).getById(id),
);
