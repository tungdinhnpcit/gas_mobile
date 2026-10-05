// lib/features/chuyen_xe/presentation/screens/chuyen_xe_theo_ngay_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../data/models/chuyen_xe_model.dart';
import '../../data/repositories/chuyen_xe_repository.dart';

/// Args truyền từ BatDauChuyenScreen sang màn hình này qua GoRouter extra.
class ChuyenXeTheoNgayArgs {
  final DateTime ngayXuat;
  final int xeId;
  final String? bienSoXe;
  final int nhanVienId;
  final String? tenNhanVien;

  const ChuyenXeTheoNgayArgs({
    required this.ngayXuat,
    required this.xeId,
    this.bienSoXe,
    required this.nhanVienId,
    this.tenNhanVien,
  });
}

/// Màn hình danh sách chuyến xe theo ngày xuất + xe + lái xe được chọn.
/// User có thể xem và chọn chuyến cũ để nhập tiếp, hoặc tạo chuyến mới bằng FAB.
class ChuyenXeTheoNgayScreen extends ConsumerStatefulWidget {
  final ChuyenXeTheoNgayArgs args;

  const ChuyenXeTheoNgayScreen({super.key, required this.args});

  @override
  ConsumerState<ChuyenXeTheoNgayScreen> createState() =>
      _ChuyenXeTheoNgayScreenState();
}

class _ChuyenXeTheoNgayScreenState
    extends ConsumerState<ChuyenXeTheoNgayScreen> {
  final _repo = ChuyenXeRepository();

  AsyncValue<List<ChuyenXeModel>> _listState = const AsyncValue.loading();
  bool _creatingTrip = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tải danh sách chuyến xe theo ngày + xe + lái xe.
  Future<void> _load() async {
    setState(() => _listState = const AsyncValue.loading());
    try {
      final args = widget.args;
      final list = await _repo.getList(
        nhanVienId: args.nhanVienId,
        xeId: args.xeId,
        tuNgay: DateTime(args.ngayXuat.year, args.ngayXuat.month, args.ngayXuat.day),
        denNgay: DateTime(args.ngayXuat.year, args.ngayXuat.month, args.ngayXuat.day),
        pageSize: 50,
      );
      if (mounted) setState(() => _listState = AsyncValue.data(list));
    } catch (e, st) {
      if (mounted) setState(() => _listState = AsyncValue.error(e, st));
    }
  }

  /// Tạo chuyến xe mới, sau đó navigate sang detail để lái xe nhập bán hàng.
  Future<void> _taoChuyenMoi() async {
    final args = widget.args;
    final ngayStr = DateFormat('dd/MM/yyyy').format(args.ngayXuat);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo chuyến xe mới'),
        content: Text(
          'Tạo chuyến mới cho xe ${args.bienSoXe ?? '#${args.xeId}'}'
              ' ngày $ngayStr'
              '${args.tenNhanVien != null ? '\nLái xe: ${args.tenNhanVien}' : ''}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white),
              child: const Text('Xác nhận')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _creatingTrip = true);
    try {
      final trip = await _repo.createTrip(
        ngayXuat: args.ngayXuat,
        xeId: args.xeId,
        nhanVienId: args.nhanVienId,
      );

      if (mounted) context.push(AppRoutes.chuyenXeDetail(trip.id.toString()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi tạo chuyến: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingTrip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final ngayLabel = DateFormat('dd/MM/yyyy').format(args.ngayXuat);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chuyến xe $ngayLabel'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        }),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: Column(
        children: [
          // Header thông tin xe + lái xe
          Container(
            width: double.infinity,
            color: const Color(0xFF00897B).withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Color(0xFF00897B), size: 18),
                const SizedBox(width: 6),
                Text(
                  args.bienSoXe ?? 'Xe #${args.xeId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00897B)),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.person, color: Color(0xFF00897B), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    args.tenNhanVien ?? 'Lái xe #${args.nhanVienId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00897B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Danh sách chuyến
          Expanded(
            child: _listState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text('$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại')),
                  ],
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined,
                            color: Colors.grey, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có chuyến xe ngày $ngayLabel',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nhấn + để tạo chuyến mới',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _ChuyenXeCard(item: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creatingTrip ? null : _taoChuyenMoi,
        icon: _creatingTrip
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
        label: Text(_creatingTrip ? 'Đang tạo...' : 'Thêm chuyến'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Card hiển thị tóm tắt 1 chuyến xe trong danh sách.
class _ChuyenXeCard extends StatelessWidget {
  final ChuyenXeModel item;

  const _ChuyenXeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(AppRoutes.chuyenXeDetail(item.id.toString())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: mã chuyến + badge trạng thái
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.maChuyenXe,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  _StatusBadge(trangThai: item.trangThai),
                ],
              ),
              const SizedBox(height: 8),

              // Tổng tiền
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Chạm để xem chi tiết',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  Text(
                    '${fmt.format(item.tongTienThu)} đ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00897B),
                        fontSize: 14),
                  ),
                ],
              ),

              // Hiển thị nợ nếu có
              if ((item.soTienNo ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Nợ: ${fmt.format(item.soTienNo!)} đ',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge màu theo trạng thái chuyến xe.
class _StatusBadge extends StatelessWidget {
  final String trangThai;

  const _StatusBadge({required this.trangThai});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (trangThai) {
      'cho-xuat'   => ('Chờ xuất', Colors.amber),
      'dang-giao'  => ('Đang giao', Colors.blue),
      'hoan-thanh' => ('Hoàn thành', Colors.green),
      'huy'        => ('Huỷ', Colors.red),
      _            => (trangThai, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
