// lib/features/ghi_chu/presentation/widgets/chia_se_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/ghi_chu_model.dart';
import '../providers/ghi_chu_provider.dart';
import 'phan_loai_dialogs.dart' show ghiChuErrorMessage;

/// Autocomplete dropdown chọn tài khoản nhận chia sẻ — dữ liệu từ [ghiChuNguoiDungProvider] (endpoint /nguoi-dung,
/// không phân trang), lọc phía client theo họ tên/username không dấu; bỏ qua các userId trong [excludeIds].
class NguoiDungAutocomplete extends ConsumerStatefulWidget {
  final Set<int> excludeIds;
  final ValueChanged<GhiChuNguoiDungModel> onSelected;

  const NguoiDungAutocomplete({super.key, this.excludeIds = const {}, required this.onSelected});

  @override
  ConsumerState<NguoiDungAutocomplete> createState() => _NguoiDungAutocompleteState();
}

class _NguoiDungAutocompleteState extends ConsumerState<NguoiDungAutocomplete> {
  TextEditingController? _ctrl;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ghiChuNguoiDungProvider);
    final all = async.valueOrNull ?? const <GhiChuNguoiDungModel>[];

    return Autocomplete<GhiChuNguoiDungModel>(
      displayStringForOption: (u) => u.hienThi,
      optionsBuilder: (value) {
        final q = removeDiacritics(value.text.trim());
        return all.where((u) =>
            !widget.excludeIds.contains(u.userId) &&
            (q.isEmpty || removeDiacritics(u.hienThi).contains(q)));
      },
      onSelected: (u) {
        widget.onSelected(u);
        // Xoá ô nhập để chọn tiếp người khác
        WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl?.clear());
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
        _ctrl = ctrl;
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Chọn tài khoản nhận',
            hintText: async.isLoading ? 'Đang tải danh sách...' : 'Gõ tên hoặc username',
            prefixIcon: const Icon(Icons.person_search_outlined),
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: async.hasError ? 'Lỗi tải danh sách tài khoản' : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 240, maxWidth: MediaQuery.of(context).size.width - 32),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final u in options)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(u.fullName?.isNotEmpty == true ? u.fullName! : u.username),
                    subtitle: Text(u.username),
                    onTap: () => onSelect(u),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mở bottom sheet chia sẻ 1 ghi chú: autocomplete thêm người + danh sách người đã chia sẻ (thu hồi được).
Future<void> showChiaSeSheet(BuildContext context, int ghiChuId, String tieuDe) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChiaSeSheet(ghiChuId: ghiChuId, tieuDe: tieuDe),
    );

class _ChiaSeSheet extends ConsumerStatefulWidget {
  final int ghiChuId;
  final String tieuDe;
  const _ChiaSeSheet({required this.ghiChuId, required this.tieuDe});

  @override
  ConsumerState<_ChiaSeSheet> createState() => _ChiaSeSheetState();
}

class _ChiaSeSheetState extends ConsumerState<_ChiaSeSheet> {
  bool _busy = false;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Chọn 1 tài khoản trong autocomplete → chia sẻ ngay rồi tải lại danh sách.
  Future<void> _them(GhiChuNguoiDungModel u) async {
    setState(() => _busy = true);
    try {
      await ref.read(ghiChuRepositoryProvider).chiaSe(widget.ghiChuId, [u.userId]);
      ref.invalidate(ghiChuChiaSeProvider(widget.ghiChuId));
      _toast('Đã chia sẻ cho ${u.hienThi}');
    } catch (e) {
      _toast(ghiChuErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Xác nhận rồi thu hồi chia sẻ của 1 người.
  Future<void> _thuHoi(GhiChuNguoiDungModel u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi chia sẻ'),
        content: Text('${u.hienThi} sẽ không xem được ghi chú này nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ghiChuRepositoryProvider).thuHoiChiaSe(widget.ghiChuId, u.userId);
      ref.invalidate(ghiChuChiaSeProvider(widget.ghiChuId));
    } catch (e) {
      _toast(ghiChuErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dsAsync = ref.watch(ghiChuChiaSeProvider(widget.ghiChuId));
    final ds = dsAsync.valueOrNull ?? const <GhiChuNguoiDungModel>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chia sẻ "${widget.tieuDe}"', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Người nhận chỉ được xem, không sửa/xoá được.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            NguoiDungAutocomplete(
              excludeIds: ds.map((e) => e.userId).toSet(),
              onSelected: _them,
            ),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text('Đã chia sẻ (${ds.length})', style: Theme.of(context).textTheme.titleSmall),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: dsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(ghiChuErrorMessage(e)),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Chưa chia sẻ cho ai.'),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(u.fullName?.isNotEmpty == true ? u.fullName! : u.username),
                              subtitle: Text(u.username),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                                tooltip: 'Thu hồi',
                                onPressed: () => _thuHoi(u),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở bottom sheet chia sẻ nhiều ghi chú: chọn 1..n tài khoản (chip) rồi bấm Chia sẻ. Trả true nếu đã chia sẻ.
Future<bool> showChiaSeNhieuSheet(BuildContext context, List<int> ghiChuIds) async =>
    (await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChiaSeNhieuSheet(ghiChuIds: ghiChuIds),
    )) ??
    false;

class _ChiaSeNhieuSheet extends ConsumerStatefulWidget {
  final List<int> ghiChuIds;
  const _ChiaSeNhieuSheet({required this.ghiChuIds});

  @override
  ConsumerState<_ChiaSeNhieuSheet> createState() => _ChiaSeNhieuSheetState();
}

class _ChiaSeNhieuSheetState extends ConsumerState<_ChiaSeNhieuSheet> {
  final List<GhiChuNguoiDungModel> _chon = [];
  bool _busy = false;

  /// Gọi API chia sẻ hàng loạt, đóng sheet và báo kết quả.
  Future<void> _submit() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(ghiChuRepositoryProvider)
          .chiaSeNhieu(widget.ghiChuIds, _chon.map((e) => e.userId).toList());
      messenger.showSnackBar(SnackBar(content: Text(
          'Đã chia sẻ ${widget.ghiChuIds.length} ghi chú cho ${_chon.length} tài khoản ($n lượt mới)')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ghiChuErrorMessage(e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chia sẻ ${widget.ghiChuIds.length} ghi chú',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Người nhận chỉ được xem, không sửa/xoá được.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            NguoiDungAutocomplete(
              excludeIds: _chon.map((e) => e.userId).toSet(),
              onSelected: (u) => setState(() => _chon.add(u)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in _chon)
                  InputChip(
                    label: Text(u.hienThi),
                    onDeleted: () => setState(() => _chon.remove(u)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy || _chon.isEmpty ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share_outlined),
                label: Text('Chia sẻ (${_chon.length} tài khoản)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
