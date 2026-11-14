// lib/features/ghi_chu/presentation/widgets/phan_loai_dialogs.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../providers/ghi_chu_provider.dart';

/// Lấy message lỗi thân thiện từ response backend ({message: ...}).
String ghiChuErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
  }
  return 'Có lỗi xảy ra, vui lòng thử lại';
}

/// Dialog tạo/sửa phân loại (tên + chọn màu). Trả về phân loại đã lưu, null nếu huỷ.
Future<GhiChuPhanLoaiModel?> showPhanLoaiEditDialog(
  BuildContext context,
  WidgetRef ref, {
  GhiChuPhanLoaiModel? item,
}) {
  final ctrl = TextEditingController(text: item?.ten ?? '');
  var mau = item?.mau ?? phanLoaiPalette.first;
  var saving = false;
  String? error;

  return showDialog<GhiChuPhanLoaiModel>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        Future<void> submit() async {
          if (ctrl.text.trim().isEmpty) {
            setSt(() => error = 'Vui lòng nhập tên phân loại');
            return;
          }
          setSt(() {
            saving = true;
            error = null;
          });
          try {
            final r = await ref
                .read(ghiChuPhanLoaiProvider.notifier)
                .save(id: item?.id, ten: ctrl.text, mau: mau);
            if (ctx.mounted) Navigator.pop(ctx, r);
          } catch (e) {
            setSt(() {
              saving = false;
              error = ghiChuErrorMessage(e);
            });
          }
        }

        return AlertDialog(
          title: Text(item == null ? 'Thêm phân loại' : 'Sửa phân loại'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Tên phân loại',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in phanLoaiPalette)
                    GestureDetector(
                      onTap: () => setSt(() => mau = hex),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: phanLoaiColor(hex),
                        child: mau == hex ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(onPressed: saving ? null : submit, child: const Text('Lưu')),
          ],
        );
      },
    ),
  );
}

/// Bottom sheet quản lý phân loại: danh sách + thêm/sửa/xoá.
Future<void> showQuanLyPhanLoaiSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuanLyPhanLoaiSheet(),
  );
}

class _QuanLyPhanLoaiSheet extends ConsumerWidget {
  const _QuanLyPhanLoaiSheet();

  /// Xác nhận rồi xoá phân loại; ghi chú thuộc loại này chuyển về không phân loại.
  Future<void> _delete(BuildContext context, WidgetRef ref, GhiChuPhanLoaiModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá phân loại'),
        content: Text(
          'Xoá "${item.ten}"?${item.soGhiChu > 0 ? '\n${item.soGhiChu} ghi chú sẽ chuyển về "Chưa phân loại".' : ''}',
        ),
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
      await ref.read(ghiChuPhanLoaiProvider.notifier).remove(item.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ghiChuErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ghiChuPhanLoaiProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Phân loại ghi chú', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: () => showPhanLoaiEditDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: state.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Lỗi: $e')),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Chưa có phân loại nào. Bấm "Thêm" để tạo.'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return ListTile(
                            leading: CircleAvatar(radius: 10, backgroundColor: it.color),
                            title: Text(it.ten),
                            subtitle: Text('${it.soGhiChu} ghi chú'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => showPhanLoaiEditDialog(context, ref, item: it),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _delete(context, ref, it),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
