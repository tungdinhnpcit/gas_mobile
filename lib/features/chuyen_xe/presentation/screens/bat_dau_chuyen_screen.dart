// lib/features/chuyen_xe/presentation/screens/bat_dau_chuyen_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/providers/user_info_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import 'chuyen_xe_theo_ngay_screen.dart';

class BatDauChuyenScreen extends ConsumerStatefulWidget {
  const BatDauChuyenScreen({super.key});

  @override
  ConsumerState<BatDauChuyenScreen> createState() => _BatDauChuyenScreenState();
}

class _BatDauChuyenScreenState extends ConsumerState<BatDauChuyenScreen> {
  final _db = LocalDatabase.instance;

  List<Map<String, dynamic>> _xeList = [];
  List<Map<String, dynamic>> _nhanVienList = [];

  DateTime _selectedDate = DateTime.now();
  int? _selectedXeId;
  String? _selectedBienSo;
  int? _selectedNhanVienId;
  String _nhanVienText = '';
  bool _isNhanVien = false; // true nếu role == LaiXe → read-only
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadXeList();
    _loadNhanVienList();
  }

  /// Tải danh sách xe từ local cache.
  /// Nếu người dùng là lái xe (role == LaiXe), tự động chọn sẵn xe đã được
  /// gán cho họ trên web (Xe.NhanVienLaiXeId), nhưng vẫn cho phép đổi xe khác.
  Future<void> _loadXeList() async {
    final xe = await _db.getXeList();
    final userInfo = await ref.read(userInfoProvider.future);
    final roleCode = userInfo.roleCode;
    final userNvId = userInfo.nhanVienId;

    int? preXeId;
    String? preBienSo;
    if (roleCode == 'LaiXe' && userNvId > 0) {
      final match = xe.where((e) => e['nhan_vien_lai_xe_id'] == userNvId);
      if (match.isNotEmpty) {
        preXeId = match.first['server_id'] as int;
        preBienSo = match.first['bien_so_xe'] as String?;
      }
    }

    if (mounted) {
      setState(() {
        _xeList = xe;
        if (preXeId != null) {
          _selectedXeId = preXeId;
          _selectedBienSo = preBienSo;
        }
      });
    }
  }

  /// Tải danh sách lái xe từ local cache và xác định vai trò người dùng.
  /// - Nếu role == LaiXe: pre-select nhân viên hiện tại, hiển thị read-only.
  /// - Nếu Admin/QuanLy/KeToan: hiển thị autocomplete để chọn lái xe.
  Future<void> _loadNhanVienList() async {
    final list = await _db.getNhanVienList();
    final userInfo = await ref.read(userInfoProvider.future);
    final roleCode = userInfo.roleCode;
    final userNvId = userInfo.nhanVienId;
    final isNhanVien = roleCode == 'LaiXe';

    String preText = '';
    int? preId;

    if (isNhanVien && userNvId > 0) {
      // Lái xe: pre-select bản thân
      final match = list.where((nv) => nv['server_id'] == userNvId).toList();
      if (match.isNotEmpty) {
        preId = userNvId;
        preText = match.first['ho_ten'] as String;
      } else {
        preId = userNvId;
        preText = userInfo.fullName;
      }
    }

    if (mounted) {
      setState(() {
        _nhanVienList = list;
        _isNhanVien = isNhanVien;
        _selectedNhanVienId = preId;
        _nhanVienText = preText;
      });
    }
  }

  /// Mở bottom sheet chọn ngày xuất — chọn xong đóng ngay, không cần nhấn OK.
  Future<void> _pickDate() async {
    await showModalBottomSheet<void>(
      context: context,
      // isScrollControlled: cho phép sheet vượt giới hạn 9/16 màn hình mặc định
      // → CalendarDatePicker + header đủ chỗ, không bị ép cao gây tràn.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Text('Chọn ngày xuất',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Flexible + SingleChildScrollView: khi chiều cao (do TextScaler
              // hoặc màn hình nhỏ) vẫn vượt vùng khả dụng thì cuộn thay vì tràn.
              Flexible(
                child: SingleChildScrollView(
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    onDateChanged: (picked) {
                      setState(() => _selectedDate = picked);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Validate input và navigate sang màn hình danh sách chuyến xe theo ngày.
  Future<void> _xemChuyenXe() async {
    if (_selectedXeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn xe')));
      return;
    }
    if (_selectedNhanVienId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn lái xe')));
      return;
    }

    setState(() => _loading = true);
    try {
      if (mounted) {
        context.push(
          AppRoutes.banHangTheoNgay,
          extra: ChuyenXeTheoNgayArgs(
            ngayXuat: _selectedDate,
            xeId: _selectedXeId!,
            bienSoXe: _selectedBienSo,
            nhanVienId: _selectedNhanVienId!,
            tenNhanVien: _nhanVienText.isNotEmpty ? _nhanVienText : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final dayLabel = DateFormat('dd/MM').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        }),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ngày xuất — tappable date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ngày xuất',
                                style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Text(
                              dateLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.calendar_today,
                          color: Color(0xFF00897B), size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chọn xe
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn xe *',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    _xeList.isEmpty
                        ? const Text('Đang tải danh sách xe...',
                        style: TextStyle(color: Colors.grey))
                        : DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedXeId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('Chọn xe'),
                      items: _xeList
                          .map((xe) => DropdownMenuItem<int>(
                        value: xe['server_id'] as int,
                        child: Text(xe['bien_so_xe'] as String),
                      ))
                          .toList(),
                      onChanged: (val) {
                        final xe = _xeList
                            .firstWhere((e) => e['server_id'] == val);
                        setState(() {
                          _selectedXeId = val;
                          _selectedBienSo = xe['bien_so_xe'] as String?;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chọn lái xe
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lái xe *',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    _isNhanVien
                    // Lái xe đăng nhập: chỉ hiển thị tên, không chọn được
                        ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade100,
                      ),
                      child: Text(
                        _nhanVienText.isEmpty
                            ? 'Không xác định'
                            : _nhanVienText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                    // Admin/QuanLy/KeToan: autocomplete chọn lái xe
                        : _nhanVienList.isEmpty
                        ? const Text(
                        'Chưa có dữ liệu lái xe — vui lòng đồng bộ dữ liệu trước',
                        style: TextStyle(color: Colors.orange))
                        : Autocomplete<Map<String, dynamic>>(
                      initialValue:
                      TextEditingValue(text: _nhanVienText),
                      optionsBuilder: (textValue) {
                        if (textValue.text.isEmpty) {
                          return _nhanVienList;
                        }
                        final q = textValue.text.toLowerCase();
                        return _nhanVienList.where((nv) =>
                        (nv['ho_ten'] as String)
                            .toLowerCase()
                            .contains(q) ||
                            (nv['ma_nhan_vien'] as String)
                                .toLowerCase()
                                .contains(q));
                      },
                      displayStringForOption: (nv) =>
                      '${nv['ho_ten']} (${nv['ma_nhan_vien']})',
                      onSelected: (nv) => setState(() {
                        _selectedNhanVienId = nv['server_id'] as int;
                        _nhanVienText =
                        '${nv['ho_ten']} (${nv['ma_nhan_vien']})';
                      }),
                      fieldViewBuilder: (ctx, ctrl, fn, onSubmit) =>
                          TextFormField(
                            controller: ctrl,
                            focusNode: fn,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              hintText: 'Tìm theo tên hoặc mã NV',
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _xemChuyenXe,
              icon: _loading
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.list_alt_rounded),
              label: Text(_loading
                  ? 'Đang kiểm tra...'
                  : 'Xem chuyến xe ngày $dayLabel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
