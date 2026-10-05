// lib/core/providers/sync_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

/// Điều phối việc làm mới cache danh mục (app chỉ chạy online, không còn upload offline).
class SyncNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  SyncNotifier() : super(const AsyncValue.data(null));

  /// Kéo lại toàn bộ danh mục từ server về cache SQLite, cập nhật state tiến trình.
  Future<SyncResult> syncCatalog() async {
    state = const AsyncValue.loading();
    try {
      final result = await SyncService.instance.syncCatalog();
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, AsyncValue<SyncResult?>>(
  (ref) => SyncNotifier(),
);
