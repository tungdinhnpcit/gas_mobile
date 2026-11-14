// lib/features/lo_trinh/presentation/widgets/hoan_tat_lo_trinh_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lo_trinh_model.dart';
import '../providers/lo_trinh_provider.dart';
import 'anh_lo_trinh_section.dart';
import 'doi_ten_lo_trinh_dialog.dart' show loiDoiTen;

/// Mở bottom sheet hoàn tất / sửa thông tin lộ trình: tên, ghi chú, ảnh.
/// Trả true nếu đã bấm Lưu thành công; null/false nếu bỏ qua (ảnh đã thêm vẫn được giữ).
Future<bool?> showHoanTatLoTrinhSheet(
  BuildContext context,
  int loTrinhId, {
  String tieuDe = 'Hoàn tất lộ trình',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HoanTatLoTrinhSheet(loTrinhId: loTrinhId, tieuDe: tieuDe),
  );
}

class _HoanTatLoTrinhSheet extends ConsumerStatefulWidget {
  final int loTrinhId;
  final String tieuDe;
  const _HoanTatLoTrinhSheet({required this.loTrinhId, required this.tieuDe});

  @override
  ConsumerState<_HoanTatLoTrinhSheet> createState() => _HoanTatLoTrinhSheetState();
}

class _HoanTatLoTrinhSheetState extends ConsumerState<_HoanTatLoTrinhSheet> {
  final _tenCtrl = TextEditingController();
  final _ghiChuCtrl = TextEditingController();
  bool _daDienSan = false; // chỉ điền tên/ghi chú từ server lần đầu, không ghi đè khi đang gõ
  bool _dangLuu = false;

  @override
  void dispose() {
    _tenCtrl.dispose();
    _ghiChuCtrl.dispose();
    super.dispose();
  }

  /// Điền sẵn tên + ghi chú hiện có của lộ trình (một lần).
  void _dienSan(LoTrinhModel lt) {
    if (_daDienSan) return;
    _daDienSan = true;
    _tenCtrl.text = lt.ten ?? '';
    _ghiChuCtrl.text = lt.ghiChu ?? '';
  }

  /// Lưu tên + ghi chú lên server, làm mới chi tiết + danh sách rồi đóng sheet.
  Future<void> _luu() async {
    setState(() => _dangLuu = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loTrinhRepositoryProvider).capNhat(
            widget.loTrinhId,
            ten: _tenCtrl.text.trim(),
            ghiChu: _ghiChuCtrl.text.trim(),
          );
      ref.invalidate(loTrinhDetailProvider(widget.loTrinhId));
      ref.invalidate(loTrinhListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(loiDoiTen(e)), backgroundColor: Colors.red));
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(loTrinhDetailProvider(widget.loTrinhId));
    return Padding(
      // Đẩy nội dung lên trên bàn phím
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: async.when(
        loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(height: 160, child: Center(child: Text('Lỗi tải lộ trình: $e'))),
        data: (lt) {
          _dienSan(lt);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.tieuDe, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Quãng đường: ${fmtQuangDuong(lt.tongQuangDuongM)} • Thời gian: ${fmtThoiLuong(lt.thoiLuong)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tenCtrl,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tên lộ trình',
                    hintText: 'VD: Giao hàng Đông Anh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ghiChuCtrl,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                AnhLoTrinhSection(loTrinh: lt),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dangLuu ? null : () => Navigator.pop(context, false),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _dangLuu ? null : _luu,
                      child: _dangLuu
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Lưu'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
