// lib/features/ghi_chu/presentation/screens/ghi_chu_phan_loai_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../providers/ghi_chu_provider.dart';
import '../widgets/phan_loai_dialogs.dart';

/// Màn danh mục "Loại ghi chú": tìm kiếm, thêm/sửa/xoá, kéo thả sắp xếp thứ tự. Có 2 chế độ:
/// - [embedded] = true: chức năng riêng mở từ menu (route trong ShellRoute) → không tự vẽ AppBar
///   (_MainShell lo), bấm vào 1 loại → mở dialog sửa.
/// - [embedded] = false: mở từ chip ở màn ghi chú (root navigator) → tự vẽ AppBar,
///   bấm vào 1 loại → pop trả id để màn ghi chú lọc theo loại đó.
class GhiChuPhanLoaiScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const GhiChuPhanLoaiScreen({super.key, this.embedded = false});

  @override
  ConsumerState<GhiChuPhanLoaiScreen> createState() => _GhiChuPhanLoaiScreenState();
}

class _GhiChuPhanLoaiScreenState extends ConsumerState<GhiChuPhanLoaiScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _sapXep = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Bật/tắt chế độ sắp xếp; khi bật thì xoá từ khoá tìm kiếm (chỉ sắp xếp trên danh sách đầy đủ).
  void _toggleSapXep() {
    setState(() {
      _sapXep = !_sapXep;
      if (_sapXep) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  /// Kéo thả xong → lưu thứ tự mới lên server.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    try {
      await ref.read(ghiChuPhanLoaiProvider.notifier).reorder(oldIndex, newIndex);
    } catch (e) {
      _toast(ghiChuErrorMessage(e));
    }
  }

  List<GhiChuPhanLoaiModel> _filter(List<GhiChuPhanLoaiModel> all) {
    if (_query.isEmpty) return all;
    return all.where((p) => removeDiacritics(p.ten).contains(_query)).toList();
  }

  Widget _buildTile(GhiChuPhanLoaiModel p, int index) {
    return Card(
      key: ValueKey(p.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: p.color.withValues(alpha: 0.15),
          child: Icon(Icons.label_outline, color: p.color),
        ),
        title: Text(p.ten, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${p.soGhiChu} ghi chú'),
        onTap: _sapXep
            ? null
            : widget.embedded
                ? () => context.push(AppRoutes.ganGhiChuPhanLoai, extra: p)
                : () => context.pop(p.id),
        trailing: _sapXep
            ? ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle))
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'sua') {
                    showPhanLoaiEditDialog(context, ref, item: p);
                  } else {
                    confirmXoaPhanLoai(context, ref, p);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'sua', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa'))),
                  PopupMenuItem(
                    value: 'xoa',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Xoá', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ghiChuPhanLoaiProvider);

    final sapXepBtn = IconButton(
      icon: Icon(_sapXep ? Icons.check : Icons.swap_vert),
      tooltip: _sapXep ? 'Xong' : 'Sắp xếp',
      onPressed: _toggleSapXep,
    );

    return Scaffold(
      // Chế độ embedded nằm trong _MainShell → không vẽ AppBar (tránh 2 AppBar chồng nhau)
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Loại ghi chú'),
              leading: BackButton(onPressed: () {
                if (context.canPop()) context.pop();
              }),
              actions: [sapXepBtn],
            ),
      body: Column(
        children: [
          if (!_sapXep)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(children: [
                Expanded(child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = removeDiacritics(v.trim())),
                decoration: InputDecoration(
                  hintText: 'Tìm loại ghi chú...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                )),
                if (widget.embedded) sapXepBtn,
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(children: [
                const Expanded(
                  child: Text('Kéo biểu tượng ≡ để thay đổi thứ tự', style: TextStyle(color: Colors.grey)),
                ),
                if (widget.embedded) sapXepBtn,
              ]),
            ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: ${ghiChuErrorMessage(e)}')),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(child: Text('Chưa có loại ghi chú nào.\nBấm "Thêm loại" để tạo.',
                      textAlign: TextAlign.center));
                }
                if (_sapXep) {
                  return ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: all.length,
                    onReorderItem: _onReorder,
                    itemBuilder: (_, i) => _buildTile(all[i], i),
                  );
                }
                final items = _filter(all);
                return RefreshIndicator(
                  onRefresh: () => ref.read(ghiChuPhanLoaiProvider.notifier).load(),
                  child: items.isEmpty
                      ? ListView(children: const [
                          Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Không tìm thấy'))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _buildTile(items[i], i),
                        ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _sapXep
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPhanLoaiEditDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Thêm loại'),
            ),
    );
  }
}
