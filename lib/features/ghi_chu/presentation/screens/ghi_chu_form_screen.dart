// lib/features/ghi_chu/presentation/screens/ghi_chu_form_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/ghi_chu_model.dart';
import '../../data/models/ghi_chu_phan_loai_model.dart';
import '../providers/ghi_chu_provider.dart';
import '../widgets/phan_loai_dialogs.dart';

/// Màn hình thêm/sửa/xoá 1 ghi chú: phân loại, tài khoản/mật khẩu, nội dung và ảnh đính kèm.
/// Route đặt ở root navigator (không nằm trong ShellRoute) nên phải tự vẽ Scaffold + AppBar.
/// [item] == null → tạo mới; khác null → sửa/xoá bản ghi hiện có.
class GhiChuFormScreen extends ConsumerStatefulWidget {
  final GhiChuModel? item;

  const GhiChuFormScreen({super.key, this.item});

  @override
  ConsumerState<GhiChuFormScreen> createState() => _GhiChuFormScreenState();
}

class _GhiChuFormScreenState extends ConsumerState<GhiChuFormScreen> {
  static const _maxAnh = 10;
  static const _themPhanLoai = -1; // giá trị đặc biệt trong dropdown: "+ Thêm phân loại"

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tieuDeCtrl;
  late final TextEditingController _taiKhoanCtrl;
  late final TextEditingController _matKhauCtrl;
  late final TextEditingController _ghiChuCtrl;

  int? _id;          // id ghi chú; có giá trị sau khi lưu lần đầu
  int? _phanLoaiId;
  List<GhiChuAnhModel> _anh = [];
  bool _obscure = true;
  bool _saving = false;
  int _uploading = 0; // số ảnh đang upload

  bool get _isEdit => _id != null;

  @override
  void initState() {
    super.initState();
    _id = widget.item?.id;
    _phanLoaiId = widget.item?.phanLoaiId;
    _anh = [...?widget.item?.anh];
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

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyMatKhau() async {
    await Clipboard.setData(ClipboardData(text: _matKhauCtrl.text));
    _toast('Đã sao chép mật khẩu');
  }

  /// Gửi dữ liệu form lên server; trả true nếu lưu thành công (cập nhật [_id] khi tạo mới).
  Future<bool> _persist() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final saved = await ref.read(ghiChuListProvider.notifier).save(
          GhiChuModel(
            id: _id,
            tieuDe: _tieuDeCtrl.text.trim(),
            taiKhoan: _taiKhoanCtrl.text.trim(),
            matKhau: _matKhauCtrl.text,
            ghiChu: _ghiChuCtrl.text.trim(),
            phanLoaiId: _phanLoaiId,
          ),
        );
    if (mounted) setState(() => _id = saved.id);
    return true;
  }

  /// Nút Lưu: lưu ghi chú rồi quay về danh sách.
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (await _persist() && mounted) context.pop();
    } catch (e) {
      _toast(ghiChuErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú'),
        content: Text('Bạn có chắc muốn xoá "${_tieuDeCtrl.text}"? Ảnh đính kèm cũng bị xoá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(ghiChuListProvider.notifier).remove(_id!);
        if (mounted) context.pop();
      } catch (e) {
        _toast(ghiChuErrorMessage(e));
      }
    }
  }

  /// Chọn nguồn ảnh (camera / thư viện) rồi upload. Ghi chú mới sẽ được lưu trước để có id.
  Future<void> _themAnh() async {
    final conLai = _maxAnh - _anh.length - _uploading;
    if (conLai <= 0) {
      _toast('Mỗi ghi chú tối đa $_maxAnh ảnh');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text('Chọn từ thư viện (tối đa $conLai ảnh)'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    List<XFile> files;
    if (source == ImageSource.camera) {
      final f = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1920);
      files = f == null ? [] : [f];
    } else {
      files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1920, limit: conLai > 1 ? conLai : null);
      if (files.length > conLai) {
        _toast('Chỉ thêm được $conLai ảnh, các ảnh còn lại bị bỏ qua');
        files = files.take(conLai).toList();
      }
    }
    if (files.isEmpty || !mounted) return;

    // Ghi chú chưa lưu → lưu trước (cần tiêu đề) để có id gắn ảnh
    if (_id == null) {
      try {
        if (!await _persist()) {
          _toast('Nhập tiêu đề trước khi thêm ảnh');
          return;
        }
      } catch (e) {
        _toast(ghiChuErrorMessage(e));
        return;
      }
    }

    final repo = ref.read(ghiChuRepositoryProvider);
    setState(() => _uploading += files.length);
    var loi = 0;
    for (final f in files) {
      try {
        final anh = await repo.uploadAnh(_id!, f);
        if (mounted) setState(() => _anh = [..._anh, anh]);
      } catch (e) {
        loi++;
        _toast(ghiChuErrorMessage(e));
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
    if (loi > 0 && files.length > 1) _toast('$loi ảnh upload không thành công');
  }

  /// Xác nhận rồi xoá 1 ảnh đính kèm.
  Future<void> _xoaAnh(GhiChuAnhModel anh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ảnh'),
        content: const Text('Bạn có chắc muốn xoá ảnh này?'),
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
      await ref.read(ghiChuRepositoryProvider).deleteAnh(_id!, anh.id);
      if (mounted) setState(() => _anh = _anh.where((a) => a.id != anh.id).toList());
    } catch (e) {
      _toast(ghiChuErrorMessage(e));
    }
  }

  /// Xem ảnh toàn màn hình, vuốt ngang giữa các ảnh, pinch-zoom.
  void _xemAnh(int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: _anh.length,
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: '${AppConstants.staticBaseUrl}${_anh[i].url}',
                  placeholder: (_, __) => const CircularProgressIndicator(),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown phân loại, có lựa chọn cuối "+ Thêm phân loại" mở dialog tạo nhanh.
  Widget _buildPhanLoai(List<GhiChuPhanLoaiModel> phanLoais) {
    // Phân loại đã bị xoá ở nơi khác → không giữ giá trị không còn trong danh sách
    final value = phanLoais.any((p) => p.id == _phanLoaiId) ? _phanLoaiId : null;
    return DropdownButtonFormField<int?>(
      // key theo giá trị để field dựng lại khi chọn phân loại vừa tạo nhanh
      key: ValueKey('pl-$value-${phanLoais.length}'),
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Phân loại', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Chưa phân loại')),
        for (final p in phanLoais)
          DropdownMenuItem<int?>(
            value: p.id,
            child: Row(children: [
              CircleAvatar(radius: 6, backgroundColor: p.color),
              const SizedBox(width: 8),
              Text(p.ten),
            ]),
          ),
        const DropdownMenuItem<int?>(
          value: _themPhanLoai,
          child: Row(children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 8),
            Text('Thêm phân loại'),
          ]),
        ),
      ],
      onChanged: (v) async {
        if (v == _themPhanLoai) {
          final moi = await showPhanLoaiEditDialog(context, ref);
          setState(() => _phanLoaiId = moi?.id ?? _phanLoaiId);
        } else {
          setState(() => _phanLoaiId = v);
        }
      },
    );
  }

  /// Lưới ảnh đính kèm 3 cột + ô "thêm ảnh" + ô loading cho ảnh đang upload.
  Widget _buildAnh() {
    final canAdd = _anh.length + _uploading < _maxAnh;
    final tiles = <Widget>[
      for (var i = 0; i < _anh.length; i++)
        GestureDetector(
          onTap: () => _xemAnh(i),
          onLongPress: () => _xoaAnh(_anh[i]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: '${AppConstants.staticBaseUrl}${_anh[i].url}',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade200),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => _xoaAnh(_anh[i]),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      for (var i = 0; i < _uploading; i++)
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (canAdd)
        InkWell(
          onTap: _themAnh,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined),
                SizedBox(height: 4),
                Text('Thêm ảnh', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh đính kèm (${_anh.length}/$_maxAnh)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final phanLoais = ref.watch(ghiChuPhanLoaiProvider).valueOrNull ?? const <GhiChuPhanLoaiModel>[];
    final busy = _saving || _uploading > 0;

    // Màn hình này ở root navigator → Scaffold + AppBar phải tự vẽ (xem app_router.dart).
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
              onPressed: busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tieuDeCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
            ),
            const SizedBox(height: 12),
            _buildPhanLoai(phanLoais),
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
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
            TextFormField(
              controller: _ghiChuCtrl,
              minLines: 5,
              maxLines: 15,
              maxLength: 1000,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            _buildAnh(),
          ],
        ),
      ),
      // Nút Lưu cố định sát đáy màn hình (nằm trên bàn phím khi bàn phím mở)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_uploading > 0 ? 'Đang tải ảnh...' : 'Lưu'),
            ),
          ),
        ),
      ),
    );
  }
}
