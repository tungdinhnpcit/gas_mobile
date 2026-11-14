// lib/features/ghi_chu/presentation/providers/ghi_chu_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ghi_chu_model.dart';
import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../../data/repositories/ghi_chu_phan_loai_repository.dart';
import '../../data/repositories/ghi_chu_repository.dart';

final ghiChuRepositoryProvider =
    Provider<GhiChuRepository>((_) => GhiChuRepository());

final ghiChuPhanLoaiRepositoryProvider =
    Provider<GhiChuPhanLoaiRepository>((_) => GhiChuPhanLoaiRepository());

/// Danh sách ghi chú, giữ bộ lọc phân loại hiện tại ([phanLoaiId] null = tất cả).
class GhiChuListNotifier extends StateNotifier<AsyncValue<List<GhiChuModel>>> {
  final GhiChuRepository _repo;
  GhiChuListNotifier(this._repo) : super(const AsyncValue.data([]));

  int? phanLoaiId;

  /// Tải lại danh sách theo bộ lọc hiện tại.
  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll(phanLoaiId: phanLoaiId));
  }

  /// Đổi bộ lọc phân loại và tải lại.
  Future<void> setFilter(int? id) async {
    phanLoaiId = id;
    await load();
  }

  /// Lưu ghi chú, trả về bản ghi server (màn danh sách tự reload khi quay lại).
  Future<GhiChuModel> save(GhiChuModel m) => _repo.save(m);

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await load();
  }
}

final ghiChuListProvider = StateNotifierProvider.autoDispose<GhiChuListNotifier,
    AsyncValue<List<GhiChuModel>>>(
  (ref) => GhiChuListNotifier(ref.watch(ghiChuRepositoryProvider)),
);

/// Danh sách phân loại của user (dùng cho filter chip ở list và dropdown ở form).
class GhiChuPhanLoaiNotifier extends StateNotifier<AsyncValue<List<GhiChuPhanLoaiModel>>> {
  final GhiChuPhanLoaiRepository _repo;
  GhiChuPhanLoaiNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(_repo.getAll);
  }

  /// Tạo/sửa phân loại rồi tải lại danh sách.
  Future<GhiChuPhanLoaiModel> save({int? id, required String ten, String? mau}) async {
    final r = await _repo.save(id: id, ten: ten, mau: mau);
    await load();
    return r;
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await load();
  }

  /// Kéo thả đổi thứ tự: cập nhật UI ngay (optimistic), gửi API; lỗi thì tải lại từ server và ném lỗi ra.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...?state.valueOrNull];
    // newIndex đã được onReorderItem điều chỉnh sẵn (vị trí sau khi gỡ phần tử cũ)
    if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = AsyncValue.data(list);
    try {
      await _repo.sapXep(list.map((e) => e.id).toList());
    } catch (_) {
      await load();
      rethrow;
    }
  }
}

final ghiChuPhanLoaiProvider = StateNotifierProvider.autoDispose<GhiChuPhanLoaiNotifier,
    AsyncValue<List<GhiChuPhanLoaiModel>>>(
  (ref) => GhiChuPhanLoaiNotifier(ref.watch(ghiChuPhanLoaiRepositoryProvider)),
);
