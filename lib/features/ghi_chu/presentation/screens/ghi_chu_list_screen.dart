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
import '../widgets/chia_se_sheet.dart';
import '../widgets/phan_loai_dialogs.dart' show ghiChuErrorMessage;

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
  bool _tabChiaSe = false;         // false = "Của tôi", true = "Được chia sẻ"
  final Set<int> _selected = {};   // id ghi chú đang chọn (chế độ chọn nhiều)
  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelect(GhiChuModel item) => setState(() {
        if (!_selected.remove(item.id!)) _selected.add(item.id!);
      });

  /// Chia sẻ các ghi chú đang chọn; thành công thì thoát chế độ chọn.
  Future<void> _chiaSeDaChon() async {
    final ok = await showChiaSeNhieuSheet(context, _selected.toList());
    if (ok && mounted) setState(_selected.clear);
  }

  /// Xác nhận rồi xoá 1 ghi chú từ menu popup của dòng.
  Future<void> _xoa(GhiChuModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú'),
        content: Text('Bạn có chắc muốn xoá "${item.tieuDe}"? Ảnh đính kèm cũng bị xoá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ghiChuListProvider.notifier).remove(item.id!);
      ref.read(ghiChuPhanLoaiProvider.notifier).load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ghiChuErrorMessage(e))));
    }
  }

  /// Mở xem ghi chú được chia sẻ (chỉ xem); quay về thì tải lại tab chia sẻ.
  Future<void> _openShared(GhiChuModel item) async {
    await context.push(AppRoutes.ghiChuForm, extra: item);
    if (mounted) ref.invalidate(ghiChuDuocChiaSeProvider);
  }

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

  /// Mở màn danh mục loại ghi chú; chọn 1 loại ở đó → lọc theo loại; loại đang lọc bị xoá → về "Tất cả".
  Future<void> _quanLyPhanLoai() async {
    final chon = await context.push<int>(AppRoutes.ghiChuPhanLoai);
    if (!mounted) return;
    final ds = ref.read(ghiChuPhanLoaiProvider).valueOrNull ?? const <GhiChuPhanLoaiModel>[];
    if (chon != null) {
      _selectPhanLoai(chon);
    } else if (_phanLoaiId != null && !ds.any((p) => p.id == _phanLoaiId)) {
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

    return PopScope(
      // Đang chọn nhiều → back/swipe chỉ thoát chế độ chọn
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Của tôi'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: true, label: Text('Được chia sẻ'), icon: Icon(Icons.people_outline)),
                ],
                selected: {_tabChiaSe},
                onSelectionChanged: (s) => setState(() {
                  _tabChiaSe = s.first;
                  _selected.clear();
                  if (_tabChiaSe) ref.invalidate(ghiChuDuocChiaSeProvider);
                }),
              ),
            ),
          ),
          if (_selecting)
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close), tooltip: 'Huỷ chọn', onPressed: () => setState(_selected.clear)),
                Expanded(child: Text('Đã chọn ${_selected.length}', style: const TextStyle(fontWeight: FontWeight.bold))),
                TextButton(
                  onPressed: () => setState(() => _selected.addAll(
                      _applyFilter(state.valueOrNull ?? const []).map((e) => e.id!))),
                  child: const Text('Chọn tất cả'),
                ),
              ]),
            ),
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
          if (!_tabChiaSe) _buildChips(phanLoais),
          Expanded(
            child: _tabChiaSe ? _buildSharedList() : state.when(
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
      floatingActionButton: _tabChiaSe
          ? null
          : _selecting
              ? FloatingActionButton.extended(
                  onPressed: _chiaSeDaChon,
                  icon: const Icon(Icons.share_outlined),
                  label: Text('Chia sẻ (${_selected.length})'),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm ghi chú'),
                ),
      ),
    );
  }

  /// Tab "Được chia sẻ": danh sách ghi chú người khác chia sẻ (chỉ xem), có tìm kiếm.
  Widget _buildSharedList() {
    final async = ref.watch(ghiChuDuocChiaSeProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      data: (all) {
        final items = _applyFilter(all);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(ghiChuDuocChiaSeProvider.future),
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Chưa có ghi chú nào được chia sẻ cho bạn')),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.people_outline)),
                        title: Text(item.tieuDe, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.taiKhoan.isNotEmpty) Text(item.taiKhoan),
                            Text('Từ: ${item.tenChuSoHuu ?? ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openShared(item),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  /// Card 1 ghi chú: icon màu phân loại, tiêu đề, tài khoản, badge phân loại + số ảnh.
  Widget _buildItem(GhiChuModel item) {
    final color = item.phanLoaiId != null ? phanLoaiColor(item.mauPhanLoai) : null;
    final checked = _selected.contains(item.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: checked ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
      child: ListTile(
        onLongPress: () => _toggleSelect(item),
        leading: _selecting
            ? Checkbox(value: checked, onChanged: (_) => _toggleSelect(item))
            : CircleAvatar(
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
        trailing: _selecting
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'share':
                      showChiaSeSheet(context, item.id!, item.tieuDe);
                    case 'edit':
                      _openForm(item);
                    case 'select':
                      _toggleSelect(item);
                    case 'delete':
                      _xoa(item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: ListTile(
                      leading: Icon(Icons.share_outlined), title: Text('Chia sẻ'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'edit', child: ListTile(
                      leading: Icon(Icons.edit_outlined), title: Text('Sửa'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'select', child: ListTile(
                      leading: Icon(Icons.checklist), title: Text('Chọn nhiều'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'delete', child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Xoá', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
                ],
              ),
        onTap: () => _selecting ? _toggleSelect(item) : _openForm(item),
      ),
    );
  }
}
