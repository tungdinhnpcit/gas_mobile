// lib/features/ghi_chu/presentation/screens/ghi_chu_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ghi_chu_model.dart';
import '../providers/ghi_chu_provider.dart';

/// Man hinh them/sua/xoa 1 ghi chu bao mat.
/// Route nay dat o root navigator (khong nam trong ShellRoute) nen phai tu
/// ve Scaffold + AppBar rieng - _MainShell khong ho tro man hinh nay.
/// [item] == null -> tao moi; khac null -> sua/xoa ban ghi hien co.
class GhiChuFormScreen extends ConsumerStatefulWidget {
  final GhiChuModel? item;

  const GhiChuFormScreen({super.key, this.item});

  @override
  ConsumerState<GhiChuFormScreen> createState() => _GhiChuFormScreenState();
}

class _GhiChuFormScreenState extends ConsumerState<GhiChuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tieuDeCtrl;
  late final TextEditingController _taiKhoanCtrl;
  late final TextEditingController _matKhauCtrl;
  late final TextEditingController _ghiChuCtrl;

  bool _obscure = true;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _tieuDeCtrl = TextEditingController(text: widget.item?.tieuDe ?? '');
    _taiKhoanCtrl = TextEditingController(text: widget.item?.taiKhoan ?? '');
    _matKhauCtrl = TextEditingController(text: widget.item?.matKhau ?? '');
    _ghiChuCtrl = TextEditingController(text: widget.item?.ghiChu ?? '');
  }

  @override
  void dispose() {
    _tieuDeCtrl.dispose();
    _taiKhoanCtrl.dispose();
    _matKhauCtrl.dispose();
    _ghiChuCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyMatKhau() async {
    await Clipboard.setData(ClipboardData(text: _matKhauCtrl.text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã sao chép mật khẩu')));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(ghiChuListProvider.notifier)
          .save(
            (widget.item ?? const GhiChuModel(tieuDe: '')).copyWith(
              tieuDe: _tieuDeCtrl.text.trim(),
              taiKhoan: _taiKhoanCtrl.text.trim(),
              matKhau: _matKhauCtrl.text,
              ghiChu: _ghiChuCtrl.text.trim(),
            ),
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú'),
        content: Text('Bạn có chắc muốn xoá "${widget.item!.tieuDe}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(ghiChuListProvider.notifier).remove(widget.item!.id!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Màn hình này ở root navigator -> Scaffold + AppBar phải tự vẽ,
    // không được _MainShell cung cấp (xem app_router.dart).
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa ghi chú' : 'Thêm ghi chú'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xoá ghi chú',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tieuDeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taiKhoanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _matKhauCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Sao chép',
                        onPressed: _copyMatKhau,
                      ),
                      IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Ô ghi chú chiếm toàn bộ phần trống còn lại, nội dung dài cuộn bên trong ô
              Expanded(
                child: TextFormField(
                  controller: _ghiChuCtrl,
                  maxLines: null,
                  minLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Nút Lưu cố định sát đáy màn hình (nằm trên bàn phím khi bàn phím mở)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu'),
            ),
          ),
        ),
      ),
    );
  }
}
