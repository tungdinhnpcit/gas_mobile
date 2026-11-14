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

/// Xác nhận rồi xoá phân loại; ghi chú thuộc loại này chuyển về "Chưa phân loại".
/// Trả true nếu đã xoá thành công.
Future<bool> confirmXoaPhanLoai(BuildContext context, WidgetRef ref, GhiChuPhanLoaiModel item) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xoá loại ghi chú'),
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
  if (ok != true) return false;
  try {
    await ref.read(ghiChuPhanLoaiProvider.notifier).remove(item.id);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ghiChuErrorMessage(e))));
    }
    return false;
  }
}
