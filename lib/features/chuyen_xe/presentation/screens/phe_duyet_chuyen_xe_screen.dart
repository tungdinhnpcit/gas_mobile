// lib/features/chuyen_xe/presentation/screens/phe_duyet_chuyen_xe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/router/app_routes.dart';
import '../../../cong_no/data/cong_no_model.dart';
import '../../data/models/chuyen_xe_model.dart';
import '../../data/repositories/chuyen_xe_repository.dart';
import '../providers/chuyen_xe_provider.dart';

// Man hinh phe duyet chuyen xe danh cho ke toan/quan ly sau khi lai xe da ket thuc tren mobile.
// Tong hop san tien mat + tien CK theo tung ngan hang tu du lieu lai xe nhap; ke toan chi kiem tra,
// sua neu can roi phe duyet (POST /api/chuyen-xe/{id}/ket-thuc).
class PheDuyetChuyenXeScreen extends ConsumerStatefulWidget {
  final int chuyenXeId;
  const PheDuyetChuyenXeScreen({super.key, required this.chuyenXeId});

  @override
  ConsumerState<PheDuyetChuyenXeScreen> createState() => _PheDuyetChuyenXeScreenState();
}

class _PheDuyetChuyenXeScreenState extends ConsumerState<PheDuyetChuyenXeScreen> {
  final _repo = ChuyenXeRepository();
  final _db = LocalDatabase.instance;
  final _fmt = NumberFormat('#,##0', 'vi_VN');

  final _tienMatCtrl = TextEditingController();
  final _ghiChuCtrl  = TextEditingController();

  // Danh sach CK theo tung ngan hang (pre-fill tu cx.tienCKTheoTaiKhoan, sua duoc)
  final List<_CKRow> _ckRows = [];
  // Danh sach no cu khach hang can tra
  final List<_TraNoCuRow> _traNoCuRows = [];

  List<Map<String, dynamic>> _taiKhoanList = [];
  int? _tienMatTaiKhoanId; // tai khoan tien mat mac dinh (loai = 'tien-mat')

  bool _initialized = false;
  bool _saving = false;

  // Trạng thái sau khi phê duyệt thành công: hiện section upload ảnh bản kê ngay tại đây
  bool _daPheDuyet = false;
  bool _uploadingBanKe = false;
  int _uploadedCount = 0;
  int _totalToUpload = 0;

  @override
  void initState() {
    super.initState();
    _loadTaiKhoan();
  }

  @override
  void dispose() {
    _tienMatCtrl.dispose();
    _ghiChuCtrl.dispose();
    for (final r in _ckRows) {
      r.dispose();
    }
    for (final r in _traNoCuRows) {
      r.dispose();
    }
    super.dispose();
  }

  // Tai danh sach tai khoan tu cache local; xac dinh tai khoan tien mat mac dinh
  Future<void> _loadTaiKhoan() async {
    final tk = await _db.getTaiKhoanList();
    if (!mounted) return;
    setState(() {
      _taiKhoanList = tk;
      final tienMatTk = tk.where((t) => (t['loai'] as String?) == 'tien-mat');
      _tienMatTaiKhoanId = tienMatTk.isNotEmpty ? tienMatTk.first['server_id'] as int? : null;
    });
  }

  // Danh sach tai khoan ngan hang cho dropdown chon them dong CK
  List<Map<String, dynamic>> get _nganHangList =>
      _taiKhoanList.where((t) => (t['loai'] as String?) == 'ngan-hang').toList();

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  // Strip ky tu la + reformat theo phan nghin
  void _handleNumInput(TextEditingController ctrl, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    final n = int.tryParse(digits) ?? 0;
    final formatted = n > 0 ? _fmt.format(n) : '';
    ctrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  // Pre-fill 1 lan tu du lieu tong hop cua chuyen (tien mat + CK theo ngan hang)
  void _prefill(ChuyenXeModel cx) {
    _tienMatCtrl.text = cx.tongTienMat > 0 ? _fmt.format(cx.tongTienMat.toInt()) : '';
    for (final ck in cx.tienCKTheoTaiKhoan) {
      final row = _CKRow(taiKhoanId: ck.taiKhoanId, tenTaiKhoan: ck.tenTaiKhoan);
      row.soTienCtrl.text = ck.tienCK > 0 ? _fmt.format(ck.tienCK.toInt()) : '';
      _ckRows.add(row);
    }
  }

  double get _tongCK => _ckRows.fold(0.0, (s, r) => s + _parseNum(r.soTienCtrl.text));

  // Goi API phe duyet
  Future<void> _submit(ChuyenXeModel cx) async {
    setState(() => _saving = true);
    try {
      // Gửi TẤT CẢ dòng bán hàng (kể cả dòng vỏ thanhTien=0) để không mất vỏ thu.
      // Dòng vỏ (thanhTien==0) đánh dấu loaiVo='thu' → backend không tính vào bình bán,
      // nhưng vẫn cộng soVoThu vào SoVoThuThucTe.
      final chiTiet = cx.banHang.map((b) {
        final isVoRow = b.thanhTien == 0;
        return {
          'khachHangId': b.khachHangId,
          'matHangId': b.matHangId,
          'soLuong': isVoRow ? 0 : b.soLuong,
          'donGia': b.donGia,
          'soVoBan': b.soVoBan,
          'soVoThu': b.soVoThu,
          if (isVoRow) 'loaiVo': 'thu',
        };
      }).toList();

      final traNoCu = _traNoCuRows
          .where((r) => r.khachHangId != null && _parseNum(r.soTienCtrl.text) > 0)
          .map((r) => {
                'khachHangId': r.khachHangId,
                if (r.chuyenXeId != null) 'chuyenXeId': r.chuyenXeId,
                'soTien': _parseNum(r.soTienCtrl.text),
              })
          .toList();

      final ckTheoTaiKhoan = _ckRows
          .where((r) => r.taiKhoanId != null && _parseNum(r.soTienCtrl.text) > 0)
          .map((r) => {
                'taiKhoanId': r.taiKhoanId,
                'soTien': _parseNum(r.soTienCtrl.text),
              })
          .toList();

      // Giữ lại gas dư lái xe đã nhập (nếu không gửi, KetThuc.GasDu rỗng → mất số kg/tiền gas dư)
      final gasDu = cx.banHangGasDu
          .map((g) => {
                'khachHangId': g.khachHangId,
                'matHangId': g.matHangId,
                'soKg': g.soKg,
                'donGia': g.donGia,
              })
          .toList();

      final body = {
        'chiTiet': chiTiet,
        'voThu': <Map>[],
        'gasDu': gasDu,
        'traNoCu': traNoCu,
        'tienMat': _parseNum(_tienMatCtrl.text),
        if (_tienMatTaiKhoanId != null) 'taiKhoanTienMatId': _tienMatTaiKhoanId,
        'ckTheoTaiKhoan': ckTheoTaiKhoan,
        'ghiChu': _ghiChuCtrl.text.trim().isEmpty ? null : _ghiChuCtrl.text.trim(),
      };

      await _repo.pheduyet(widget.chuyenXeId, body);
      ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Phê duyệt thành công'), backgroundColor: Colors.green),
        );
        // Không pop ngay — hiện section upload ảnh bản kê để kế toán chụp/chọn ảnh tại chỗ
        setState(() => _daPheDuyet = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Chụp ảnh bản kê — cho phép bấm lặp lại nhiều lần liên tục để chụp nhiều tấm.
  Future<void> _handleChupAnhBanKe() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    setState(() {
      _uploadingBanKe = true;
      _uploadedCount = 0;
      _totalToUpload = 1;
    });
    try {
      final upload = ref.read(uploadBanKeProvider);
      await upload(widget.chuyenXeId, photo);
      ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBanKe = false);
    }
  }

  /// Chọn nhiều ảnh từ thư viện và upload tuần tự, có đếm tiến trình.
  Future<void> _handleChonNhieuAnhBanKe() async {
    final picker = ImagePicker();
    final photos = await picker.pickMultiImage(imageQuality: 85);
    if (photos.isEmpty) return;

    setState(() {
      _uploadingBanKe = true;
      _uploadedCount = 0;
      _totalToUpload = photos.length;
    });
    try {
      final upload = ref.read(uploadBanKeProvider);
      for (final photo in photos) {
        await upload(widget.chuyenXeId, photo);
        if (mounted) setState(() => _uploadedCount++);
      }
      ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBanKe = false);
    }
  }

  /// Xóa ảnh bản kê đã upload — cho phép chọn/chụp ảnh khác thay thế.
  Future<void> _handleXoaAnhBanKe(int anhId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ảnh bản kê'),
        content: const Text('Xóa ảnh này? Hành động không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deleteBanKe(widget.chuyenXeId, anhId);
      ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(chuyenXeDetailProvider(widget.chuyenXeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_daPheDuyet ? 'Đã phê duyệt' : 'Phê duyệt chuyến xe'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (cx) {
          if (!_initialized) {
            _prefill(cx);
            _initialized = true;
          }
          return _daPheDuyet ? _buildSauPheDuyet(cx) : _buildContent(cx);
        },
      ),
    );
  }

  // UI hiển thị sau khi đã phê duyệt thành công — cho phép chụp/chọn/xóa ảnh bản kê tại chỗ
  Widget _buildSauPheDuyet(ChuyenXeModel cx) {
    final anhBanKe = cx.ketThuc?.anhBanKe ?? [];
    final baseUrl = AppConstants.staticBaseUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Đã phê duyệt chuyến xe',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ảnh bản kê xác nhận',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (anhBanKe.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('⚠ Chưa có ảnh',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (anhBanKe.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Chưa có ảnh. Chụp lại bản kê đã in và ký để lưu trữ đối chiếu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: anhBanKe.length,
              itemBuilder: (_, i) {
                final anh = anhBanKe[i];
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        barrierColor: Colors.black87,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(12),
                          child: InteractiveViewer(
                            child: Image.network('$baseUrl${anh.url}'),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '$baseUrl${anh.url}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _handleXoaAnhBanKe(anh.id),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          if (_uploadingBanKe) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(_totalToUpload > 1
                    ? 'Đang upload $_uploadedCount/$_totalToUpload...'
                    : 'Đang upload...'),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingBanKe ? null : _handleChupAnhBanKe,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingBanKe ? null : _handleChonNhieuAnhBanKe,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Chọn nhiều ảnh'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ChuyenXeModel cx) {
    final tongTienBanHang = cx.banHang.fold<double>(0, (s, b) => s + b.thanhTien);
    final tongVoThu = cx.banHang.fold<int>(0, (s, b) => s + b.soVoThu);
    final tienMat = _parseNum(_tienMatCtrl.text);
    final tongThu = tienMat + _tongCK;
    final conLai  = tongTienBanHang - tongThu;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Tom tat chuyen xe ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cx.maChuyenXe} — ${cx.bienSoXe ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Tổng tiền bán hàng: ${_fmt.format(tongTienBanHang.toInt())} đ',
                      style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                  if (tongVoThu > 0)
                    Text('Tổng vỏ thu: $tongVoThu vỏ', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Tien mat ---
          const Text('Tiền mặt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _NumField(
            label: 'Tiền mặt (đ)',
            ctrl: _tienMatCtrl,
            onChanged: (v) => _handleNumInput(_tienMatCtrl, v),
          ),
          const SizedBox(height: 16),

          // --- Tien CK theo tung ngan hang ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chuyển khoản theo ngân hàng',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              TextButton.icon(
                onPressed: _nganHangList.isEmpty ? null : () => setState(() => _ckRows.add(_CKRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
              ),
            ],
          ),
          if (_ckRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Chưa có khoản chuyển khoản nào',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            ),
          ..._ckRows.asMap().entries.map((e) => _buildCKRow(e.key, e.value)),
          const SizedBox(height: 8),

          // --- Tong hop ---
          _tongRow('Tổng thu:', tongThu, color: Colors.teal.shade700),
          _tongRow('Còn lại (nợ):', conLai,
              color: conLai > 0 ? Colors.red.shade700 : Colors.green.shade700),
          const SizedBox(height: 16),

          // --- No cu khach hang tra ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nợ cũ thu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              TextButton.icon(
                onPressed: () => setState(() => _traNoCuRows.add(_TraNoCuRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm dòng'),
              ),
            ],
          ),
          ..._traNoCuRows.asMap().entries.map((e) => _buildTraNoCuRow(e.key, e.value)),
          const SizedBox(height: 16),

          // --- Ghi chu ---
          const Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _ghiChuCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ghi chú thêm...',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 24),

          // --- Nut phe duyet ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _submit(cx),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_outlined),
              label: const Text('Xác nhận phê duyệt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tongRow(String label, double value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${_fmt.format(value.toInt())} đ',
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // 1 dong CK: dropdown ngan hang + so tien
  Widget _buildCKRow(int idx, _CKRow row) {
    // Neu dong pre-fill tu server co taiKhoanId nhung khong nam trong _nganHangList (chua tai xong),
    // van cho hien ten tai khoan da co.
    final items = _nganHangList
        .map((t) => DropdownMenuItem<int>(
              value: t['server_id'] as int?,
              child: Text(t['ten_tai_khoan'] as String? ?? '—', overflow: TextOverflow.ellipsis),
            ))
        .toList();
    final hasValue = row.taiKhoanId != null &&
        items.any((it) => it.value == row.taiKhoanId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              initialValue: hasValue ? row.taiKhoanId : null,
              isDense: true,
              hint: Text(row.tenTaiKhoan ?? 'Chọn ngân hàng', overflow: TextOverflow.ellipsis),
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: items,
              onChanged: (v) => setState(() {
                row.taiKhoanId = v;
                row.tenTaiKhoan = _nganHangList
                    .firstWhere((t) => t['server_id'] == v, orElse: () => {})['ten_tai_khoan'] as String?;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.soTienCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền',
                border: OutlineInputBorder(),
                isDense: true,
                suffixText: 'đ',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) => _handleNumInput(row.soTienCtrl, v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => setState(() {
              _ckRows[idx].dispose();
              _ckRows.removeAt(idx);
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Mo man picker chon khoan no cu; pre-fill so tien = con no
  Future<void> _pickNoCu(_TraNoCuRow row) async {
    final picked = await context.push<DuNoItemModel>(
      AppRoutes.chonNoCu,
      extra: {'excludeChuyenXeId': widget.chuyenXeId},
    );
    if (picked == null || !mounted) return;
    setState(() {
      row.khachHangId  = picked.khachHangId;
      row.tenKhachHang = picked.tenKhachHang;
      row.chuyenXeId   = picked.chuyenXeId;
      row.maChuyenXe   = picked.maChuyenXe;
      row.ngayXuat     = picked.ngayXuat;
      row.conNo        = picked.conNo;
      row.soTienCtrl.text = picked.conNo > 0 ? _fmt.format(picked.conNo.toInt()) : '';
    });
  }

  // Nhap so tien thu no cu — cap khong vuot qua con no cua khoan da chon
  void _handleTraNoInput(_TraNoCuRow row, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    var n = int.tryParse(digits) ?? 0;
    if (row.conNo > 0 && n > row.conNo) n = row.conNo.toInt();
    final formatted = n > 0 ? _fmt.format(n) : '';
    row.soTienCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  Widget _buildTraNoCuRow(int idx, _TraNoCuRow row) {
    final selected = row.khachHangId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickNoCu(row),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? const Color(0xFF00897B) : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                      color: selected ? const Color(0xFFE0F2F1) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(selected ? Icons.account_circle : Icons.person_search_outlined,
                            size: 18, color: const Color(0xFF00897B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: selected
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.tenKhachHang ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text('Chuyến ${row.maChuyenXe ?? ''} • Còn nợ ${_fmt.format(row.conNo.toInt())} đ',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                  ],
                                )
                              : const Text('Chọn khách hàng còn nợ',
                                  style: TextStyle(fontSize: 13, color: Colors.black54)),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => setState(() {
                  _traNoCuRows[idx].dispose();
                  _traNoCuRows.removeAt(idx);
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            TextField(
              controller: row.soTienCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền thu',
                border: OutlineInputBorder(),
                isDense: true,
                suffixText: 'đ',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (v) => _handleTraNoInput(row, v),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget input so tien co dinh dang phan nghin
class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  const _NumField({required this.label, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}

// State cho 1 dong CK theo ngan hang
class _CKRow {
  int? taiKhoanId;
  String? tenTaiKhoan;
  final soTienCtrl = TextEditingController();
  _CKRow({this.taiKhoanId, this.tenTaiKhoan});
  void dispose() => soTienCtrl.dispose();
}

// State cho 1 dong no cu khach hang (chon qua man picker)
class _TraNoCuRow {
  int? khachHangId;
  String? tenKhachHang;
  int? chuyenXeId;      // chuyen no goc
  String? maChuyenXe;
  String? ngayXuat;
  double conNo = 0;     // so con no cua khoan da chon (de cap so tien thu)
  final soTienCtrl = TextEditingController();
  void dispose() => soTienCtrl.dispose();
}
