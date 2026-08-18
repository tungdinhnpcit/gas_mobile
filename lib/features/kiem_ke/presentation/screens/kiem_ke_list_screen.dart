// lib/features/kiem_ke/presentation/screens/kiem_ke_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../chuyen_xe/data/models/kiem_ke_model.dart';
import '../../../chuyen_xe/data/repositories/chuyen_xe_repository.dart';

/// Màn hình kế toán: danh sách phiếu xuất kho độc lập (Luồng B) lọc theo ngày
/// lập, mặc định hôm nay. Mỗi phiếu có 2 giai đoạn: (1) tạo phiếu xuất kho —
/// nhập số bình/vỏ xuất theo mặt hàng trước khi lái xe đi bán; (2) phiếu kiểm
/// kê — nhập số bình còn lại/vỏ mang về khi lái xe bán hàng về. Bấm phiếu
/// chưa gắn chuyến → nhập kiểm kê rồi chọn chuyến để liên kết; bấm phiếu đã
/// gắn chuyến → vào thẳng màn đối chiếu.
class KiemKeListScreen extends StatefulWidget {
  const KiemKeListScreen({super.key});

  @override
  State<KiemKeListScreen> createState() => _KiemKeListScreenState();
}

class _KiemKeListScreenState extends State<KiemKeListScreen> {
  final _repo = ChuyenXeRepository();
  bool _loading = true;
  String? _error;
  List<KiemKeChuyenXeModel> _items = [];

  DateTime _ngay = DateTime.now();

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
      final items = await _repo.getPhieuKiemKeList(tuNgay: _ngay, denNgay: _ngay);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  /// Xoa phieu kiem ke (chua chot) sau khi nguoi dung xac nhan.
  Future<void> _deletePhieu(KiemKeChuyenXeModel kk) async {
    final confirm = await showDialog<bool>(
      context: context,
      // Dung context cua dialog (ctx) de pop dung dialog, tranh pop nham route shell
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phiếu xuất kho?'),
        content: Text('Xóa phiếu xuất kho #${kk.id}? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.deletePhieuKiemKe(kk.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa phiếu xuất kho'), backgroundColor: Colors.orange),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _onTapPhieu(KiemKeChuyenXeModel kk) {
    final chuyenXeId = kk.chuyenXeId;
    if (chuyenXeId != null) {
      context.push(AppRoutes.kiemKeDoiChieu(chuyenXeId));
    } else {
      // Phiếu chưa gắn: kế toán nhập số mang về trước → rồi chọn chuyến để đối chiếu
      context
          .push(AppRoutes.kiemKeNhapSoMangVe(kk.id), extra: kk.ngayLap)
          .then((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('Không tải được dữ liệu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
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

    final fmt = DateFormat('dd/MM/yyyy');

    return Column(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context
                  .push(AppRoutes.kiemKeDocLapNhap, extra: _ngay)
                  .then((_) => _load()),
              icon: const Icon(Icons.add),
              label: const Text('Tạo phiếu xuất kho'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.fact_check_outlined, size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Text('Không có phiếu xuất kho nào trong ngày này',
                                style: TextStyle(color: Colors.black45, fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final kk = _items[i];
                      return _KiemKePhieuItem(
                        item: kk,
                        fmt: fmt,
                        onTap: () => _onTapPhieu(kk),
                        // Chi cho sua/xoa khi phieu chua chot; sua xong tu reload danh sach
                        onEdit: kk.daChot
                            ? null
                            : () => context
                                .push(AppRoutes.kiemKeDocLapSua(kk.id))
                                .then((_) => _load()),
                        onDelete: kk.daChot ? null : () => _deletePhieu(kk),
                      );
                    },
                  ),
          ),
        ),
      ],
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

class _KiemKePhieuItem extends StatelessWidget {
  final KiemKeChuyenXeModel item;
  final DateFormat fmt;
  final VoidCallback onTap;
  // null => an nut sua/xoa (phieu da chot)
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _KiemKePhieuItem({
    required this.item,
    required this.fmt,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                child: const Icon(Icons.fact_check_outlined, color: Color(0xFF00897B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phiếu xuất kho #${item.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    if (item.ngayLap != null)
                      Text(fmt.format(item.ngayLap!.toLocal()),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13)),
                    if (item.maChuyenXe != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(item.maChuyenXe!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                    // Xe chuẩn bị hàng - hiển thị kể cả khi chưa gắn chuyến để biết phiếu này dành cho xe nào
                    if (item.bienSoXe != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(item.bienSoXe!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                    if (item.ghiChu != null && item.ghiChu!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.ghiChu!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Badge(
                    label: item.daGanChuyen ? 'Đã gắn chuyến' : 'Chưa gắn chuyến',
                    color: item.daGanChuyen ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 6),
                  _Badge(
                    label: item.chiTiet.any((c) => c.soBinhConLai != null)
                        ? 'Đã kiểm kê'
                        : 'Chưa kiểm kê',
                    color: item.chiTiet.any((c) => c.soBinhConLai != null)
                        ? Colors.teal
                        : Colors.grey,
                  ),
                  if (item.daChot) ...[
                    const SizedBox(height: 6),
                    const _Badge(label: 'Đã chốt', color: Colors.blue),
                  ],
                  // Nut sua/xoa chi hien khi phieu chua chot, xep ngang canh nhau
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEdit != null)
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit_outlined, size: 20, color: Color(0xFF00897B)),
                            ),
                          ),
                        if (onDelete != null)
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
