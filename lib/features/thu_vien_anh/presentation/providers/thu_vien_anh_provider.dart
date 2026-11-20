// lib/features/thu_vien_anh/presentation/providers/thu_vien_anh_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/thu_vien_anh_model.dart';
import '../../data/thu_vien_anh_repository.dart';

final thuVienAnhRepositoryProvider = Provider((_) => ThuVienAnhRepository());

/// Trạng thái màn hình thư viện ảnh: bộ lọc + danh sách đã tải (phân trang tải thêm).
class ThuVienAnhState {
  final DateTime tuNgay;
  final DateTime denNgay;
  final String search;
  final String? loai; // null = tất cả; giao-hang | xac-nhan | ban-ke | lo-trinh | ghi-chu
  final List<AnhItemModel> items;
  final int totalCount;
  final bool isQuanTri;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const ThuVienAnhState({
    required this.tuNgay,
    required this.denNgay,
    this.search = '',
    this.loai,
    this.items = const [],
    this.totalCount = 0,
    this.isQuanTri = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  bool get hasMore => items.length < totalCount;

  ThuVienAnhState copyWith({
    DateTime? tuNgay,
    DateTime? denNgay,
    String? search,
    String? Function()? loai,
    List<AnhItemModel>? items,
    int? totalCount,
    bool? isQuanTri,
    bool? loading,
    bool? loadingMore,
    String? Function()? error,
  }) =>
      ThuVienAnhState(
        tuNgay: tuNgay ?? this.tuNgay,
        denNgay: denNgay ?? this.denNgay,
        search: search ?? this.search,
        loai: loai != null ? loai() : this.loai,
        items: items ?? this.items,
        totalCount: totalCount ?? this.totalCount,
        isQuanTri: isQuanTri ?? this.isQuanTri,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error != null ? error() : this.error,
      );
}

class ThuVienAnhNotifier extends AutoDisposeNotifier<ThuVienAnhState> {
  static const pageSize = 60;
  int _page = 1;
  int _requestId = 0; // bỏ kết quả cũ khi bộ lọc đổi trong lúc đang tải

  ThuVienAnhRepository get _repo => ref.read(thuVienAnhRepositoryProvider);

  @override
  ThuVienAnhState build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Future.microtask(reload);
    return ThuVienAnhState(tuNgay: today.subtract(const Duration(days: 6)), denNgay: today, loading: true);
  }

  /// Tải lại từ trang 1 theo bộ lọc hiện tại.
  Future<void> reload() async {
    final id = ++_requestId;
    _page = 1;
    state = state.copyWith(loading: true, error: () => null);
    try {
      final res = await _repo.getPage(
        tuNgay: state.tuNgay, denNgay: state.denNgay,
        search: state.search, loai: state.loai, page: 1, pageSize: pageSize,
      );
      if (id != _requestId) return;
      state = state.copyWith(items: res.items, totalCount: res.totalCount, isQuanTri: res.isQuanTri, loading: false);
    } catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: () => 'Không tải được danh sách ảnh');
    }
  }

  /// Tải thêm trang kế tiếp khi cuộn tới cuối.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final id = _requestId;
    state = state.copyWith(loadingMore: true);
    try {
      final res = await _repo.getPage(
        tuNgay: state.tuNgay, denNgay: state.denNgay,
        search: state.search, loai: state.loai, page: _page + 1, pageSize: pageSize,
      );
      if (id != _requestId) return;
      _page++;
      state = state.copyWith(items: [...state.items, ...res.items], totalCount: res.totalCount, loadingMore: false);
    } catch (_) {
      if (id != _requestId) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Lấy toàn bộ ảnh khớp bộ lọc (dùng cho "Tải tất cả" của quản trị), tối đa [limit] ảnh.
  Future<List<AnhItemModel>> fetchAll({int limit = 200}) async {
    final all = <AnhItemModel>[];
    var page = 1;
    while (all.length < limit) {
      final res = await _repo.getPage(
        tuNgay: state.tuNgay, denNgay: state.denNgay,
        search: state.search, loai: state.loai, page: page, pageSize: 200,
      );
      all.addAll(res.items);
      if (res.items.isEmpty || all.length >= res.totalCount) break;
      page++;
    }
    return all.take(limit).toList();
  }

  /// Đổi khoảng ngày rồi tải lại.
  void setDateRange(DateTime tu, DateTime den) {
    state = state.copyWith(tuNgay: tu, denNgay: den);
    reload();
  }

  /// Đổi loại ảnh rồi tải lại.
  void setLoai(String? loai) {
    state = state.copyWith(loai: () => loai);
    reload();
  }

  /// Đổi từ khoá tìm kiếm rồi tải lại.
  void setSearch(String s) {
    if (s == state.search) return;
    state = state.copyWith(search: s);
    reload();
  }
}

final thuVienAnhProvider =
    AutoDisposeNotifierProvider<ThuVienAnhNotifier, ThuVienAnhState>(ThuVienAnhNotifier.new);
