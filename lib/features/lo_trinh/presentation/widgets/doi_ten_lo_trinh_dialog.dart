// lib/features/lo_trinh/presentation/widgets/doi_ten_lo_trinh_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Hộp thoại nhập tên lộ trình. Trả về tên đã nhập (có thể rỗng = xoá tên), null nếu bấm Bỏ qua.
Future<String?> showDoiTenLoTrinhDialog(
  BuildContext context, {
  String? tenHienTai,
  String tieuDe = 'Đặt tên lộ trình',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DoiTenLoTrinhDialog(tenHienTai: tenHienTai, tieuDe: tieuDe),
  );
}

/// Dialog tự sở hữu TextEditingController: chỉ dispose khi route thực sự bị gỡ khỏi cây
/// (sau animation đóng) — tránh lỗi "used after being disposed" nếu dispose ngay khi pop.
class _DoiTenLoTrinhDialog extends StatefulWidget {
  final String? tenHienTai;
  final String tieuDe;
  const _DoiTenLoTrinhDialog({required this.tenHienTai, required this.tieuDe});

  @override
  State<_DoiTenLoTrinhDialog> createState() => _DoiTenLoTrinhDialogState();
}

class _DoiTenLoTrinhDialogState extends State<_DoiTenLoTrinhDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tenHienTai ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Đóng dialog và trả tên đã nhập.
  void _luu() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tieuDe),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'VD: Giao hàng Đông Anh'),
        onSubmitted: (_) => _luu(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bỏ qua')),
        FilledButton(onPressed: _luu, child: const Text('Lưu')),
      ],
    );
  }
}

/// Lấy message lỗi thân thiện từ response backend.
String loiDoiTen(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
  }
  return 'Đổi tên thất bại';
}
