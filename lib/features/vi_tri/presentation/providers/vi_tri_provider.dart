// lib/features/vi_tri/presentation/providers/vi_tri_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vi_tri_chia_se_model.dart';
import '../../data/repositories/vi_tri_repository.dart';

final viTriRepositoryProvider = Provider((_) => ViTriRepository());

/// Danh sách điện thoại đang chia sẻ vị trí.
final viTriListProvider = FutureProvider.autoDispose<List<ViTriChiaSeModel>>(
    (ref) => ref.read(viTriRepositoryProvider).getList());

/// Vị trí chi tiết 1 điện thoại theo id.
final viTriDetailProvider = FutureProvider.autoDispose.family<ViTriChiaSeModel, int>(
    (ref, id) => ref.read(viTriRepositoryProvider).getById(id));
