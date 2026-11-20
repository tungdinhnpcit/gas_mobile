// lib/features/thu_vien_anh/presentation/screens/thu_vien_anh_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/thu_vien_anh_model.dart';
import '../../data/thu_vien_anh_repository.dart';
import '../providers/thu_vien_anh_provider.dart';

/// Thư viện ảnh (route trong ShellRoute → không tự có Scaffold/AppBar).
/// Lọc theo ngày/tên/loại, chạm giữ để chọn nhiều, lưu ảnh đã chọn hoặc tất cả vào thư viện ảnh của máy.
class ThuVienAnhScreen extends ConsumerStatefulWidget {
  const ThuVienAnhScreen({super.key});

  @override
  ConsumerState<ThuVienAnhScreen> createState() => _ThuVienAnhScreenState();
}

class _ThuVienAnhScreenState extends ConsumerState<ThuVienAnhScreen> {
  static const _maxTaiTatCa = 200;
  static const _loaiOptions = <(String?, String)>[
    (null, 'Tất cả'),
    ('giao-hang', 'Giao hàng'),
    ('xac-nhan', 'Xác nhận KH'),
    ('ban-ke', 'Bản kê'),
    ('lo-trinh', 'Lộ trình'),
    ('ghi-chu', 'Ghi chú'),
  ];

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  final Map<String, AnhItemModel> _selected = {};
  bool _saving = false;
  int _savedCount = 0;
  int _totalToSave = 0;

  bool get _selectMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 400) {
        ref.read(thuVienAnhProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Mở hộp chọn khoảng ngày, đổi bộ lọc và bỏ chọn ảnh cũ.
  Future<void> _pickRange(ThuVienAnhState s) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: s.tuNgay, end: s.denNgay),
    );
    if (r == null) return;
    setState(_selected.clear);
    ref.read(thuVienAnhProvider.notifier).setDateRange(r.start, r.end);
  }

  /// Chọn / bỏ chọn 1 ảnh.
  void _toggle(AnhItemModel it) => setState(() {
        if (_selected.remove(it.key) == null) _selected[it.key] = it;
      });

  /// Lưu danh sách ảnh vào thư viện ảnh của máy, hiển thị tiến trình x/n.
  Future<void> _saveList(List<AnhItemModel> list) async {
    if (list.isEmpty) return;
    final repo = ref.read(thuVienAnhRepositoryProvider);
    if (!await repo.ensureGalleryAccess()) {
      _snack('Chưa được cấp quyền lưu ảnh vào thư viện');
      return;
    }
    setState(() {
      _saving = true;
      _savedCount = 0;
      _totalToSave = list.length;
    });
    var loi = 0;
    for (final it in list) {
      if (!mounted) return;
      try {
        await repo.saveToGallery(it);
      } catch (e) {
        loi++;
        debugPrint('[THU_VIEN_ANH] Lỗi lưu ${it.key}: $e');
      }
      if (mounted) setState(() => _savedCount++);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _selected.clear();
    });
    _snack(loi == 0
        ? 'Đã lưu ${list.length} ảnh vào thư viện ảnh (album GasManager)'
        : 'Đã lưu ${list.length - loi}/${list.length} ảnh, $loi ảnh lỗi');
  }

  /// "Tải tất cả" (quản trị): lấy toàn bộ ảnh theo bộ lọc, giới hạn 200 ảnh/lần trên điện thoại.
  Future<void> _saveAll(ThuVienAnhState s) async {
    final soLuong = s.totalCount > _maxTaiTatCa ? _maxTaiTatCa : s.totalCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tải tất cả ảnh'),
        content: Text(s.totalCount > _maxTaiTatCa
            ? 'Có ${s.totalCount} ảnh khớp bộ lọc. Điện thoại chỉ tải tối đa $_maxTaiTatCa ảnh mới nhất mỗi lần — '
                'hãy thu hẹp khoảng ngày hoặc dùng web để tải toàn bộ (ZIP).'
            : 'Lưu $soLuong ảnh vào thư viện ảnh của máy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Tải $soLuong ảnh')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final list = await ref.read(thuVienAnhProvider.notifier).fetchAll(limit: _maxTaiTatCa);
      await _saveList(list);
    } catch (_) {
      _snack('Không lấy được danh sách ảnh');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Xem ảnh phóng to, có nút lưu ảnh đang xem.
  void _xemAnh(AnhItemModel it) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: ThuVienAnhRepository.fullUrl(it.url),
                    placeholder: (_, __) => const CircularProgressIndicator(),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.tieuDe,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text(_fmtDateTime(it.ngay), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Lưu ảnh',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveList([it]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(thuVienAnhProvider);
    final notifier = ref.read(thuVienAnhProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Bộ lọc
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Mã chuyến, biển số, khách hàng...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      setState(_selected.clear);
                      notifier.setSearch(v.trim());
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text('${_fmtDate(s.tuNgay).substring(0, 5)} - ${_fmtDate(s.denNgay).substring(0, 5)}'),
                onPressed: () => _pickRange(s),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final (code, label) in _loaiOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label),
                    selected: s.loai == code,
                    onSelected: (_) {
                      setState(_selected.clear);
                      notifier.setLoai(code);
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                _selectMode ? 'Đã chọn ${_selected.length}' : '${s.totalCount} ảnh',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              if (_selectMode) ...[
                TextButton(
                  onPressed: () => setState(() {
                    for (final it in s.items) {
                      _selected[it.key] = it;
                    }
                  }),
                  child: const Text('Chọn hết'),
                ),
                TextButton(onPressed: () => setState(_selected.clear), child: const Text('Bỏ chọn')),
              ] else
                Text('Chạm giữ để chọn', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
        // Lưới ảnh
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.reload,
            child: s.loading
                ? const Center(child: CircularProgressIndicator())
                : s.error != null
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(child: Text(s.error!)),
                        Center(child: TextButton(onPressed: notifier.reload, child: const Text('Thử lại'))),
                      ])
                    : s.items.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Không có ảnh nào khớp bộ lọc')),
                          ])
                        : GridView.builder(
                            controller: _scrollCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.78,
                            ),
                            itemCount: s.items.length + (s.loadingMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= s.items.length) {
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              }
                              return _buildTile(s.items[i], theme);
                            },
                          ),
          ),
        ),
        // Thanh hành động
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
            ),
            child: _saving
                ? Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('Đang lưu $_savedCount/$_totalToSave ảnh...'),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text('Tải đã chọn (${_selected.length})'),
                          onPressed: _selectMode ? () => _saveList(_selected.values.toList()) : null,
                        ),
                      ),
                      if (s.isQuanTri) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download_for_offline_outlined),
                            label: Text('Tải tất cả (${s.totalCount})'),
                            onPressed: s.totalCount == 0 ? null : () => _saveAll(s),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// 1 ô ảnh: thumbnail + badge loại + tiêu đề/ngày; chạm = xem (hoặc chọn khi đang ở chế độ chọn), chạm giữ = chọn.
  Widget _buildTile(AnhItemModel it, ThemeData theme) {
    final checked = _selected.containsKey(it.key);
    return GestureDetector(
      onTap: () => _selectMode ? _toggle(it) : _xemAnh(it),
      onLongPress: () => _toggle(it),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: checked ? theme.colorScheme.primary : Colors.black12, width: checked ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: ThuVienAnhRepository.fullUrl(it.url),
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(it.loaiLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
                  if (_selectMode)
                    Positioned(
                      top: 2, left: 2,
                      child: Icon(
                        checked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: checked ? theme.colorScheme.primary : Colors.white,
                        shadows: const [Shadow(blurRadius: 3)],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.tieuDe, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(_fmtDateTime(it.ngay), maxLines: 1,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
