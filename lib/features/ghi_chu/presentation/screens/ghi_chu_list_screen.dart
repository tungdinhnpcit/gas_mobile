// lib/features/ghi_chu/presentation/screens/ghi_chu_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/ghi_chu_model.dart';
import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../providers/ghi_chu_provider.dart';
import '../widgets/phan_loai_dialogs.dart';

/// Màn danh sách "Ghi chú bảo mật" — lọc theo phân loại (chip), tìm kiếm tiếng Việt không dấu
/// theo tiêu đề/tài khoản/ghi chú. Không hiển thị mật khẩu trong danh sách.
class GhiChuListScreen extends ConsumerStatefulWidget {
  const GhiChuListScreen({super.key});

  @override
  ConsumerState<GhiChuListScreen> createState() => _GhiChuListScreenState();
}

class _GhiChuListScreenState extends ConsumerState<GhiChuListScreen> {
  final _searchCtrl = TextEditingController();
  String _filterQuery = '';
  Timer? _debounce;
  int? _phanLoaiId; // null = tất cả

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ghiChuListProvider.notifier).load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      setState(() => _filterQuery = removeDiacritics(value.trim()));
    });
  }

  List<GhiChuModel> _applyFilter(List<GhiChuModel> allItems) {
    if (_filterQuery.isEmpty) return allItems;
    return allItems.where((g) {
      final t = removeDiacritics(g.tieuDe);
      final a = removeDiacritics(g.taiKhoan);
      final c = removeDiacritics(g.ghiChu);
      return t.contains(_filterQuery) ||
          a.contains(_filterQuery) ||
          c.contains(_filterQuery);
    }).toList();
  }

  /// Chọn chip phân loại → tải lại danh sách theo phân loại.
  void _selectPhanLoai(int? id) {
    setState(() => _phanLoaiId = id);
    ref.read(ghiChuListProvider.notifier).setFilter(id);
  }

  /// Mở form thêm/sửa; khi quay về thì reload danh sách và số đếm phân loại.
  Future<void> _openForm([GhiChuModel? item]) async {
    await context.push(AppRoutes.ghiChuForm, extra: item);
    if (mounted) {
      await ref.read(ghiChuListProvider.notifier).load();
      ref.read(ghiChuPhanLoaiProvider.notifier).load();
    }
  }

  /// Mở bottom sheet quản lý phân loại; nếu phân loại đang lọc bị xoá thì về "Tất cả".
  Future<void> _quanLyPhanLoai() async {
    await showQuanLyPhanLoaiSheet(context);
    if (!mounted) return;
    final ds = ref.read(ghiChuPhanLoaiProvider).valueOrNull ?? const <GhiChuPhanLoaiModel>[];
    if (_phanLoaiId != null && !ds.any((p) => p.id == _phanLoaiId)) {
      _selectPhanLoai(null);
    } else {
      ref.read(ghiChuListProvider.notifier).load();
    }
  }

  Widget _buildChips(List<GhiChuPhanLoaiModel> phanLoais) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: _phanLoaiId == null,
              onSelected: (_) => _selectPhanLoai(null),
            ),
          ),
          for (final p in phanLoais)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: p.color),
                label: Text('${p.ten} (${p.soGhiChu})'),
                selected: _phanLoaiId == p.id,
                selectedColor: p.color.withValues(alpha: 0.2),
                onSelected: (_) => _selectPhanLoai(p.id),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: const Text('Phân loại'),
            onPressed: _quanLyPhanLoai,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ghiChuListProvider);
    final phanLoais = ref.watch(ghiChuPhanLoaiProvider).valueOrNull ?? const <GhiChuPhanLoaiModel>[];

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm theo tiêu đề, tài khoản, ghi chú...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
          ),
          _buildChips(phanLoais),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
              data: (allItems) {
                final items = _applyFilter(allItems);
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Chưa có ghi chú nào'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(ghiChuListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _buildItem(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm ghi chú'),
      ),
    );
  }

  /// Card 1 ghi chú: icon màu phân loại, tiêu đề, tài khoản, badge phân loại + số ảnh.
  Widget _buildItem(GhiChuModel item) {
    final color = item.phanLoaiId != null ? phanLoaiColor(item.mauPhanLoai) : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color?.withValues(alpha: 0.15),
          child: Icon(Icons.sticky_note_2_outlined, color: color),
        ),
        title: Text(
          item.tieuDe,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.taiKhoan.isNotEmpty) Text(item.taiKhoan),
            if (item.tenPhanLoai != null || item.anh.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (item.tenPhanLoai != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color!.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(item.tenPhanLoai!, style: TextStyle(fontSize: 12, color: color)),
                      ),
                    if (item.anh.isNotEmpty) ...[
                      const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                      Text('${item.anh.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openForm(item),
      ),
    );
  }
}
