// lib/features/kiem_ke/presentation/screens/kiem_ke_nhap_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/router/app_routes.dart';
import '../../../chuyen_xe/data/models/chuyen_xe_model.dart';
import '../../../chuyen_xe/data/models/kiem_ke_model.dart';
import '../../../chuyen_xe/data/repositories/chuyen_xe_repository.dart';

/// Một dòng nhập kiểm kê: Mặt hàng (đã gồm sẵn hãng SX) → Số bình/vỏ xuất.
class _KiemKeRow {
  int nhaCungCapId;
  int matHangId;
  String soBinhXuat;
  String soVoXuat;

  _KiemKeRow({
    this.nhaCungCapId = 0,
    this.matHangId = 0,
    this.soBinhXuat = '',
    this.soVoXuat = '',
  });
}

/// Màn hình kế toán nhập phiếu xuất kho (số bình/vỏ xuất theo mặt hàng, trước
/// khi lái xe đi bán) — route ở root navigator nên tự có Scaffold + AppBar
/// riêng (theo mobile_screen_navigation.md).
///
/// `chuyenXeId == null` → chế độ "phiếu độc lập" (Luồng B): tạo phiếu xuất kho
/// trước, chưa gắn chuyến xe nào (POST /api/kiem-ke). `chuyenXeId != null` →
/// chế độ cũ (Luồng A): xuất kho gắn sẵn theo đúng chuyến đó (PUT
/// /api/chuyen-xe/{id}/kiem-ke), vẫn giữ hoạt động dù không còn lối vào từ menu.
class KiemKeNhapScreen extends StatefulWidget {
  const KiemKeNhapScreen({super.key, this.chuyenXeId, this.ngayLap, this.kiemKeId});

  final int? chuyenXeId;
  // Ngày lập phiếu độc lập = ngày đang lọc ở danh sách (null → backend dùng giờ VN)
  final DateTime? ngayLap;
  // Khac null => che do SUA phieu doc lap da co (PUT /api/kiem-ke/{id})
  final int? kiemKeId;

  @override
  State<KiemKeNhapScreen> createState() => _KiemKeNhapScreenState();
}

class _KiemKeNhapScreenState extends State<KiemKeNhapScreen> {
  final _repo = ChuyenXeRepository();
  final _db = LocalDatabase.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  ChuyenXeModel? _chuyenXe;
  List<Map<String, dynamic>> _matHangList = [];
  List<Map<String, dynamic>> _xeList = [];
  // Xe chuẩn bị hàng — chỉ áp dụng cho phiếu độc lập (Luồng B), tham khảo khi xem lại/liên kết chuyến
  int? _selectedXeId;
  final List<_KiemKeRow> _rows = [];
  final _ghiChuCtrl = TextEditingController();
  // Ngay lap phieu o che do SUA (cho phep chinh lai); null neu khong phai che do sua
  DateTime? _ngayLap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ghiChuCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chuyenXeId = widget.chuyenXeId;
      final mhList = await _db.getMatHangList();
      final xeList = await _db.getXeList();
      ChuyenXeModel? cx;
      KiemKeChuyenXeModel? kiemKe;
      if (chuyenXeId != null) {
        // Luong A: kiem ke gan san theo chuyen
        final results = await Future.wait([
          _repo.getById(chuyenXeId),
          _repo.getKiemKe(chuyenXeId),
        ]);
        cx     = results[0] as ChuyenXeModel;
        kiemKe = results[1] as KiemKeChuyenXeModel?;
      } else if (widget.kiemKeId != null) {
        // Che do SUA: load phieu doc lap da co de prefill
        kiemKe = await _repo.getPhieuKiemKeById(widget.kiemKeId!);
      }

      if (!mounted) return;
      setState(() {
        _chuyenXe    = cx;
        _matHangList = mhList;
        _xeList      = xeList;
        _rows.clear();
        // Che do SUA: nap ngay lap hien tai de cho phep chinh lai
        if (widget.kiemKeId != null) {
          _ngayLap = kiemKe?.ngayLap?.toLocal();
        }
        // Prefill xe da chon (che do SUA phieu doc lap, hoac khoi tao lai sau khi reload)
        if (chuyenXeId == null) {
          _selectedXeId = kiemKe?.xeId;
        }
        if (kiemKe != null && kiemKe.chiTiet.isNotEmpty) {
          _ghiChuCtrl.text = kiemKe.ghiChu ?? '';
          for (final ct in kiemKe.chiTiet) {
            _rows.add(_KiemKeRow(
              nhaCungCapId: ct.nhaCungCapId ?? 0,
              matHangId:    ct.matHangId,
              soBinhXuat:   ct.soBinhXuat > 0 ? '${ct.soBinhXuat}' : '',
              soVoXuat:     ct.soVoXuat > 0 ? '${ct.soVoXuat}' : '',
            ));
          }
        } else {
          _rows.add(_KiemKeRow());
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _addRow() => setState(() => _rows.add(_KiemKeRow()));

  void _removeRow(int index) => setState(() => _rows.removeAt(index));

  /// Chon lai ngay lap phieu (chi o che do SUA).
  Future<void> _pickNgayLap() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ngayLap ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _ngayLap = picked);
  }

  Future<void> _save() async {
    final chiTiet = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final soBinh = int.tryParse(r.soBinhXuat) ?? 0;
      final soVo   = int.tryParse(r.soVoXuat) ?? 0;
      if (r.matHangId <= 0 || (soBinh <= 0 && soVo <= 0)) continue;
      chiTiet.add({
        'nhaCungCapId': r.nhaCungCapId > 0 ? r.nhaCungCapId : null,
        'matHangId':    r.matHangId,
        'soBinhXuat':   soBinh,
        'soVoXuat':     soVo,
      });
    }

    if (chiTiet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ít nhất 1 dòng hợp lệ (chọn mặt hàng + số bình/vỏ)')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ghiChu = _ghiChuCtrl.text.trim().isEmpty ? null : _ghiChuCtrl.text.trim();
      final chuyenXeId = widget.chuyenXeId;
      if (chuyenXeId != null) {
        await _repo.upsertKiemKe(chuyenXeId, ghiChu: ghiChu, chiTiet: chiTiet);
      } else if (widget.kiemKeId != null) {
        // Che do SUA: replace ghiChu + chiTiet, cap nhat lai ngay lap neu co chinh
        await _repo.updatePhieuKiemKe(widget.kiemKeId!,
            ghiChu: ghiChu, chiTiet: chiTiet, ngayLap: _ngayLap, xeId: _selectedXeId);
      } else {
        await _repo.createPhieuKiemKe(
            ghiChu: ghiChu, chiTiet: chiTiet, ngayLap: widget.ngayLap, xeId: _selectedXeId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu phiếu xuất kho thành công'), backgroundColor: Colors.green),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Xóa toàn bộ biên bản kiểm kê của chuyến xe sau khi người dùng xác nhận.
  Future<void> _deleteKiemKe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa kiểm kê?'),
        content: const Text('Xóa toàn bộ biên bản kiểm kê này? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final chuyenXeId = widget.chuyenXeId;
    if (chuyenXeId == null) return;
    setState(() => _saving = true);
    try {
      await _repo.deleteKiemKe(chuyenXeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa kiểm kê'), backgroundColor: Colors.orange),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chuyenXeId != null
            ? 'Kiểm kê xuất hàng'
            : widget.kiemKeId != null
                ? 'Sửa phiếu xuất kho'
                : 'Tạo phiếu xuất kho'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.kiemKeList);
          }
        }),
        actions: [
          if (!_loading && _error == null) ...[
            if (widget.chuyenXeId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Xóa kiểm kê',
                onPressed: _saving ? null : _deleteKiemKe,
              ),
            // Nut Luu dang FilledButton nen teal de noi bat, tranh chim vao mau AppBar sang
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final cx = _chuyenXe;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Header thông tin chuyến — readonly, chỉ hiện khi kiểm kê đã gắn sẵn 1 chuyến (Luồng A).
        if (cx != null) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cx.maChuyenXe,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (cx.bienSoXe != null)
                    _InfoLine(icon: Icons.directions_car, label: 'Biển số xe', value: cx.bienSoXe!),
                  if (cx.tenNhanVien != null)
                    _InfoLine(icon: Icons.person_outline, label: 'Lái xe', value: cx.tenNhanVien!),
                  if (cx.tenPhuXe != null)
                    _InfoLine(icon: Icons.person_outline, label: 'Phụ xe', value: cx.tenPhuXe!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Phieu doc lap (Luong B): cho chon xe chuan bi hang - tuy chon, chi de tham khao
        if (cx == null) ...[
          const Text('Xe (tuỳ chọn)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _selectedXeId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'Chọn xe chuẩn bị hàng',
            ),
            items: _xeList
                .map((xe) => DropdownMenuItem<int>(
                      value: xe['server_id'] as int,
                      child: Text(xe['bien_so_xe'] as String),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedXeId = val),
          ),
          const SizedBox(height: 16),
        ],

        // Che do SUA: cho phep chinh lai ngay lap phieu
        if (widget.kiemKeId != null) ...[
          const Text('Ngày lập phiếu',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickNgayLap,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                _ngayLap != null
                    ? DateFormat('dd/MM/yyyy').format(_ngayLap!)
                    : 'Chọn ngày',
                style: TextStyle(color: _ngayLap == null ? Colors.grey : null),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Chi tiết phiếu xuất kho',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        ..._rows.asMap().entries.map((e) => _RowEditor(
              key: ValueKey(e.key),
              row: e.value,
              matHangList: _matHangList,
              onChanged: () => setState(() {}),
              onRemove: _rows.length > 1 ? () => _removeRow(e.key) : null,
            )),

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Thêm dòng'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),

        const SizedBox(height: 16),
        TextField(
          controller: _ghiChuCtrl,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu phiếu xuất kho'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Editor cho 1 dòng kiểm kê: dropdown Mặt hàng (đã gồm sẵn hãng SX) → 2 ô số.
class _RowEditor extends StatefulWidget {
  final _KiemKeRow row;
  final List<Map<String, dynamic>> matHangList;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _RowEditor({
    super.key,
    required this.row,
    required this.matHangList,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final FocusNode _soBinhFocusNode;

  @override
  void initState() {
    super.initState();
    _soBinhFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _soBinhFocusNode.dispose();
    super.dispose();
  }

  /// Tra cứu "mã - tên (hãng)" của Mặt hàng đang chọn để hiển thị trên field.
  /// Tên hãng lấy trực tiếp từ cache_mat_hang.ten_nha_cc (đã join sẵn từ backend).
  String? _matHangLabel(int matHangId) {
    if (matHangId <= 0) return null;
    final item = widget.matHangList.firstWhere((e) => e['server_id'] == matHangId, orElse: () => {});
    if (item.isEmpty) return null;
    final ma = item['ma_mat_hang'] ?? '';
    final ten = item['ten_mat_hang'] ?? '';
    final tenNcc = item['ten_nha_cc'] as String?;
    final base = '$ma - $ten';
    return (tenNcc != null && tenNcc.isNotEmpty) ? '$base ($tenNcc)' : base;
  }

  Future<void> _pickMatHang(BuildContext context) async {
    final mh = await context.push<Map<String, dynamic>>(AppRoutes.timKiemMatHang);
    if (mh != null) {
      widget.row.matHangId = mh['server_id'] as int;
      // Suy ra hãng SX trực tiếp từ mặt hàng đã chọn — không cần chọn hãng riêng.
      widget.row.nhaCungCapId = mh['nha_cung_cap_id'] as int? ?? 0;
      widget.onChanged();
      // Đợi frame rebuild (do onChanged() trigger setState ở màn cha) rồi mới
      // request focus, tránh focus bị request trên frame cũ.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_soBinhFocusNode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final onRemove = widget.onRemove;
    final matHangLabel = _matHangLabel(row.matHangId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onRemove != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onRemove,
                  tooltip: 'Xoá dòng',
                ),
              ),
            InkWell(
              onTap: () => _pickMatHang(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Mặt hàng',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.search, size: 18),
                ),
                child: Text(
                  matHangLabel ?? 'Chọn mặt hàng',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: matHangLabel == null ? Colors.grey : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.soBinhXuat,
                    focusNode: _soBinhFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số bình xuất',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      row.soBinhXuat = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: row.soVoXuat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số vỏ xuất',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      row.soVoXuat = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
