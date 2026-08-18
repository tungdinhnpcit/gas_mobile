// lib/features/kiem_ke/presentation/screens/kiem_ke_chon_chuyen_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../chuyen_xe/data/models/chuyen_xe_model.dart';
import '../../../chuyen_xe/data/models/kiem_ke_model.dart';
import '../../../chuyen_xe/data/repositories/chuyen_xe_repository.dart';

/// Màn hình kế toán: chọn 1 chuyến xe đã hoàn thành (do lái xe lập trên mobile)
/// để liên kết vào phiếu kiểm kê độc lập đã tạo — route ở root navigator nên
/// tự có Scaffold + AppBar riêng (theo mobile_screen_navigation.md).
class KiemKeChonChuyenScreen extends StatefulWidget {
  const KiemKeChonChuyenScreen({super.key, required this.kiemKeId, this.ngayMacDinh});

  final int kiemKeId;
  // Ngày mặc định của bộ lọc = ngày lập phiếu kiểm kê (null → hôm nay)
  final DateTime? ngayMacDinh;

  @override
  State<KiemKeChonChuyenScreen> createState() => _KiemKeChonChuyenScreenState();
}

class _KiemKeChonChuyenScreenState extends State<KiemKeChonChuyenScreen> {
  final _repo = ChuyenXeRepository();

  bool _loading = true;
  bool _linking = false;
  String? _error;
  List<ChuyenXeModel> _items = [];
  // Xe da chon luc lap phieu kiem ke - dung de uu tien hien chuyen cung xe len dau danh sach
  int? _kiemKeXeId;

  late DateTime _ngay = widget.ngayMacDinh ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Lấy song song: chuyến hoàn thành + danh sách kiểm kê đã gắn chuyến (để loại chuyến đã gắn)
      // + phiếu kiểm kê hiện tại (để biết xe đã chọn lúc lập phiếu, ưu tiên hiển thị chuyến cùng xe)
      final results = await Future.wait([
        _repo.getListByTrangThai(
          trangThai: 'hoan-thanh',
          tuNgay: _ngay,
          denNgay: _ngay,
        ),
        _repo.getPhieuKiemKeList(daGanChuyen: true),
        _repo.getPhieuKiemKeById(widget.kiemKeId),
      ]);
      final chuyenList = results[0] as List<ChuyenXeModel>;
      final daGan = results[1] as List<KiemKeChuyenXeModel>;
      final kiemKe = results[2] as KiemKeChuyenXeModel;
      final ganIds = daGan.map((k) => k.chuyenXeId).whereType<int>().toSet();

      final kiemKeXeId = kiemKe.xeId;
      final items = chuyenList.where((cx) => !ganIds.contains(cx.id)).toList()
        ..sort((a, b) {
          // Uu tien chuyen cung xe voi phieu kiem ke len dau, giu sap xep ngay giam dan trong tung nhom
          if (kiemKeXeId != null) {
            final aMatch = a.xeId == kiemKeXeId;
            final bMatch = b.xeId == kiemKeXeId;
            if (aMatch != bMatch) return aMatch ? -1 : 1;
          }
          return b.ngayXuat.compareTo(a.ngayXuat);
        });
      if (!mounted) return;
      setState(() {
        _items = items;
        _kiemKeXeId = kiemKeXeId;
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

  /// Chọn ngày qua bottom sheet — chọn xong nhận luôn, không cần nhấn OK.
  Future<void> _pickDate() async {
    await showModalBottomSheet<void>(
      context: context,
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
                    const Text('Chọn ngày',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: CalendarDatePicker(
                    initialDate: _ngay,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    onDateChanged: (picked) {
                      setState(() => _ngay = picked);
                      Navigator.pop(ctx);
                      _load();
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

  Future<void> _chonChuyen(ChuyenXeModel cx) async {
    setState(() => _linking = true);
    try {
      await _repo.lienKetChuyen(widget.kiemKeId, cx.id);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.kiemKeDoiChieu(cx.id));
    } catch (e) {
      if (!mounted) return;
      // Ưu tiên message backend trả về (VD 400: "Chuyến xe đã được kiểm kê khác liên kết.")
      final msg = e is DioException
          ? (e.response?.data is Map ? e.response?.data['message'] as String? : null) ??
              e.message ??
              e.toString()
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn chuyến xe'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.kiemKeList);
          }
        }),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DateButton(
              label: 'Ngày',
              date: _ngay,
              fmt: fmt,
              onTap: _pickDate,
            ),
          ),
          Expanded(child: _buildList(fmt)),
          if (_linking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildList(DateFormat fmt) {
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
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text('Không có chuyến xe hoàn thành trong khoảng ngày này',
                      style: TextStyle(color: Colors.black45, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final cx = _items[i];
          final cungXe = _kiemKeXeId != null && cx.xeId == _kiemKeXeId;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: cungXe
                  ? const BorderSide(color: Color(0xFF00897B), width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _linking ? null : () => _chonChuyen(cx),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFF00897B), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(cx.maChuyenXe,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              if (cungXe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00897B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Cùng xe',
                                      style: TextStyle(
                                          color: Color(0xFF00897B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(fmt.format(cx.ngayXuat.toLocal()),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 13)),
                          if (cx.bienSoXe != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(cx.bienSoXe!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                          if (cx.tenNhanVien != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(cx.tenNhanVien!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF00897B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                fmt.format(date),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
