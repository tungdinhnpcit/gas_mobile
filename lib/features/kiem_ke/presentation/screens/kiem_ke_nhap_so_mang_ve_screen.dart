// lib/features/kiem_ke/presentation/screens/kiem_ke_nhap_so_mang_ve_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../chuyen_xe/data/models/kiem_ke_model.dart';
import '../../../chuyen_xe/data/repositories/chuyen_xe_repository.dart';

/// Phiếu kiểm kê: kế toán nhập số bình còn lại + số vỏ mang về cho từng mặt
/// hàng (nhóm theo hãng) sau khi lái xe bán hàng về, lưu ngay vào phiếu, rồi
/// chọn chuyến để đối chiếu.
/// Route ở root navigator → tự có Scaffold + AppBar (mobile_screen_navigation.md).
class KiemKeNhapSoMangVeScreen extends StatefulWidget {
  const KiemKeNhapSoMangVeScreen({super.key, required this.kiemKeId, this.ngay});

  final int kiemKeId;
  // Ngày (từ danh sách) truyền tiếp sang màn chọn chuyến
  final DateTime? ngay;

  @override
  State<KiemKeNhapSoMangVeScreen> createState() => _KiemKeNhapSoMangVeScreenState();
}

/// Mot dong nhap: chi tiet mat hang + 3 controller (so binh con lai, so vo mang ve, kg gas du).
/// Dong co san dua vao [ct]; dong moi (them mat hang khi mang ve) co ct=null va tu luu thong tin mat hang.
class _Row {
  final KiemKeChiTietModel? ct; // null = dong moi them tay
  final TextEditingController binhCtrl;
  final TextEditingController voCtrl;
  final TextEditingController gasDuCtrl;

  // Thong tin cho dong moi (khi ct == null)
  final int? matHangId;
  final int? nhaCungCapId;
  final String? matHangLabel;
  final String? tenNhaCungCap;

  _Row.existing(KiemKeChiTietModel c)
      : ct = c,
        matHangId = null,
        nhaCungCapId = null,
        matHangLabel = null,
        tenNhaCungCap = null,
        binhCtrl = TextEditingController(
            text: c.soBinhConLai != null ? '${c.soBinhConLai}' : ''),
        voCtrl = TextEditingController(
            text: c.soVoMangVe != null ? '${c.soVoMangVe}' : ''),
        gasDuCtrl = TextEditingController(
            text: c.soKgGasDu > 0 ? '${c.soKgGasDu}' : '');

  _Row.moi({
    required this.matHangId,
    required this.nhaCungCapId,
    required this.matHangLabel,
    required this.tenNhaCungCap,
  })  : ct = null,
        binhCtrl = TextEditingController(),
        voCtrl = TextEditingController(),
        gasDuCtrl = TextEditingController();

  // Nhan hien thi + hang de nhom (dung chung cho ca 2 loai dong)
  int get theMatHangId => ct?.matHangId ?? matHangId ?? 0;
  int? get theNhaCungCapId => ct?.nhaCungCapId ?? nhaCungCapId;
  String get theLabel =>
      ct != null ? (ct!.matHangLabel.isEmpty ? 'Mặt hàng #${ct!.matHangId}' : ct!.matHangLabel) : (matHangLabel ?? 'Mặt hàng');
  String get theHang =>
      (ct?.tenNhaCungCap ?? tenNhaCungCap)?.trim().isNotEmpty == true
          ? (ct?.tenNhaCungCap ?? tenNhaCungCap)!
          : 'Không xác định hãng';
  bool get isNew => ct == null;

  void dispose() {
    binhCtrl.dispose();
    voCtrl.dispose();
    gasDuCtrl.dispose();
  }
}

class _KiemKeNhapSoMangVeScreenState extends State<KiemKeNhapSoMangVeScreen> {
  final _repo = ChuyenXeRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_Row> _rows = [];

  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final phieu = await _repo.getPhieuKiemKeById(widget.kiemKeId);
      if (!mounted) return;
      for (final r in _rows) {
        r.dispose();
      }
      setState(() {
        _rows = phieu.chiTiet.map((ct) => _Row.existing(ct)).toList();
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

  List<Map<String, dynamic>> _buildChiTiet() => _rows
      .map((r) => {
            // Dong cu gui id; dong moi gui id=0 + matHangId/nhaCungCapId de backend them dong
            'id': r.ct?.id ?? 0,
            if (r.isNew) 'matHangId': r.matHangId,
            if (r.isNew) 'nhaCungCapId': r.nhaCungCapId,
            'soBinhConLai': int.tryParse(r.binhCtrl.text.trim()) ?? 0,
            'soVoMangVe': int.tryParse(r.voCtrl.text.trim()) ?? 0,
            'soKgGasDu': int.tryParse(r.gasDuCtrl.text.trim()) ?? 0,
          })
      .toList();

  Future<bool> _luu({bool silent = false}) async {
    setState(() => _saving = true);
    try {
      await _repo.updateSoMangVe(widget.kiemKeId, _buildChiTiet());
      if (!mounted) return true;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu số mang về'), backgroundColor: Colors.green),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      final msg = e is DioException
          ? (e.response?.data is Map ? e.response?.data['message'] as String? : null) ??
              e.message ??
              e.toString()
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chonChuyen() async {
    // Lưu trước rồi mới sang màn chọn chuyến để đối chiếu
    final ok = await _luu(silent: true);
    if (!ok || !mounted) return;
    context.push(AppRoutes.kiemKeChonChuyen(widget.kiemKeId), extra: widget.ngay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu kiểm kê'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.kiemKeList);
          }
        }),
      ),
      body: _buildBody(),
      bottomNavigationBar: _rows.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Phiếu này chưa có mặt hàng nào.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)),
        ),
      );
    }

    // Nhom dong theo hang, giu thu tu xuat hien
    final groups = <String, List<_Row>>{};
    for (final r in _rows) {
      groups.putIfAbsent(r.theHang, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.factory_outlined, size: 16, color: _teal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _teal)),
                ),
              ],
            ),
          ),
          ...entry.value.map(_rowCard),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _themMatHang,
          icon: const Icon(Icons.add),
          label: const Text('Thêm mặt hàng'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: _teal,
          ),
        ),
      ],
    );
  }

  Widget _rowCard(_Row r) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.theLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (r.isNew)
                  InkWell(
                    onTap: () => _xoaDong(r),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              r.isNew
                  ? 'Mặt hàng thêm khi mang về'
                  : 'Xuất: ${r.ct!.soBinhXuat} bình • ${r.ct!.soVoXuat} vỏ',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numField('Số bình còn lại', r.binhCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _numField('Số vỏ mang về', r.voCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            _numField('Kg gas dư', r.gasDuCtrl),
          ],
        ),
      ),
    );
  }

  /// Them mat hang moi (vo/gas du mat hang khac mang ve) - dung route tim kiem mat hang chung.
  Future<void> _themMatHang() async {
    final mh = await context.push<Map<String, dynamic>>(AppRoutes.timKiemMatHang);
    if (mh == null || !mounted) return;
    final serverId = mh['server_id'] as int?;
    if (serverId == null) return;
    final ma = mh['ma_mat_hang'] ?? '';
    final ten = mh['ten_mat_hang'] ?? '';
    final tenNcc = mh['ten_nha_cc'] as String?;
    final base = '$ma - $ten';
    setState(() {
      _rows.add(_Row.moi(
        matHangId: serverId,
        nhaCungCapId: mh['nha_cung_cap_id'] as int?,
        matHangLabel: (tenNcc != null && tenNcc.isNotEmpty) ? '$base ($tenNcc)' : base,
        tenNhaCungCap: tenNcc,
      ));
    });
  }

  void _xoaDong(_Row r) {
    setState(() {
      _rows.remove(r);
      r.dispose();
    });
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _luu(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: _teal,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _chonChuyen,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping_outlined),
                label: const Text('Chọn chuyến để đối chiếu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
