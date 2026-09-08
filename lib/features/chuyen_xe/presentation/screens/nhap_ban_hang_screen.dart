// lib/features/chuyen_xe/presentation/screens/nhap_ban_hang_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/database/local_database.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../chuyen_xe/data/repositories/chuyen_xe_repository.dart';
import '../../data/models/chuyen_xe_model.dart';

// ─── Helper state classes ────────────────────────────────────────────────────

class _SaleRow {
  final GlobalKey containerKey = GlobalKey();
  int? matHangId;
  String matHangLabel = '';
  final matHangSearchCtrl = TextEditingController();
  String? maMatHang;
  String? tenMatHang;
  String? maNhaCungCap;
  String? tenNhaCungCap;
  String? donViTinh;

  bool isVo = false;
  String loaiVo = 'thu'; // 'thu' hoặc 'ban'
  final soLuongCtrl = TextEditingController(text: '1');
  final donGiaCtrl = TextEditingController();

  void dispose() {
    matHangSearchCtrl.dispose();
    soLuongCtrl.dispose();
    donGiaCtrl.dispose();
  }

  int get soLuong => int.tryParse(soLuongCtrl.text) ?? 0;
  double get donGia =>
      double.tryParse(
        donGiaCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;
  double get thanhTien => isVo ? 0 : soLuong * donGia;
  int get soVoThu => isVo && loaiVo == 'thu' ? soLuong : 0;
  int get soVoBan => isVo && loaiVo == 'ban' ? soLuong : 0;
}

class _GasDuRow {
  final GlobalKey containerKey = GlobalKey();
  int? matHangId;
  String matHangLabel = '';
  final matHangSearchCtrl = TextEditingController();

  final soKgCtrl = TextEditingController(text: '0');
  final tongTienCtrl = TextEditingController();

  void dispose() {
    matHangSearchCtrl.dispose();
    soKgCtrl.dispose();
    tongTienCtrl.dispose();
  }

  double get soKg => double.tryParse(soKgCtrl.text.replaceAll(',', '')) ?? 0;
  double get tongTien =>
      double.tryParse(
        tongTienCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;
  double get thanhTien => tongTien;
  double get donGia => soKg > 0 ? tongTien / soKg : 0;
}

class _NoVoRow {
  final GlobalKey containerKey = GlobalKey();
  int? matHangId;
  String matHangLabel = '';
  final matHangSearchCtrl = TextEditingController();
  String? maMatHang;
  String? tenMatHang;
  String? maNhaCungCap;
  String? tenNhaCungCap;

  final soLuongCtrl = TextEditingController(text: '0');

  void dispose() {
    matHangSearchCtrl.dispose();
    soLuongCtrl.dispose();
  }

  int get soLuong => int.tryParse(soLuongCtrl.text) ?? 0;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class NhapBanHangScreen extends ConsumerStatefulWidget {
  /// Server ID chuyến xe (null khi chuyến tạo offline).
  final int? chuyenXeServerId;

  /// Local ID chuyến xe (khi chuyến tạo offline, chưa sync).
  final int? chuyenXeLocalId;

  /// Phụ xe đã chọn từ màn hình bán hàng (truyền vào để gửi API).
  final int? phuXeId;

  /// Ngày xuất của chuyến — dùng lấy giá bán đã cấu hình cho ngày đó.
  /// Null ⇒ dùng ngày hôm nay.
  final DateTime? ngayXuat;

  const NhapBanHangScreen({
    super.key,
    this.chuyenXeServerId,
    this.chuyenXeLocalId,
    this.phuXeId,
    this.ngayXuat,
  });

  @override
  ConsumerState<NhapBanHangScreen> createState() => _NhapBanHangScreenState();
}

class _NhapBanHangScreenState extends ConsumerState<NhapBanHangScreen> {
  final _repo = ChuyenXeRepository();
  final _db = LocalDatabase.instance;
  final _fmtMoney = NumberFormat('#,##0', 'vi_VN');

  /// Ngày (yyyy-MM-dd) dùng tra giá bán đã cấu hình — theo ngày xuất chuyến.
  String get _ngayGiaStr =>
      (widget.ngayXuat ?? DateTime.now()).toIso8601String().substring(0, 10);

  // Cache
  List<Map<String, dynamic>> _nhaCCList = [];
  List<Map<String, dynamic>> _taiKhoanList = [];
  List<Map<String, dynamic>> _matHangList = [];
  Map<int, int> _binhToVo = {}; // binh server_id → vo server_id

  // Khách hàng
  Map<String, dynamic>? _selectedKhachHang;

  // Sản phẩm (multi-row)
  final List<_SaleRow> _saleRows = [_SaleRow()];

  // Gas dư
  final List<_GasDuRow> _gasDuRows = [];

  // Nợ vỏ
  final List<_NoVoRow> _noVoRows = [];

  // Thanh toán
  final _tienMatCtrl = TextEditingController(text: '');
  final _tienCKCtrl = TextEditingController(text: '');
  final _dieuChinhTienCtrl = TextEditingController(text: '');
  final _tienChenhLechVoCtrl = TextEditingController(text: '');
  final _tienTruTraTruocCtrl = TextEditingController(text: '');
  int? _selectedTaiKhoanId;

  // Số dư tiền khách đã chuyển trước — chỉ tra được khi online, dùng để hiển thị "Còn lại"
  double? _soDuTraTruoc;
  bool _loadingSoDuTraTruoc = false;

  // Ghi chú
  final _ghiChuCtrl = TextEditingController();

  // GlobalKeys cho scroll-to-top
  final _khachHangSectionKey = GlobalKey();
  final _thanhToanSectionKey = GlobalKey();
  final _ghiChuKey = GlobalKey();

  bool _saving = false;

  // true khi lái xe tự gõ ô Tiền mặt → ngừng auto-fill để không ghi đè giá trị họ nhập
  bool _tienMatManual = false;

  // ── Computed ─────────────────────────────────────────────────────────────

  int get _tongBinhBan =>
      _saleRows.where((r) => !r.isVo).fold(0, (s, r) => s + r.soLuong);

  int get _tongVoThu => _saleRows
      .where((r) => r.isVo && r.loaiVo == 'thu')
      .fold(0, (s, r) => s + r.soLuong);

  double get _tongTienBanHang => _saleRows.fold(0.0, (s, r) => s + r.thanhTien);

  double get _tongTienGasDu => _gasDuRows.fold(0.0, (s, r) => s + r.thanhTien);

  // tong tien khach thuc phai tra = tien ban binh - tien mua gas du (lai xe tra lai khach)
  //   + dieu chinh tien (duong = them, am = bot) + chenh lech tien doi vo
  // truoc day cong nham _tongTienGasDu khien tong tien va no bi day len cao sai
  double get _tongTien =>
      _tongTienBanHang - _tongTienGasDu + _dieuChinhTien + _tienChenhLechVo;

  double get _tienMat =>
      double.tryParse(
        _tienMatCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;

  double get _tienCK =>
      double.tryParse(
        _tienCKCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;

  double get _dieuChinhTien =>
      double.tryParse(
        _dieuChinhTienCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;

  double get _tienChenhLechVo =>
      double.tryParse(
        _tienChenhLechVoCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;

  double get _tienTruTraTruoc =>
      double.tryParse(
        _tienTruTraTruocCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      ) ??
      0;

  double get _conLai => _tongTien - _tienMat - _tienCK - _tienTruTraTruoc;

  // Tự điền Tiền mặt = tổng phải thu, chừng nào lái xe chưa sửa tay ô này.
  void _autoFillTienMat() {
    if (_tienMatManual) return;
    final tong = _tongTien;
    _tienMatCtrl.text = tong > 0 ? _fmtMoney.format(tong.round()) : '';
  }

  // Rebuild + auto-fill Tiền mặt — dùng cho mọi onChanged ảnh hưởng tổng tiền.
  void _onSaleChanged() => setState(_autoFillTienMat);

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCaches();
  }

  @override
  void dispose() {
    _tienMatCtrl.dispose();
    _tienCKCtrl.dispose();
    _dieuChinhTienCtrl.dispose();
    _tienChenhLechVoCtrl.dispose();
    _tienTruTraTruocCtrl.dispose();
    _ghiChuCtrl.dispose();
    for (final r in _saleRows) {
      r.dispose();
    }
    for (final r in _gasDuRows) {
      r.dispose();
    }
    for (final r in _noVoRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCaches() async {
    // Kéo giá bán cấu hình cho ngày xuất chuyến (bỏ qua nếu offline — dùng cache cũ)
    await SyncService.instance
        .syncGiaBanNgay(widget.ngayXuat ?? DateTime.now());
    final ncc = await _db.getNhaCungCapList();
    final tk = await _db.getTaiKhoanList();
    final mh = await _db.getMatHangList();
    final binhToVo = await _db.getBinhToVoMap();
    if (mounted) {
      setState(() {
        _nhaCCList = ncc;
        _taiKhoanList = tk;
        _matHangList = mh;
        _binhToVo = binhToVo;
      });
    }
  }

  /// Tra số dư tiền khách đã chuyển trước (chỉ tra được khi online); im lặng bỏ qua nếu lỗi/offline.
  Future<void> _loadSoDuTraTruoc() async {
    final khServerId = _selectedKhachHang?['server_id'] as int?;
    if (khServerId == null) return;
    setState(() => _loadingSoDuTraTruoc = true);
    try {
      final online = await ConnectivityService.instance.checkOnline();
      if (!online) return;
      final soDu = await _repo.getSoDuTraTruoc(khServerId);
      if (mounted) setState(() => _soDuTraTruoc = soDu);
    } catch (_) {
      // Bỏ qua — trường trừ tiền chuyển trước sẽ không hiển thị số dư nếu tra lỗi
    } finally {
      if (mounted) setState(() => _loadingSoDuTraTruoc = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Scroll den widget de hien thi, khong unfocus tranh conflict focus voi TextField
  void _ensureVisible(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Label mặt hàng: "MA - Tên (MaNCC)"
  String _matHangLabel(Map<String, dynamic> mh) {
    final nccId = mh['nha_cung_cap_id'] as int?;
    final maNcc = nccId != null
        ? (_nhaCCList.firstWhere(
                    (n) => n['server_id'] == nccId,
                    orElse: () => {},
                  )['ma_ncc']
                  as String? ??
              '')
        : '';
    final ma = mh['ma_mat_hang'] as String? ?? '';
    final ten = mh['ten_mat_hang'] as String? ?? '';
    return '$ma - $ten${maNcc.isNotEmpty ? ' ($maNcc)' : ''}';
  }

  void _addSaleRow() {
    setState(() => _saleRows.add(_SaleRow()));
  }

  /// Khi chọn mặt hàng bình có mapping vỏ → tự thêm 1 dòng vỏ (thu) với số
  /// lượng bằng số bình hiện tại. Đặt 1 lần, người dùng vẫn sửa/xóa được.
  void _autoAddVoRow(_SaleRow binhRow) {
    final binhId = binhRow.matHangId;
    if (binhId == null) return;
    final voId = _binhToVo[binhId];
    if (voId == null) return;
    // Tránh trùng: đã có dòng vỏ này rồi thì thôi.
    if (_saleRows.any((r) => r.matHangId == voId)) return;

    final vo = _matHangList.firstWhere(
      (m) => m['server_id'] == voId,
      orElse: () => const {},
    );
    if (vo.isEmpty) return;

    final voRow = _SaleRow()
      ..matHangId = voId
      ..maMatHang = vo['ma_mat_hang'] as String?
      ..tenMatHang = vo['ten_mat_hang'] as String?
      ..donViTinh = vo['don_vi_tinh'] as String?
      ..isVo = true
      ..loaiVo = 'thu';
    final label = _matHangLabel(vo);
    voRow.matHangLabel = label;
    voRow.matHangSearchCtrl.text = label;
    voRow.soLuongCtrl.text = binhRow.soLuong.toString();

    setState(() => _saleRows.add(voRow));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tự thêm dòng vỏ tương ứng (thu vỏ)'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeSaleRow(int index) {
    if (_saleRows.length <= 1) return;
    setState(() {
      _saleRows[index].dispose();
      _saleRows.removeAt(index);
      _autoFillTienMat();
    });
  }

  void _addGasDuRow() {
    setState(() => _gasDuRows.add(_GasDuRow()));
  }

  void _removeGasDuRow(int index) {
    setState(() {
      _gasDuRows[index].dispose();
      _gasDuRows.removeAt(index);
      _autoFillTienMat();
    });
  }

  void _addNoVoRow() {
    setState(() => _noVoRows.add(_NoVoRow()));
  }

  void _removeNoVoRow(int index) {
    setState(() {
      _noVoRows[index].dispose();
      _noVoRows.removeAt(index);
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedKhachHang == null) {
      _showError('Vui lòng chọn khách hàng');
      return;
    }
    final validRows = _saleRows
        .where((r) => r.matHangId != null && r.soLuong > 0)
        .toList();
    if (validRows.isEmpty) {
      _showError('Vui lòng nhập ít nhất 1 mặt hàng với số lượng > 0');
      return;
    }
    if (_tienTruTraTruoc > (_soDuTraTruoc ?? 0)) {
      _showError('Số tiền trừ vượt quá số dư đã chuyển trước hiện có');
      return;
    }

    setState(() => _saving = true);

    final khServerId = _selectedKhachHang!['server_id'] as int?;
    final khLocalId = _selectedKhachHang!['local_id'] as int?;

    try {
      final online = await ConnectivityService.instance.checkOnline();
      final hasServerId = widget.chuyenXeServerId != null;

      if (online && hasServerId && khServerId != null) {
        final xacNhanId = await _repo.nhapKhachHang(widget.chuyenXeServerId!, {
          'khachHangId': khServerId,
          'chiTiet': validRows
              .map(
                (r) => {
                  'matHangId': r.matHangId,
                  'soLuong': r.soLuong,
                  'donGia': r.donGia,
                  'soVoBan': r.soVoBan,
                  'soVoThu': r.soVoThu,
                },
              )
              .toList(),
          'gasDu': _gasDuRows
              .where((r) => r.matHangId != null && r.soKg > 0 && r.tongTien > 0)
              .map(
                (r) => {
                  'matHangId': r.matHangId,
                  'soKg': r.soKg,
                  'donGia': r.donGia, // computed: tongTien / soKg
                },
              )
              .toList(),
          'noVo': _noVoRows
              .where((r) => r.matHangId != null && r.soLuong > 0)
              .map((r) => {'matHangId': r.matHangId, 'soLuong': r.soLuong})
              .toList(),
          'tienMat': _tienMat,
          'tienCK': _tienCK,
          'dieuChinhTien': _dieuChinhTien,
          'tienChenhLechVo': _tienChenhLechVo,
          'tienTruTraTruoc': _tienTruTraTruoc,
          // Thời gian bán lấy từ điện thoại (giờ VN) để lưu đúng mốc thời gian vào DB
          'thoiGianBan': DateTime.now().toIso8601String(),
          if (_selectedTaiKhoanId != null) 'taiKhoanCKId': _selectedTaiKhoanId,
          if (widget.phuXeId != null) 'phuXeId': widget.phuXeId,
          'ghiChu': _ghiChuCtrl.text.trim().isEmpty
              ? null
              : _ghiChuCtrl.text.trim(),
        });
        if (mounted) {
          // Redirect sang xác nhận khách hàng
          // Tim thong tin tai khoan nhan chuyen khoan (neu co chon)
          final selectedTk = _selectedTaiKhoanId != null
              ? _taiKhoanList.firstWhere(
                  (tk) => tk['server_id'] == _selectedTaiKhoanId,
                  orElse: () => <String, dynamic>{},
                )
              : <String, dynamic>{};
          context.pushReplacement(
            '/xac-nhan/$xacNhanId',
            extra: {
              'chuyenXeId': widget.chuyenXeServerId,
              'tenKhachHang': _selectedKhachHang!['ten_khach_hang'] as String?,
              'tienMat': _tienMat,
              'tienCK': _tienCK,
              'dieuChinhTien': _dieuChinhTien,
              'tienChenhLechVo': _tienChenhLechVo,
              'conLai': _conLai,
              'ghiChu': _ghiChuCtrl.text.trim().isEmpty
                  ? null
                  : _ghiChuCtrl.text.trim(),
              'tenTaiKhoan': selectedTk['ten_tai_khoan'] as String?,
              'soTaiKhoan': selectedTk['so_tai_khoan'] as String?,
              'tenNganHang': selectedTk['ngan_hang'] as String?,
              'noVoList': _noVoRows
                  .where((r) => r.matHangId != null && r.soLuong > 0)
                  .map(
                    (r) => BanHangNoVoModel(
                      id: 0,
                      khachHangId: khServerId,
                      matHangId: r.matHangId!,
                      maMatHang: r.maMatHang,
                      tenMatHang: r.tenMatHang,
                      maNhaCungCap: r.maNhaCungCap,
                      tenNhaCungCap: r.tenNhaCungCap,
                      soLuong: r.soLuong,
                      createdAt: DateTime.now(),
                    ),
                  )
                  .toList(),
              'banHangList': validRows
                  .map(
                    (r) => BanHangKhachHangModel(
                      id: 0, // Không có ID trước khi lưu
                      khachHangId: khServerId,
                      tenKhachHang:
                          _selectedKhachHang!['ten_khach_hang'] as String?,
                      matHangId: r.matHangId!,
                      maMatHang: r.maMatHang,
                      tenMatHang: r.tenMatHang,
                      maNhaCungCap: r.maNhaCungCap,
                      tenNhaCungCap: r.tenNhaCungCap,
                      donViTinh: r.donViTinh,
                      soLuong: r.soLuong,
                      donGia: r.donGia,
                      thanhTien: r.thanhTien,
                      soVoBan: r.soVoBan,
                      soVoThu: r.soVoThu,
                      createdAt: DateTime.now(),
                    ),
                  )
                  .toList(),
            },
          );
        }
      } else {
        final confirm = await _showOfflineDialog();
        if (confirm == true && mounted) {
          bool isFirstRow = true;
          final int? phuXeIdOffline = widget.phuXeId;
          for (final r in validRows) {
            await _db.insertBanHangOffline({
              'chuyen_xe_server_id': widget.chuyenXeServerId,
              'chuyen_xe_local_id': widget.chuyenXeLocalId,
              'khach_hang_server_id': khServerId,
              'khach_hang_local_id': khLocalId,
              'mat_hang_id': r.matHangId,
              'so_luong': r.soLuong,
              'don_gia': r.donGia,
              'thanh_tien': r.thanhTien,
              'so_vo_ban': r.soVoBan,
              'so_vo_thu': r.soVoThu,
              'tien_mat': isFirstRow ? _tienMat : 0.0,
              'tien_ck': isFirstRow ? _tienCK : 0.0,
              'dieu_chinh_tien': isFirstRow ? _dieuChinhTien : 0.0,
              'tien_chenh_lech_vo': isFirstRow ? _tienChenhLechVo : 0.0,
              'tai_khoan_ck_id': isFirstRow ? _selectedTaiKhoanId : null,
              'phu_xe_id': isFirstRow ? phuXeIdOffline : null,
              'ghi_chu': isFirstRow && _ghiChuCtrl.text.trim().isNotEmpty
                  ? _ghiChuCtrl.text.trim()
                  : null,
              'created_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            });
            isFirstRow = false;
          }
          for (final r in _gasDuRows.where(
            (g) => g.matHangId != null && g.soKg > 0 && g.tongTien > 0,
          )) {
            await _db.insertBanHangGasDuLocal({
              'chuyen_xe_server_id': widget.chuyenXeServerId,
              'chuyen_xe_local_id': widget.chuyenXeLocalId,
              'khach_hang_server_id': khServerId,
              'khach_hang_local_id': khLocalId,
              'mat_hang_id': r.matHangId,
              'so_kg': r.soKg,
              'don_gia': r.donGia,
              'thanh_tien': r.thanhTien,
              'created_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            });
          }
          for (final r in _noVoRows.where(
            (n) => n.matHangId != null && n.soLuong > 0,
          )) {
            await _db.insertBanHangNoVoLocal({
              'chuyen_xe_server_id': widget.chuyenXeServerId,
              'chuyen_xe_local_id': widget.chuyenXeLocalId,
              'khach_hang_server_id': khServerId,
              'khach_hang_local_id': khLocalId,
              'mat_hang_id': r.matHangId,
              'so_luong': r.soLuong,
              'created_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu offline. Sẽ đồng bộ khi có mạng.'),
              ),
            );
            context.pop();
          }
        }
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('[NHAP_KH] status: ${e.response?.statusCode}');
        debugPrint('[NHAP_KH] resp: ${e.response?.data}');
      }
      if (mounted) _showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _showOfflineDialog() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Không có mạng'),
      content: const Text(
        'Không thể kết nối server. Bạn có muốn lưu dữ liệu offline và đồng bộ sau không?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Lưu offline'),
        ),
      ],
    ),
  );

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── Chặn rời màn khi có dữ liệu chưa lưu ───────────────────────────────────

  /// True nếu user đã nhập bất kỳ dữ liệu bán hàng nào mà chưa lưu.
  bool get _hasUnsavedData {
    if (_selectedKhachHang != null) return true;
    if (_gasDuRows.isNotEmpty || _noVoRows.isNotEmpty) return true;
    if (_saleRows.any((r) =>
        r.matHangId != null ||
        r.soLuongCtrl.text.trim() != '1' ||
        r.donGiaCtrl.text.trim().isNotEmpty)) {
      return true;
    }
    if (_tienMatCtrl.text.trim().isNotEmpty ||
        _tienCKCtrl.text.trim().isNotEmpty ||
        _dieuChinhTienCtrl.text.trim().isNotEmpty ||
        _tienChenhLechVoCtrl.text.trim().isNotEmpty) {
      return true;
    }
    if (_ghiChuCtrl.text.trim().isNotEmpty) return true;
    return false;
  }

  /// Hỏi xác nhận trước khi rời màn — chỉ hỏi khi có dữ liệu chưa lưu.
  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedData) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rời màn hình?'),
        content: const Text(
          'Dữ liệu bán hàng chưa lưu sẽ bị mất. Bạn có chắc muốn rời đi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rời đi'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop:false → chặn back vật lý + swipe-back, mọi lối rời đi qua _confirmLeave
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) context.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Nhập bán hàng'),
        leading: BackButton(
          onPressed: () async {
            if (await _confirmLeave() && mounted) context.pop();
          },
        ),
      ),
      // Bỏ bottom nav (trang chủ / thông báo / cài đặt) để tránh ấn nhầm thoát khi đang nhập bán hàng
      body: GestureDetector(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Summary bar ──────────────────────────────────────────────────
              _buildSummaryBar(),
              const SizedBox(height: 10),

              // ── Khách hàng ───────────────────────────────────────────────────
              _SectionCard(
                key: _khachHangSectionKey,
                title: 'Khách hàng',
                child: _buildKhachHangSection(),
              ),
              const SizedBox(height: 10),

              // ── Chi tiết bán hàng ────────────────────────────────────────────
              _SectionCard(
                title: 'Chi tiết bán hàng',
                child: _buildSaleRowsSection(),
              ),
              const SizedBox(height: 10),

              // ── Mua gas dư ───────────────────────────────────────────────────
              _SectionCard(title: 'Mua gas dư', child: _buildGasDuSection()),
              const SizedBox(height: 10),

              // ── Nợ vỏ ────────────────────────────────────────────────────────
              _SectionCard(title: 'Nợ vỏ', child: _buildNoVoSection()),
              const SizedBox(height: 10),

              // ── Thanh toán ───────────────────────────────────────────────────
              _SectionCard(
                key: _thanhToanSectionKey,
                title: 'Thanh toán',
                child: _buildThanhToanSection(),
              ),
              const SizedBox(height: 10),

              // ── Ghi chú ──────────────────────────────────────────────────────
              TextField(
                key: _ghiChuKey,
                controller: _ghiChuCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onTap: () => _ensureVisible(_ghiChuKey),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00897B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: 'Bình bán', value: '$_tongBinhBan bình'),
          _SummaryDivider(),
          _SummaryItem(label: 'Vỏ thu', value: '$_tongVoThu vỏ'),
          _SummaryDivider(),
          _SummaryItem(
            label: 'Tổng tiền',
            value: '${_fmtMoney.format(_tongTien)} đ',
          ),
        ],
      ),
    );
  }

  Widget _buildKhachHangSection() {
    final tenKH = _selectedKhachHang?['ten_khach_hang'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Button mở màn hình tìm kiếm khách hàng
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final selected = await context.push<Map<String, dynamic>>(
                    AppRoutes.timKiemKhachHang,
                  );
                  if (selected != null && mounted) {
                    setState(() {
                      _selectedKhachHang = selected;
                      _soDuTraTruoc = null;
                    });
                    _loadSoDuTraTruoc();
                  }
                },
                icon: Icon(
                  _selectedKhachHang == null
                      ? Icons.search
                      : Icons.person_outline,
                  size: 18,
                  color: _selectedKhachHang == null
                      ? Colors.grey
                      : const Color(0xFF00897B),
                ),
                label: Text(
                  _selectedKhachHang == null ? 'Tìm kiếm khách hàng...' : tenKH,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _selectedKhachHang == null
                        ? Colors.grey
                        : const Color(0xFF00897B),
                    fontWeight: _selectedKhachHang != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: BorderSide(
                    color: _selectedKhachHang == null
                        ? Colors.grey.shade400
                        : const Color(0xFF00897B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Button tạo khách hàng mới → nhận lại khách vừa tạo và tự chọn vào form
            OutlinedButton.icon(
              onPressed: () async {
                // Gan khach qua callback (khong phu thuoc pop-result vi man nay co
                // PopScope canPop:false lam go_router 14.x mat gia tri tra ve)
                await context.push(
                  AppRoutes.taoKhachHang,
                  extra: {
                    'onCreated': (Map<String, dynamic> kh) {
                      if (mounted) setState(() => _selectedKhachHang = kh);
                    },
                  },
                );
                if (mounted) _loadCaches();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tạo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        // Nút xoá khách hàng đã chọn
        if (_selectedKhachHang != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedKhachHang = null),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bỏ chọn',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSaleRowsSection() {
    return Column(
      children: [
        for (int i = 0; i < _saleRows.length; i++) _buildSaleRow(i),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addSaleRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Thêm dòng hàng'),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleRow(int index) {
    final row = _saleRows[index];

    return Container(
      key: row.containerKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Picker mặt hàng (chạm để chọn) ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.matHangSearchCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Mặt hàng *',
                    hintText: 'Chạm để chọn mặt hàng...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixIcon: row.matHangId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              row.matHangId = null;
                              row.matHangLabel = '';
                              row.matHangSearchCtrl.clear();
                              row.isVo = false;
                              row.donGiaCtrl.clear();
                              _autoFillTienMat();
                            }),
                          )
                        : null,
                  ),
                  onTap: () async {
                    _ensureVisible(row.containerKey);
                    final selected = await context.push<Map<String, dynamic>>(
                      AppRoutes.timKiemMatHang,
                    );
                    if (selected != null && mounted) {
                      final label = _matHangLabel(selected);
                      final isVo =
                          (selected['don_vi_tinh'] as String? ?? '')
                              .toLowerCase() ==
                          'vỏ';
                      // Giá mặc định = giá đã cấu hình cho ngày xuất chuyến.
                      // Chưa cấu hình → null → để trống ô đơn giá.
                      final dg = isVo
                          ? null
                          : await _db.getGiaBanNgay(
                              selected['server_id'] as int,
                              _ngayGiaStr,
                            );
                      if (!mounted) return;
                      setState(() {
                        row.matHangId = selected['server_id'] as int;
                        row.matHangLabel = label;
                        row.matHangSearchCtrl.text = label;
                        row.maMatHang = selected['ma_mat_hang'] as String?;
                        row.tenMatHang = selected['ten_mat_hang'] as String?;
                        row.maNhaCungCap = selected['ma_ncc'] as String?;
                        row.tenNhaCungCap = selected['ten_ncc'] as String?;
                        row.donViTinh = selected['don_vi_tinh'] as String?;
                        row.isVo = isVo;
                        if (dg != null && dg > 0) {
                          row.donGiaCtrl.text = _fmtMoney.format(dg.toInt());
                        } else {
                          row.donGiaCtrl.clear();
                        }
                        _autoFillTienMat();
                      });
                      // Bán bình → tự thêm dòng vỏ tương ứng (thu vỏ cùng số lượng)
                      if (!isVo) _autoAddVoRow(row);
                    }
                  },
                ),
              ),
              if (_saleRows.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _removeSaleRow(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Số lượng / đơn giá ────────────────────────────────────────
          if (row.isVo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Loại vỏ:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'thu', label: Text('Vỏ thu')),
                        ButtonSegment(value: 'ban', label: Text('Vỏ bán')),
                      ],
                      selected: {row.loaiVo},
                      onSelectionChanged: (s) =>
                          setState(() => row.loaiVo = s.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: row.soLuongCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: 'vỏ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onTap: () => _ensureVisible(row.containerKey),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            )
          else
            Column(
              children: [
                TextField(
                  controller: row.soLuongCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: 'bình',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onTap: () => _ensureVisible(row.containerKey),
                  onChanged: (_) => _onSaleChanged(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: row.donGiaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Đơn giá',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: 'đ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onTap: () => _ensureVisible(row.containerKey),
                  onChanged: (_) => _onSaleChanged(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thành tiền',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_fmtMoney.format(row.thanhTien)} đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGasDuSection() {
    return Column(
      children: [
        for (int i = 0; i < _gasDuRows.length; i++) _buildGasDuRow(i),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addGasDuRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Thêm gas dư'),
          ),
        ),
        if (_gasDuRows.isEmpty)
          const Text(
            'Không có gas dư',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildGasDuRow(int index) {
    final row = _gasDuRows[index];

    return Container(
      key: row.containerKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Picker mặt hàng (chạm để chọn) ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.matHangSearchCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Mặt hàng',
                    hintText: 'Chạm để chọn mặt hàng...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixIcon: row.matHangId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              row.matHangId = null;
                              row.matHangLabel = '';
                              row.matHangSearchCtrl.clear();
                            }),
                          )
                        : null,
                  ),
                  onTap: () async {
                    _ensureVisible(row.containerKey);
                    final selected = await context.push<Map<String, dynamic>>(
                      AppRoutes.timKiemMatHang,
                    );
                    if (selected != null && mounted) {
                      final label = _matHangLabel(selected);
                      setState(() {
                        row.matHangId = selected['server_id'] as int;
                        row.matHangLabel = label;
                        row.matHangSearchCtrl.text = label;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => _removeGasDuRow(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.soKgCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số kg',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'kg',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onTap: () => _ensureVisible(row.containerKey),
            onChanged: (_) => _onSaleChanged(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.tongTienCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandsFormatter()],
            decoration: const InputDecoration(
              labelText: 'Tổng tiền',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'đ',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onTap: () => _ensureVisible(row.containerKey),
            onChanged: (_) => _onSaleChanged(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVoSection() {
    return Column(
      children: [
        for (int i = 0; i < _noVoRows.length; i++) _buildNoVoRow(i),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addNoVoRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Thêm nợ vỏ'),
          ),
        ),
        if (_noVoRows.isEmpty)
          const Text(
            'Không có nợ vỏ',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildNoVoRow(int index) {
    final row = _noVoRows[index];

    return Container(
      key: row.containerKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.matHangSearchCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Mặt hàng',
                    hintText: 'Chạm để chọn mặt hàng...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixIcon: row.matHangId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              row.matHangId = null;
                              row.matHangLabel = '';
                              row.matHangSearchCtrl.clear();
                            }),
                          )
                        : null,
                  ),
                  onTap: () async {
                    _ensureVisible(row.containerKey);
                    final selected = await context.push<Map<String, dynamic>>(
                      AppRoutes.timKiemMatHang,
                    );
                    if (selected != null && mounted) {
                      final label = _matHangLabel(selected);
                      setState(() {
                        row.matHangId = selected['server_id'] as int;
                        row.matHangLabel = label;
                        row.matHangSearchCtrl.text = label;
                        row.maMatHang = selected['ma_mat_hang'] as String?;
                        row.tenMatHang = selected['ten_mat_hang'] as String?;
                        row.maNhaCungCap = selected['ma_ncc'] as String?;
                        row.tenNhaCungCap = selected['ten_ncc'] as String?;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => _removeNoVoRow(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.soLuongCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Số lượng',
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'vỏ',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onTap: () => _ensureVisible(row.containerKey),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildThanhToanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tiền mặt
        TextField(
          controller: _tienMatCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [_ThousandsFormatter()],
          onTap: () => _ensureVisible(_thanhToanSectionKey),
          decoration: const InputDecoration(
            labelText: 'Tiền mặt',
            border: OutlineInputBorder(),
            isDense: true,
            suffixText: 'đ',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (_) => setState(() => _tienMatManual = true),
        ),
        const SizedBox(height: 8),
        // Chuyển khoản
        TextField(
          controller: _tienCKCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [_ThousandsFormatter()],
          decoration: const InputDecoration(
            labelText: 'Chuyển khoản',
            border: OutlineInputBorder(),
            isDense: true,
            suffixText: 'đ',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onTap: () => _ensureVisible(_thanhToanSectionKey),
          onChanged: (_) => setState(() {}),
        ),
        // Dropdown tài khoản nhận CK (nếu có dữ liệu)
        if (_taiKhoanList.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _selectedTaiKhoanId,
            decoration: const InputDecoration(
              labelText: 'Tài khoản nhận CK',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            hint: const Text('Chọn tài khoản (không bắt buộc)'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text(
                  '— Không chọn —',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ..._taiKhoanList.map((tk) {
                final ten = tk['ten_tai_khoan'] as String? ?? '';
                final nganHang = tk['ngan_hang'] as String?;
                final label = nganHang != null ? '$ten — $nganHang' : ten;
                return DropdownMenuItem<int>(
                  value: tk['server_id'] as int,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (v) => setState(() => _selectedTaiKhoanId = v),
          ),
        ],
        // Trừ tiền đã chuyển trước — khách đã chuyển khoản trả tiền hóa đơn trước đó
        if (_selectedKhachHang != null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _tienTruTraTruocCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandsFormatter()],
            onTap: () => _ensureVisible(_thanhToanSectionKey),
            decoration: InputDecoration(
              labelText: 'Trừ tiền đã chuyển trước',
              helperText: _loadingSoDuTraTruoc
                  ? 'Đang tra số dư...'
                  : _soDuTraTruoc != null
                      ? 'Còn lại: ${_fmtMoney.format(_soDuTraTruoc)} đ'
                      : null,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixText: 'đ',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 8),
        // Điều chỉnh tiền (+/-): số dương = thêm tiền, số âm = bớt tiền
        TextField(
          controller: _dieuChinhTienCtrl,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [_SignedThousandsFormatter()],
          onTap: () => _ensureVisible(_thanhToanSectionKey),
          decoration: const InputDecoration(
            labelText: 'Điều chỉnh tiền (+/-)',
            hintText: 'VD: -20.000 để bớt, 20.000 để thêm',
            border: OutlineInputBorder(),
            isDense: true,
            suffixText: 'đ',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (_) => _onSaleChanged(),
        ),
        const SizedBox(height: 8),
        // Chênh lệch tiền khi đổi vỏ khác hãng/giá (+/-)
        TextField(
          controller: _tienChenhLechVoCtrl,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [_SignedThousandsFormatter()],
          onTap: () => _ensureVisible(_thanhToanSectionKey),
          decoration: const InputDecoration(
            labelText: 'Chênh lệch đổi vỏ (+/-)',
            hintText: 'vd: -20000 hoặc 20000',
            border: OutlineInputBorder(),
            isDense: true,
            suffixText: 'đ',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (_) => _onSaleChanged(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Còn lại / Nợ:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${_fmtMoney.format(_conLai)} đ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _conLai > 0 ? Colors.red : const Color(0xFF00897B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF00897B),
              ),
            ),
            const Divider(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 32, width: 1, color: Colors.white30);
  }
}

// ─── Thousands separator formatter ───────────────────────────────────────────

class _ThousandsFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll('.', '').replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(raw);
    if (n == null) return oldValue;
    final formatted = _fmt.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─── Signed thousands separator formatter (cho phép dấu '-' ở đầu) ───────────

class _SignedThousandsFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.replaceAll('.', '').replaceAll(',', '');
    final isNegative = raw.startsWith('-');
    if (isNegative) raw = raw.substring(1);
    if (raw.isEmpty) {
      final text = isNegative ? '-' : '';
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final n = int.tryParse(raw);
    if (n == null) return oldValue;
    final formatted = (isNegative ? '-' : '') + _fmt.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
