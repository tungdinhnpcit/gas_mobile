// lib/features/ghi_chu/presentation/screens/gan_ghi_chu_phan_loai_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/ghi_chu_model.dart';
import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../providers/ghi_chu_provider.dart';
import '../widgets/phan_loai_dialogs.dart';

/// Màn gán ghi chú cho 1 loại: liệt kê toàn bộ ghi chú có checkbox (tick = thuộc loại này),
/// ô nhập + nút "Lọc" để lọc theo tên (tiêu đề, không dấu), nút Lưu gán/gỡ hàng loạt.
/// Route ở root navigator → tự vẽ Scaffold + AppBar.
class GanGhiChuPhanLoaiScreen extends ConsumerStatefulWidget {
  final GhiChuPhanLoaiModel loai;

  const GanGhiChuPhanLoaiScreen({super.key, required this.loai});

  @override
  ConsumerState<GanGhiChuPhanLoaiScreen> createState() => _GanGhiChuPhanLoaiScreenState();
}

class _GanGhiChuPhanLoaiScreenState extends ConsumerState<GanGhiChuPhanLoaiScreen> {
  final _filterCtrl = TextEditingController();

  List<GhiChuModel> _all = [];
  Set<int> _initial = {};   // các ghi chú thuộc loại lúc mở màn (để biết có thay đổi)
  Set<int> _selected = {};
  String _query = '';       // từ khoá đã áp dụng (không dấu)
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _changed =>
      _selected.length != _initial.length || !_selected.containsAll(_initial);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  /// Tải toàn bộ ghi chú của user, tick sẵn các ghi chú đang thuộc loại này.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(ghiChuRepositoryProvider).getAll();
      final init = list.where((g) => g.phanLoaiId == widget.loai.id).map((g) => g.id!).toSet();
      if (!mounted) return;
      setState(() {
        _all = list;
        _initial = init;
        _selected = {...init};
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ghiChuErrorMessage(e);
        });
      }
    }
  }

  /// Nút "Lọc": áp dụng từ khoá trong ô nhập (lọc theo tiêu đề, không dấu). Lựa chọn tick được giữ nguyên.
  void _applyFilter() {
    FocusScope.of(context).unfocus();
    setState(() => _query = removeDiacritics(_filterCtrl.text.trim()));
  }

  void _clearFilter() {
    _filterCtrl.clear();
    setState(() => _query = '');
  }

  List<GhiChuModel> get _visible => _query.isEmpty
      ? _all
      : _all.where((g) => removeDiacritics(g.tieuDe).contains(_query)).toList();

  /// Chọn tất cả / bỏ chọn các dòng đang hiển thị (sau lọc).
  void _toggleAllVisible(bool select) {
    final ids = _visible.map((g) => g.id!);
    setState(() => select ? _selected.addAll(ids) : _selected.removeAll(ids));
  }

  /// Lưu: gửi danh sách id đã tick lên server, reload số đếm phân loại rồi quay lại.
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(ghiChuPhanLoaiRepositoryProvider).ganGhiChu(widget.loai.id, _selected.toList());
      await ref.read(ghiChuPhanLoaiProvider.notifier).load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu ${_selected.length} ghi chú cho "${widget.loai.ten}"')),
      );
      _popAfterCommit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ghiChuErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Hỏi xác nhận khi rời màn mà chưa lưu.
  Future<bool> _confirmDiscard() async {
    if (!_changed) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa lưu thay đổi'),
        content: const Text('Bỏ các thay đổi đã chọn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ thay đổi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Rời màn an toàn: đánh dấu "không còn thay đổi" để PopScope dựng lại với canPop = true,
  /// rồi mới pop ở frame kế tiếp (pop ngay sẽ bị PopScope cũ chặn → gọi callback lặp vô hạn).
  void _popAfterCommit() {
    setState(() => _initial = {..._selected});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _back() async {
    if (await _confirmDiscard() && mounted) _popAfterCommit();
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _filterCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyFilter(),
              onChanged: (_) => setState(() {}), // cập nhật nút ✕
              decoration: InputDecoration(
                hintText: 'Nhập tên ghi chú...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterCtrl.text.isEmpty && _query.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: _clearFilter),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _applyFilter,
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: const Text('Lọc'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ]),
      );
    }
    if (_all.isEmpty) return const Center(child: Text('Chưa có ghi chú nào'));

    final visible = _visible;
    final allVisibleSelected = visible.isNotEmpty && visible.every((g) => _selected.contains(g.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Đã chọn ${_selected.length} / ${_all.length}'
                  '${_query.isNotEmpty ? ' · đang hiển thị ${visible.length}' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (visible.isNotEmpty)
                TextButton(
                  onPressed: () => _toggleAllVisible(!allVisibleSelected),
                  child: Text(allVisibleSelected ? 'Bỏ chọn' : 'Chọn tất cả'),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Không có ghi chú nào khớp tên đã lọc'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final g = visible[i];
                    final khacLoai = g.phanLoaiId != null && g.phanLoaiId != widget.loai.id;
                    return CheckboxListTile(
                      value: _selected.contains(g.id),
                      onChanged: (v) => setState(() => v == true ? _selected.add(g.id!) : _selected.remove(g.id)),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(g.tieuDe, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: (g.taiKhoan.isEmpty && !khacLoai)
                          ? null
                          : Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (g.taiKhoan.isNotEmpty) Text(g.taiKhoan),
                                // Đang thuộc loại khác: tick sẽ chuyển ghi chú sang loại này
                                if (khacLoai)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: phanLoaiColor(g.mauPhanLoai).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      g.tenPhanLoai ?? '',
                                      style: TextStyle(fontSize: 12, color: phanLoaiColor(g.mauPhanLoai)),
                                    ),
                                  ),
                              ],
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmDiscard() && mounted) _popAfterCommit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Row(children: [
            CircleAvatar(radius: 7, backgroundColor: widget.loai.color),
            const SizedBox(width: 8),
            Expanded(child: Text('Gán ghi chú: ${widget.loai.ten}', overflow: TextOverflow.ellipsis)),
          ]),
        ),
        body: Column(
          children: [
            _buildFilterRow(),
            Expanded(child: _buildList()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: (_changed && !_saving && !_loading) ? _save : null,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_changed ? 'Lưu (${_selected.length} ghi chú)' : 'Chưa có thay đổi'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
