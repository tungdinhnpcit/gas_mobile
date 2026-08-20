// lib/features/chuyen_xe/presentation/screens/chuyen_xe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/user_info_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/chuyen_xe_model.dart';
import '../../data/models/kiem_ke_model.dart';
import '../../data/repositories/chuyen_xe_repository.dart';
import '../providers/chuyen_xe_provider.dart';
import '../../../cong_no/data/cong_no_repository.dart';
import '../../../cong_no/data/cong_no_model.dart';

// Formatter dùng chung trong file.
final _fmtCurrency =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');
final _fmtDateOnly = DateFormat('dd/MM/yyyy');
final _fmtKg = NumberFormat('#,##0.##', 'vi_VN');

class ChuyenXeDetailScreen extends ConsumerStatefulWidget {
  const ChuyenXeDetailScreen({super.key, required this.chuyenXeId});

  final String chuyenXeId;

  @override
  ConsumerState<ChuyenXeDetailScreen> createState() =>
      _ChuyenXeDetailScreenState();
}

class _ChuyenXeDetailScreenState extends ConsumerState<ChuyenXeDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ChuyenXeRepository();
  bool _uploading = false;
  bool _uploadingBanKe = false;
  int _uploadedBanKeCount = 0;
  int _totalBanKeToUpload = 0;
  bool _ketThucLoading = false;
  late final TabController _tabController;

  // Danh sách tab: index cố định, hiển thị tất cả
  static const _tabs = [
    Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'Chi tiết'),
    Tab(icon: Icon(Icons.shopping_cart_outlined, size: 20), text: 'Bán hàng'),
    Tab(icon: Icon(Icons.recycling_rounded, size: 20), text: 'Thu vỏ'),
    Tab(icon: Icon(Icons.fact_check_outlined, size: 20), text: 'Kiểm kê'),
    Tab(icon: Icon(Icons.payments_outlined, size: 20), text: 'Thu tiền'),
    Tab(icon: Icon(Icons.camera_alt_outlined, size: 20), text: 'Ảnh'),
    Tab(icon: Icon(Icons.local_gas_station_outlined, size: 20), text: 'Gas dư'),
    Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Thu nợ'),
  ];

  // Index của tab Bán hàng — dùng để hiện FAB
  static const _banHangTabIndex = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, initialIndex: _banHangTabIndex, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Hiện bottom sheet chọn nguồn ảnh (camera hoặc thư viện).
  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Lái xe xác nhận kết thúc chuyến — đổi trangThai sang hoan-thanh.
  /// Nếu chuyến chưa chọn phụ xe → nhắc chọn phụ xe (hoặc chọn "không có") trước.
  Future<void> _confirmKetThuc() async {
    final id = int.tryParse(widget.chuyenXeId);
    if (id == null) return;

    final cx = ref.read(chuyenXeDetailProvider(id)).valueOrNull;
    if (cx == null) return;

    // Chưa có phụ xe → nhắc chọn phụ xe hoặc xác nhận không có phụ xe trước khi kết thúc.
    if (cx.phuXeId == null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Chưa chọn phụ xe'),
          content: const Text(
              'Chuyến này chưa có phụ xe. Vui lòng chọn phụ xe, hoặc xác nhận chuyến không có phụ xe để tiếp tục kết thúc.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'huy'),
                child: const Text('Huỷ')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'khong-co'),
                child: const Text('Không có phụ xe')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'chon'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B)),
              child: const Text('Chọn phụ xe'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'huy' || !mounted) return;

      try {
        if (choice == 'khong-co') {
          await _repo.capNhatPhuXe(id, null);
        } else {
          // 'chon' → mở màn tìm phụ xe
          final selected =
              await context.push<Map<String, dynamic>>(AppRoutes.timKiemPhuXe);
          if (selected == null || !mounted) return; // user không chọn → huỷ kết thúc
          await _repo.capNhatPhuXe(id, selected['id'] as int?);
        }
        ref.invalidate(chuyenXeDetailProvider(id));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi lưu phụ xe: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    await _thucHienKetThuc(id);
  }

  /// Hiện dialog xác nhận rồi gọi API kết thúc chuyến (dùng chung cho mọi nhánh).
  Future<void> _thucHienKetThuc(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kết thúc chuyến?'),
        content: const Text('Xác nhận bạn đã nhập xong tất cả khách hàng trong ngày.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _ketThucLoading = true);
    try {
      await _repo.ketThucMobile(id);
      ref.invalidate(chuyenXeDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chuyến xe đã kết thúc'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _ketThucLoading = false);
    }
  }

  /// Lái xe xác nhận xóa chuyến xe — toàn bộ dữ liệu sẽ bị xóa vĩnh viễn.
  Future<void> _xoaChuyenXe() async {
    final id = int.tryParse(widget.chuyenXeId);
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa chuyến xe?'),
        content: const Text(
            'Toàn bộ dữ liệu bán hàng và ảnh sẽ bị xóa vĩnh viễn. Không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.deleteTrip(id);
      if (!mounted) return;
      final nhanVienId = ref.read(userInfoProvider).value?.nhanVienId ?? 0;
      ref.read(chuyenXeListProvider.notifier).load(
        nhanVienId: nhanVienId > 0 ? nhanVienId : null,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Xử lý chọn ảnh và upload lên server, tự động nén xuống ≤ 1MB.
  Future<void> _handleUpload(ChuyenXeModel cx) async {
    final source = await _pickSource();
    if (source == null) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return;

    setState(() => _uploading = true);
    try {
      final upload = ref.read(uploadPhotoProvider);
      await upload(cx.id, photo);
      final id = int.tryParse(widget.chuyenXeId) ?? 0;
      ref.invalidate(chuyenXeDetailProvider(id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Kế toán chụp ảnh bản kê xác nhận — cho phép bấm lặp lại nhiều lần liên tục để chụp nhiều tấm.
  Future<void> _handleChupAnhBanKe(ChuyenXeModel cx) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    setState(() {
      _uploadingBanKe = true;
      _uploadedBanKeCount = 0;
      _totalBanKeToUpload = 1;
    });
    try {
      final upload = ref.read(uploadBanKeProvider);
      await upload(cx.id, photo);
      final id = int.tryParse(widget.chuyenXeId) ?? 0;
      ref.invalidate(chuyenXeDetailProvider(id));
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

  /// Chọn nhiều ảnh bản kê từ thư viện và upload tuần tự, có đếm tiến trình.
  Future<void> _handleChonNhieuAnhBanKe(ChuyenXeModel cx) async {
    final picker = ImagePicker();
    final photos = await picker.pickMultiImage(imageQuality: 85);
    if (photos.isEmpty) return;

    setState(() {
      _uploadingBanKe = true;
      _uploadedBanKeCount = 0;
      _totalBanKeToUpload = photos.length;
    });
    try {
      final upload = ref.read(uploadBanKeProvider);
      for (final photo in photos) {
        await upload(cx.id, photo);
        if (mounted) setState(() => _uploadedBanKeCount++);
      }
      final id = int.tryParse(widget.chuyenXeId) ?? 0;
      ref.invalidate(chuyenXeDetailProvider(id));
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
  Future<void> _handleXoaAnhBanKe(int chuyenXeId, int anhId) async {
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
      await _repo.deleteBanKe(chuyenXeId, anhId);
      final id = int.tryParse(widget.chuyenXeId) ?? 0;
      ref.invalidate(chuyenXeDetailProvider(id));
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
    final id = int.tryParse(widget.chuyenXeId) ?? 0;
    // Guard: id không hợp lệ (route conflict) — trả về trang lỗi thay vì crash
    if (id <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('ID chuyến xe không hợp lệ: "${widget.chuyenXeId}"'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/chuyen-xe'),
                child: const Text('Quay lại danh sách'),
              ),
            ],
          ),
        ),
      );
    }
    final detailAsync = ref.watch(chuyenXeDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: detailAsync.when(
          loading: () => Text('Chuyến #${widget.chuyenXeId}'),
          error: (_, __) => Text('Chuyến #${widget.chuyenXeId}'),
          data: (cx) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cx.bienSoXe ?? cx.maChuyenXe,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                _fmtDateOnly.format(cx.ngayXuat.toLocal()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Trang chủ',
            onPressed: () => context.go(AppRoutes.home),
          ),
          if (detailAsync.valueOrNull != null &&
              detailAsync.valueOrNull!.trangThai != 'hoan-thanh' &&
              detailAsync.valueOrNull!.trangThai != 'huy')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa chuyến xe',
              onPressed: _xoaChuyenXe,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs,
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Không tải được thông tin'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(chuyenXeDetailProvider(id)),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (cx) => Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _TabChiTiet(cx: cx),
                _TabBanHang(cx: cx),
                _TabThuVo(cx: cx),
                _TabKiemKe(cx: cx),
                _TabThuTien(cx: cx),
                _TabAnh(
                  cx: cx,
                  uploading: _uploading,
                  onUpload: () => _handleUpload(cx),
                  uploadingBanKe: _uploadingBanKe,
                  uploadedBanKeCount: _uploadedBanKeCount,
                  totalBanKeToUpload: _totalBanKeToUpload,
                  onChupAnhBanKe: () => _handleChupAnhBanKe(cx),
                  onChonNhieuAnhBanKe: () => _handleChonNhieuAnhBanKe(cx),
                  onXoaAnhBanKe: (anhId) => _handleXoaAnhBanKe(cx.id, anhId),
                ),
                _TabGasDu(cx: cx),
                _TabThuNo(cx: cx),
              ],
            ),
            // Header tóm tắt luôn hiển thị phía trên
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderBar(cx: cx),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
      bottomNavigationBar: _buildBottomBar(detailAsync),
    );
  }

  /// Xay dung bottom bar phu hop voi role va trang thai chuyen xe:
  /// - Lai xe + dang-giao: button "Ket thuc chuyen" mau cam
  /// - Ke toan/QL/GD + hoan-thanh + chua co ketThuc: button "Phe duyet" mau xanh duong
  Widget? _buildBottomBar(AsyncValue<ChuyenXeModel> detailAsync) {
    final cx = detailAsync.valueOrNull;
    if (cx == null) return null;

    final roleCode = ref.watch(userInfoProvider).value?.roleCode ?? '';
    final isLaiXe = roleCode == 'LaiXe' || roleCode.isEmpty;

    // Lai xe thay button "Ket thuc chuyen" khi dang-giao
    if (cx.trangThai == 'dang-giao' && isLaiXe) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _ketThucLoading ? null : _confirmKetThuc,
            icon: _ketThucLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Kết thúc chuyến'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );
    }

    // Ke toan/QL/GD thay button "Phe duyet" khi hoan-thanh + chua co ketThuc
    if (cx.trangThai == 'hoan-thanh' && cx.ketThuc == null && !isLaiXe) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: () {
              final id = int.tryParse(widget.chuyenXeId);
              if (id == null) return;
              context.push('/phe-duyet/$id');
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Phê duyệt chuyến xe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );
    }

    return null;
  }
}

// ── Header tóm tắt mã chuyến + trạng thái ──────────────────────────────────

class _HeaderBar extends StatelessWidget {
  final ChuyenXeModel cx;
  const _HeaderBar({required this.cx});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFF00897B), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cx.maChuyenXe,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  _fmtDateOnly.format(cx.ngayXuat.toLocal()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          _StatusBadge(label: cx.trangThaiLabel, color: cx.trangThaiColor),
        ],
      ),
    );
  }
}

// ── Tab 1: Chi tiết hàng hóa ────────────────────────────────────────────────

class _TabChiTiet extends StatelessWidget {
  final ChuyenXeModel cx;
  const _TabChiTiet({required this.cx});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thông tin xe + ghi chú
          _SectionCard(
            title: 'Thông tin chuyến',
            child: Column(
              children: [
                if (cx.bienSoXe != null)
                  _InfoRow(
                      icon: Icons.directions_car,
                      label: 'Biển số xe',
                      value: cx.bienSoXe!),
                if (cx.bienSoXe != null) const SizedBox(height: 8),
                if (cx.tenNhanVien != null)
                  _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Lái xe',
                      value: cx.tenNhanVien!),
                if (cx.tenNhanVien != null) const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Ngày xuất',
                    value: _fmtDateOnly.format(cx.ngayXuat.toLocal())),
                if (cx.ghiChu != null && cx.ghiChu!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.note_outlined,
                      label: 'Ghi chú',
                      value: cx.ghiChu!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tổng hợp bán hàng
          _BanHangSummaryCard(cx),
          const SizedBox(height: 16),

          // Thống kê thu tiền: tổng số khách, xác nhận, tiền mặt, tiền theo tài khoản
          _SectionCard(
            title: 'Thống kê thu tiền',
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.groups_outlined,
                    label: 'Tổng số khách hàng',
                    value: '${cx.tongSoKhachHang}'),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Đã xác nhận / chưa xác nhận',
                    value: '${cx.soKhachDaXacNhan} / ${cx.soKhachChuaXacNhan}'),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Tổng tiền mặt',
                    value: _fmtCurrency.format(cx.tongTienMat)),
                if (cx.tienCKTheoTaiKhoan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...cx.tienCKTheoTaiKhoan.map((tk) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _InfoRow(
                            icon: Icons.account_balance_outlined,
                            label: tk.tenTaiKhoan ?? 'Không rõ tài khoản',
                            value: _fmtCurrency.format(tk.tienCK)),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danh sách hàng hóa: nếu đã settle dùng ketThuc.chiTiet (có tên KH + giá), ngược lại dùng kế hoạch chuyến
          if (cx.ketThuc != null && cx.ketThuc!.chiTiet.isNotEmpty) ...[
            _SectionLabel(
                '${cx.ketThuc!.chiTiet.map((c) => c.khachHangId).toSet().length} khách hàng đã mua'),
            const SizedBox(height: 8),
            ...cx.ketThuc!.chiTiet.asMap().entries.map((e) {
              final i  = e.key;
              final ct = e.value;
              return GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _KhachHangDetailSheet(
                    cx: cx,
                    khachHangId: ct.khachHangId,
                    tenKhachHang: ct.tenKhachHang,
                  ),
                ),
                child: _KetThucChiTietCard(index: i, item: ct),
              );
            }),
          ] else if (cx.chiTiet.isNotEmpty) ...[
            _SectionLabel('${cx.chiTiet.length} mặt hàng mang theo'),
            const SizedBox(height: 8),
            ...cx.chiTiet.asMap().entries.map((e) {
              final i  = e.key;
              final ct = e.value;
              return _MatHangPlanCard(index: i, item: ct);
            }),
          ] else
            _EmptyState(
                icon: Icons.inventory_2_outlined,
                label: 'Chưa có hàng hóa trong chuyến'),
          const SizedBox(height: 16),

          // Tổng tiền thu
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền thu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text(
                  _fmtCurrency.format(cx.tongTienThu),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Card khách hàng khi chuyến đã kết thúc — hiển thị tên KH + mặt hàng + giá thực tế.
class _KetThucChiTietCard extends StatelessWidget {
  final int index;
  final KetThucChiTietModel item;
  const _KetThucChiTietCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF00897B).withValues(alpha: 0.15),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Color(0xFF00897B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.tenKhachHang ?? 'Khách hàng #${item.khachHangId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Text(
                  _fmtCurrency.format(item.thanhTien),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00897B),
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DataChip(
                      label: 'Mặt hàng',
                      value: item.tenMatHang ?? 'ID ${item.matHangId}'),
                ),
                _DataChip(label: 'SL', value: '${item.soLuong} bình'),
                const SizedBox(width: 8),
                _DataChip(
                    label: 'Đ/bình',
                    value: _fmtCurrency.format(item.donGia)),
              ],
            ),
            if (item.soVoBan > 0 || item.soVoThu > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  _DataChip(
                      label: 'Vỏ bán',
                      value: '${item.soVoBan}',
                      color: Colors.blue),
                  const SizedBox(width: 8),
                  _DataChip(
                      label: 'Vỏ thu',
                      value: '${item.soVoThu}',
                      color: Colors.teal),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Card mặt hàng mang theo khi chuyến chưa kết thúc — chỉ hiển thị tên hàng + số lượng, không có tên khách hàng.
class _MatHangPlanCard extends StatelessWidget {
  final int index;
  final ChuyenXeChiTietModel item;
  const _MatHangPlanCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.15),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.tenMatHang ?? 'Mặt hàng #${item.matHangId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (item.tenNhaCungCap != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.nhaCungCapLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55)),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${item.soLuong} bình',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF00897B)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1b: Bán hàng (lái xe nhập) ────────────────────────────────────────

class _TabBanHang extends ConsumerStatefulWidget {
  final ChuyenXeModel cx;
  const _TabBanHang({required this.cx});

  @override
  ConsumerState<_TabBanHang> createState() => _TabBanHangState();
}

class _TabBanHangState extends ConsumerState<_TabBanHang> {
  final _repo = ChuyenXeRepository();

  // ── Phụ xe selection ────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedPhuXe;

  // ── Tìm kiếm khách hàng (filter trực tiếp danh sách bên dưới) ──────────────
  final _customerSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final phuXeId = widget.cx.phuXeId;
    if (phuXeId != null) {
      _selectedPhuXe = {'id': phuXeId, 'hoTen': widget.cx.tenPhuXe ?? ''};
    }
  }

  Future<void> _openKhachHangDetail(ChuyenXeModel cx, List<BanHangKhachHangModel> rows,
      List<GasDuChiTietModel> gasDuRows) async {
    final noVoRows = cx.banHangNoVo
        .where((n) => n.khachHangId == rows.first.khachHangId)
        .toList();
    final thanhToanMatches = cx.banHangThanhToan
        .where((t) => t.khachHangId == rows.first.khachHangId);
    final thanhToan = thanhToanMatches.isEmpty ? null : thanhToanMatches.first;
    await context.push(
      AppRoutes.suaBanHangKhachHang(cx.id, rows.first.khachHangId),
      extra: {
        'rows': rows,
        'gasDuRows': gasDuRows,
        'noVoRows': noVoRows,
        'thanhToan': thanhToan,
      },
    );
    if (mounted) ref.invalidate(chuyenXeDetailProvider(cx.id));
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    super.dispose();
  }


  /// Xây dựng badge xác nhận khách hàng — chỉ hiển thị trạng thái (không bấm được).
  /// Muốn ký/chụp lại phải vào màn sửa bán hàng của khách.
  Widget _buildXacNhanBadge(int khachHangId, Map<int, XacNhanKhachHangModel?> xacNhanMap) {
    final xn = xacNhanMap[khachHangId];
    final daXacNhan = xn?.daXacNhan ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: daXacNhan ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        // trang thai don gian: da ky xac nhan hay chua
        daXacNhan ? '✓ Đã ký' : '⚠ Chưa ký',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Lưu phụ xe ngay khi chọn/xóa ở màn chi tiết (không cần nhập bán hàng) → quay lại vẫn hiển thị.
  Future<void> _luuPhuXe(int? phuXeId) async {
    try {
      await _repo.capNhatPhuXe(widget.cx.id, phuXeId);
      if (!mounted) return;
      ref.invalidate(chuyenXeDetailProvider(widget.cx.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu phụ xe: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Goi lai provider de lay du lieu moi tu server - dung lam callback cho RefreshIndicator
  Future<void> _refresh() async =>
      ref.refresh(chuyenXeDetailProvider(widget.cx.id).future);

  /// Mo dialog xem anh bien lai hoac chu ky xac nhan cua khach hang
  // Xem ảnh xác nhận phóng to theo url cụ thể (biên lai hoặc chữ ký) — hỗ trợ 2 luồng song song
  void _xemAnhFull(String relativeUrl, {required bool isKy, DateTime? ngayXacNhan}) {
    final baseUrl = AppConstants.resolvedApiUrl.replaceFirst(RegExp(r'/apimanager$'), '');
    final imageUrl = '$baseUrl$relativeUrl';
    final title = isKy ? 'Chữ ký xác nhận' : 'Ảnh biên lai';
    final iconData = isKy ? Icons.draw_outlined : Icons.image_outlined;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: const Color(0xFF00897B),
                child: Row(
                  children: [
                    Icon(iconData, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade100,
                    child: const Center(
                        child: Text('Không tải được ảnh',
                            style: TextStyle(color: Colors.grey))),
                  ),
                ),
              ),
              if (ngayXacNhan != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: Colors.grey.shade50,
                  child: Text(
                    'Xác nhận lúc: ${_fmtDate.format(ngayXacNhan.toLocal())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Strip hiển thị thumbnail ảnh biên lai + chữ ký của khách (cả 2 luồng nếu có)
  Widget _buildXacNhanThumbnails(XacNhanKhachHangModel? xn) {
    if (xn == null || (!xn.coAnh && !xn.coChuKy)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      color: const Color(0xFFF1F8F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ảnh xác nhận khách hàng:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (xn.coAnh)
                _xacNhanThumb(xn.anhUrl!, label: 'Biên lai', icon: Icons.image_outlined, isKy: false, ngay: xn.ngayXacNhan),
              if (xn.coChuKy)
                _xacNhanThumb(xn.chuKyUrl!, label: 'Chữ ký', icon: Icons.draw_outlined, isKy: true, ngay: xn.ngayXacNhan),
            ],
          ),
        ],
      ),
    );
  }

  // Một thumbnail ảnh xác nhận — bấm để phóng to
  Widget _xacNhanThumb(String relativeUrl,
      {required String label, required IconData icon, required bool isKy, DateTime? ngay}) {
    final baseUrl = AppConstants.resolvedApiUrl.replaceFirst(RegExp(r'/apimanager$'), '');
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _xemAnhFull(relativeUrl, isKy: isKy, ngayXacNhan: ngay),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.white,
                child: Image.network(
                  '$baseUrl$relativeUrl',
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'vi_VN');
    final cx = widget.cx;
    final items = cx.banHang;
    // Thực thu toàn chuyến = tiền bán hàng + điều chỉnh + chênh lệch vỏ − tiền mua gas dư.
    // Cùng công thức với khachPhaiTra của từng card để footer = Σ các card.
    final total = items.fold<double>(0, (s, b) => s + b.thanhTien) +
        cx.banHangThanhToan
            .fold<double>(0, (s, t) => s + t.dieuChinhTien + t.tienChenhLechVo) -
        cx.banHangGasDu.fold<double>(0, (s, g) => s + g.thanhTien);
    final canEdit =
        cx.trangThai != 'hoan-thanh' && cx.trangThai != 'huy';

    // Nhóm theo khachHangId, giữ thứ tự xuất hiện đầu tiên
    final groups = <int, List<BanHangKhachHangModel>>{};
    for (final b in items) {
      groups.putIfAbsent(b.khachHangId, () => []).add(b);
    }
    final groupEntries = groups.entries.toList()
      ..sort((a, b) => a.value.first.createdAt.compareTo(b.value.first.createdAt));

    final searchQuery = removeDiacritics(_customerSearchCtrl.text.trim());
    final filteredEntries = searchQuery.isEmpty
        ? groupEntries
        : groupEntries
            .where((e) => removeDiacritics(e.value.first.tenKhachHang ?? '')
                .contains(searchQuery))
            .toList();

    // Lấy xacNhan list từ cx
    final xacNhanMap = <int, XacNhanKhachHangModel?>{};
    for (final xn in cx.xacNhan) {
      final existing = xacNhanMap[xn.khachHangId];
      // Lấy xacNhan mới nhất
      if (existing == null || xn.id > existing.id) {
        xacNhanMap[xn.khachHangId] = xn;
      }
    }

    return Column(
      children: [
        // Khoảng trống cho _HeaderBar (Positioned overlay ~56px)
        const SizedBox(height: 56),

        // ── Phụ xe ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phụ xe — button mở màn hình tìm kiếm
              Row(
                children: [
                  const Icon(Icons.person_search,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text('Phụ xe:',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(width: 8),
                  if (_selectedPhuXe != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _selectedPhuXe!['hoTen'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() => _selectedPhuXe = null);
                        _luuPhuXe(null);
                      },
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await context.push<
                              Map<String, dynamic>>(
                            AppRoutes.timKiemPhuXe,
                          );
                          if (selected != null && mounted) {
                            setState(() => _selectedPhuXe = selected);
                            _luuPhuXe(selected['id'] as int?);
                          }
                        },
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Chọn phụ xe',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Tìm kiếm khách hàng (filter trực tiếp danh sách bên dưới) ─────────────
        // Luôn hiện kể cả khi canEdit=false vì chỉ đọc dữ liệu, không sửa.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TextField(
            controller: _customerSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm khách hàng...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixIcon: _customerSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _customerSearchCtrl.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Button Nhập bán hàng ở đầu tab — chỉ hiện khi chuyến đang giao
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context
                    .push(
                      AppRoutes.nhapBanHang(cx.id),
                      extra: {
                        'phuXeId': _selectedPhuXe?['id'] as int?,
                        'ngayXuat': cx.ngayXuat.toLocal(), // lay gia cau hinh theo ngay xuat chuyen
                      },
                    )
                    .then((_) => ref.invalidate(chuyenXeDetailProvider(cx.id))),
                icon: const Icon(Icons.add),
                label: const Text('Nhập bán hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),

        // Danh sách hoặc empty state
        if (items.isEmpty)
          // Boc RefreshIndicator + CustomScrollView de ho tro pull-to-refresh khi chua co data
          // CustomScrollView + SliverFillRemaining fill toan bo viewport nen gesture keo xuat hien ngay ca khi content ngan
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh, // goi _refresh() khi nguoi dung keo xuong
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false, // content khong scroll doc lap, fill viewport
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Chưa có dữ liệu bán hàng',
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('Nhấn + để nhập',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (filteredEntries.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('Không tìm thấy khách hàng phù hợp',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else ...[
        // Boc RefreshIndicator de ho tro pull-to-refresh khi co data
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh, // goi _refresh() khi nguoi dung keo xuong
            child: ListView.builder(
              // AlwaysScrollableScrollPhysics bat buoc de pull gesture hoat dong khi list ngan hon viewport
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: filteredEntries.length,
              itemBuilder: (_, i) {
              final entry = filteredEntries[i];
              final rows = entry.value;
              // loc rieng cac dong mua gas du cua khach nay tu cx.banHangGasDu (list rieng, khong nam trong rows)
              final gasDuRows = cx.banHangGasDu.where((g) => g.khachHangId == entry.key).toList();
              final khachTen = rows.first.tenKhachHang ?? '—';
              // tong tien lai xe da tra khach de mua lai gas du - so tien nay phai duoc TRU vao no
              final tongTienGasDu = gasDuRows.fold<double>(0, (s, g) => s + g.thanhTien);
              final soBinhBan   = rows.where((b) => b.soVoThu == 0 && b.soVoBan == 0).fold(0, (s, b) => s + b.soLuong);
              final soVoThu     = rows.fold(0, (s, b) => s + b.soVoThu);
              // thong tin thanh toan cua khach nay nam trong list rieng cx.banHangThanhToan
              final thanhToanRows = cx.banHangThanhToan.where((t) => t.khachHangId == entry.key).toList();
              final dieuChinhTien = thanhToanRows.isNotEmpty ? thanhToanRows.first.dieuChinhTien : 0.0;
              final tienChenhLechVo = thanhToanRows.isNotEmpty ? thanhToanRows.first.tienChenhLechVo : 0.0;
              // tong tien ban hang (chua tru gas du) - chi dung de tinh khachPhaiTra, khong hien thi truc tiep
              final khachTotal  = rows.fold<double>(0, (s, b) => s + b.thanhTien) + tienChenhLechVo;
              // tong tien khach THUC PHAI TRA = tien hang ban + chenh lech doi vo - tien mua gas du (da tra lai khach) + dieu chinh
              final khachPhaiTra = khachTotal - tongTienGasDu + dieuChinhTien;
              final tienDaTra   = thanhToanRows.fold(0.0, (s, t) => s + t.tienMat + t.tienCK);
              final tienNo      = (khachPhaiTra - tienDaTra).clamp(0.0, double.infinity);

              return InkWell(
                onTap: () => _openKhachHangDetail(cx, rows, gasDuRows),
                borderRadius: BorderRadius.circular(10),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Header: tên khách + tổng tiền khách đó
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00897B),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        khachTen,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white),
                                      ),
                                    ),
                                    // Badge xác nhận
                                    _buildXacNhanBadge(entry.key, xacNhanMap),
                                  ],
                                ),
                                Text(
                                  _fmtDate.format(rows.first.createdAt.toLocal()),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${fmt.format(khachPhaiTra)}đ',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // Strip thumbnail ảnh xác nhận (biên lai + chữ ký) — 2 luồng song song
                    _buildXacNhanThumbnails(xacNhanMap[entry.key]),
                    // Danh sách mặt hàng
                    ...rows.asMap().entries.map((e) {
                      final idx = e.key;
                      final b = e.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            const Divider(height: 1, indent: 14, endIndent: 14),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                          children: [
                                            TextSpan(text: '${b.maMatHang != null ? "${b.maMatHang} - " : ""}${b.tenMatHang ?? "—"}'),
                                            if (b.maNhaCungCap != null)
                                              TextSpan(
                                                text: ' (${b.maNhaCungCap} - ${b.tenNhaCungCap ?? ""})',
                                                style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.normal),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${b.soLuong} × ${fmt.format(b.donGia)}đ  →  ${fmt.format(b.thanhTien)}đ',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF00897B),
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (b.soVoThu > 0 || b.soVoBan > 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Vỏ thu: ${b.soVoThu}  |  Kho→KH: ${b.soVoBan}',
                                            style: const TextStyle(
                                                color: Colors.blueGrey,
                                                fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    // Stats footer: số bình bán, vỏ thu, tiền nợ
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                        border: Border(
                            top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.propane_tank_outlined,
                                label: '$soBinhBan bình',
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                icon: Icons.recycling,
                                label: '$soVoThu vỏ thu',
                                color: Colors.blueGrey,
                              ),
                              const Spacer(),
                              tienNo > 0
                                  ? _StatChip(
                                      icon: Icons.warning_amber_rounded,
                                      label: 'Nợ ${fmt.format(tienNo)}đ',
                                      color: Colors.red,
                                    )
                                  : _StatChip(
                                      icon: Icons.check_circle_outline,
                                      label: 'Đã thu đủ',
                                      color: Colors.green,
                                    ),
                            ],
                          ),
                          // chi hien dong nay neu khach co ban gas du - de user thay ro
                          // day la tien mua gas du (khong phai khach mua binh gas), da tru vao no o tren
                          if (tongTienGasDu > 0) ...[
                            const SizedBox(height: 6), // khoang cach voi dong stat phia tren
                            _StatChip(
                              icon: Icons.local_gas_station_outlined, // icon rieng cho gas du, khac icon binh gas
                              label: 'Mua gas dư ${fmt.format(tongTienGasDu)}đ', // ghi ro la mua gas du, khong phai ban binh
                              color: Colors.orange.shade700, // mau cam - dong bo voi mau gas du mua lai trong _KhachHangDetailSheet
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
          ), // dong RefreshIndicator
        ),
        Container(
          color: const Color(0xFFE0F2F1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng (${groupEntries.length} KH)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${fmt.format(total)}đ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF00897B))),
            ],
          ),
        ),
        ], // đóng else ...[
      ],
    );
  }
}

// ── Tab 2: Thu vỏ bình ────────────────────────────────────────────────────

class _TabThuVo extends StatelessWidget {
  final ChuyenXeModel cx;
  const _TabThuVo({required this.cx});

  /// Tổng hợp tạm tính vỏ thu từ cx.banHang khi kế toán chưa duyệt (cx.ketThuc == null).
  List<VoThuChiTietModel> _voThuTamTinh() {
    final groups = <String, List<BanHangKhachHangModel>>{};
    for (final b in cx.banHang.where((b) => b.soVoThu > 0)) {
      final key = '${b.matHangId}|${b.maNhaCungCap ?? ''}';
      groups.putIfAbsent(key, () => []).add(b);
    }
    return groups.values.map((rows) {
      final first = rows.first;
      return VoThuChiTietModel(
        id: first.matHangId,
        matHangId: first.matHangId,
        maMatHang: first.maMatHang,
        tenMatHang: first.tenMatHang,
        maNhaCungCap: first.maNhaCungCap,
        tenNhaCungCap: first.tenNhaCungCap,
        soVo: rows.fold(0, (s, b) => s + b.soVoThu),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final daDuyet = cx.ketThuc != null;
    final voThu = daDuyet ? cx.ketThuc!.voThu : _voThuTamTinh();
    final tongVo = daDuyet
        ? cx.ketThuc!.soVoThuThucTe
        : voThu.fold<int>(0, (s, v) => s + v.soVo);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (voThu.isEmpty)
            _EmptyState(
                icon: Icons.recycling_rounded,
                label: 'Không có dữ liệu thu vỏ')
          else ...[
            if (!daDuyet) ...[
              const _GhiChuTamTinh(),
              const SizedBox(height: 8),
            ],
            _SummaryRow(
                label: 'Tổng vỏ thu',
                value: '$tongVo bình',
                valueColor: Colors.teal),
            const SizedBox(height: 12),
            _SectionLabel('Chi tiết theo hãng'),
            const SizedBox(height: 8),
            ...voThu.map((v) => _VoThuCard(item: v)),
          ],
        ],
      ),
    );
  }
}

/// Banner ghi chú số liệu tạm tính khi chuyến kết thúc qua mobile nhưng kế toán
/// chưa duyệt trên web (chưa có bản ghi KetThucChuyenXe chính thức).
class _GhiChuTamTinh extends StatelessWidget {
  const _GhiChuTamTinh();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Số liệu tạm tính từ dữ liệu đã nhập — chờ kế toán duyệt chính thức',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

// Card một dòng thu vỏ.
class _VoThuCard extends StatelessWidget {
  final VoThuChiTietModel item;
  const _VoThuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.recycling_rounded,
              color: Colors.teal, size: 22),
        ),
        title: Text(
          item.matHangLabel.isNotEmpty
              ? item.matHangLabel
              : 'Mặt hàng #${item.matHangId}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          item.nhaCungCapLabel.isNotEmpty
              ? item.nhaCungCapLabel
              : 'Không xác định hãng',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.soVo} vỏ',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2b: Kiểm kê xuất hàng (read-only) ───────────────────────────────────

class _TabKiemKe extends ConsumerWidget {
  final ChuyenXeModel cx;
  const _TabKiemKe({required this.cx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kiemKeAsync = ref.watch(kiemKeProvider(cx.id));

    return kiemKeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Không tải được kiểm kê'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(kiemKeProvider(cx.id)),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (kk) {
        if (kk == null || kk.chiTiet.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
            child: _EmptyState(
                icon: Icons.fact_check_outlined,
                label: 'Chưa có dữ liệu kiểm kê'),
          );
        }

        // Nhóm theo Nhà cung cấp, giữ tên "Khác" cho dòng không có hãng.
        final groups = <String, List<KiemKeChiTietModel>>{};
        for (final ct in kk.chiTiet) {
          final key = ct.tenNhaCungCap?.isNotEmpty == true
              ? ct.nhaCungCapLabel
              : 'Khác';
          groups.putIfAbsent(key, () => []).add(ct);
        }

        final tongBinhXuat = kk.chiTiet.fold<int>(0, (s, c) => s + c.soBinhXuat);
        final tongVoXuat   = kk.chiTiet.fold<int>(0, (s, c) => s + c.soVoXuat);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kk.ngayLap != null || kk.nguoiLap != null)
                _SectionCard(
                  title: 'Thông tin kiểm kê',
                  child: Column(
                    children: [
                      if (kk.ngayLap != null)
                        _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Ngày lập',
                            value: _fmtDate.format(kk.ngayLap!.toLocal())),
                      if (kk.ngayLap != null && kk.nguoiLap != null)
                        const SizedBox(height: 8),
                      if (kk.nguoiLap != null)
                        _InfoRow(
                            icon: Icons.person_outline,
                            label: 'Người lập',
                            value: kk.nguoiLap!),
                      if (kk.ghiChu != null && kk.ghiChu!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                            icon: Icons.note_outlined,
                            label: 'Ghi chú',
                            value: kk.ghiChu!),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryRow(
                        label: 'Tổng bình xuất',
                        value: '$tongBinhXuat bình',
                        valueColor: const Color(0xFF00897B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryRow(
                        label: 'Tổng vỏ xuất',
                        value: '$tongVoXuat vỏ',
                        valueColor: Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...groups.entries.map((entry) => _KiemKeNhaCungCapSection(
                    tenNhaCungCap: entry.key,
                    rows: entry.value,
                  )),
            ],
          ),
        );
      },
    );
  }
}

/// Section nhóm theo hãng — header + danh sách dòng mặt hàng.
class _KiemKeNhaCungCapSection extends StatelessWidget {
  final String tenNhaCungCap;
  final List<KiemKeChiTietModel> rows;
  const _KiemKeNhaCungCapSection({required this.tenNhaCungCap, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.factory_outlined, size: 16, color: Color(0xFF00897B)),
              const SizedBox(width: 6),
              Text(
                tenNhaCungCap,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((ct) => _KiemKeChiTietCard(item: ct)),
        ],
      ),
    );
  }
}

/// Card một dòng kiểm kê: mặt hàng + số bình/vỏ xuất + số còn lại/mang về (nếu có).
class _KiemKeChiTietCard extends StatelessWidget {
  final KiemKeChiTietModel item;
  const _KiemKeChiTietCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.matHangLabel.isNotEmpty
                  ? item.matHangLabel
                  : 'Mặt hàng #${item.matHangId}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DataChip(
                      label: 'Bình xuất', value: '${item.soBinhXuat}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DataChip(label: 'Vỏ xuất', value: '${item.soVoXuat}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _DataChip(
                    label: 'Bình còn lại',
                    value: item.soBinhConLai != null ? '${item.soBinhConLai}' : '-',
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DataChip(
                    label: 'Vỏ mang về',
                    value: item.soVoMangVe != null ? '${item.soVoMangVe}' : '-',
                    color: Colors.blueGrey,
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

// ── Tab 3: Thu tiền ─────────────────────────────────────────────────────────

class _TabThuTien extends StatelessWidget {
  final ChuyenXeModel cx;
  const _TabThuTien({required this.cx});

  /// Dựng số liệu tạm tính từ cx.banHang/cx.banHangThanhToan/cx.banHangGasDu khi kế toán chưa duyệt.
  KetThucChuyenXeModel _ketThucTamTinh() {
    final tienMat = cx.banHangThanhToan.fold<double>(0, (s, t) => s + t.tienMat);
    final tienCK = cx.banHangThanhToan.fold<double>(0, (s, t) => s + t.tienCK);
    final tongTienNop = tienMat + tienCK;
    final soVoThu = cx.banHang.fold<int>(0, (s, b) => s + b.soVoThu);
    final tongTienTraGasDu =
        cx.banHangGasDu.fold<double>(0, (s, g) => s + g.thanhTien);
    return KetThucChuyenXeModel(
      id: 0,
      ngayKetThuc: cx.updatedAt,
      tienMat: tienMat,
      tienCK: tienCK,
      tongTienNop: tongTienNop,
      // no = tien hang ban - tien mua gas du (da tra khach) - tien da thu (mat + ck)
      // truoc day thieu tru tongTienTraGasDu du bien nay da tinh san o tren, gay hien thi no sai
      soTienNo: (cx.tongTienThu - tongTienTraGasDu - tongTienNop) < 0
          ? 0
          : cx.tongTienThu - tongTienTraGasDu - tongTienNop,
      soVoThuThucTe: soVoThu,
      tienUngMuaVo: 0,
      soVoMua: 0,
      tongTienTraGasDu: tongTienTraGasDu,
      tongThuNoCu: 0,
      chiTiet: const [],
      voThu: const [],
      gasDu: const [],
      traNoCu: const [],
      anhBanKe: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final daDuyet = cx.ketThuc != null;
    final kt = cx.ketThuc ?? (cx.banHang.isNotEmpty ? _ketThucTamTinh() : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
      child: kt == null
          ? _EmptyState(
              icon: Icons.payments_outlined,
              label: 'Chuyến chưa kết thúc')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!daDuyet) ...[
                  const _GhiChuTamTinh(),
                  const SizedBox(height: 12),
                ],
                if (kt.ngayKetThuc != null) ...[
                  _InfoChip(
                      icon: Icons.check_circle_outline,
                      label: 'Kết thúc lúc',
                      value: _fmtDate.format(kt.ngayKetThuc!.toLocal()),
                      color: Colors.green),
                  const SizedBox(height: 12),
                ],

                // Tổng tiền nộp
                _SectionCard(
                  title: 'Tiền nộp',
                  child: Column(
                    children: [
                      _InfoRow(
                          icon: Icons.money,
                          label: 'Tiền mặt',
                          value: _fmtCurrency.format(kt.tienMat)),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.account_balance_outlined,
                          label: 'Chuyển khoản',
                          value: _fmtCurrency.format(kt.tienCK)),
                      const Divider(height: 20),
                      _InfoRow(
                          icon: Icons.summarize_outlined,
                          label: 'Tổng nộp',
                          value: _fmtCurrency.format(kt.tongTienNop),
                          bold: true,
                          valueColor: const Color(0xFF00897B)),
                      if (kt.soTienNo > 0) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                            icon: Icons.warning_amber_outlined,
                            label: 'Còn nợ',
                            value: _fmtCurrency.format(kt.soTienNo),
                            bold: true,
                            valueColor: Colors.red),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Vỏ bình
                _SectionCard(
                  title: 'Vỏ bình',
                  child: Column(
                    children: [
                      _InfoRow(
                          icon: Icons.recycling_rounded,
                          label: 'Vỏ thu thực tế',
                          value: '${kt.soVoThuThucTe} bình'),
                      if (kt.soVoMua > 0) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                            icon: Icons.add_shopping_cart_outlined,
                            label: 'Vỏ mua thêm',
                            value: '${kt.soVoMua} bình'),
                        const SizedBox(height: 8),
                        _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Tiền ứng mua vỏ',
                            value: _fmtCurrency.format(kt.tienUngMuaVo)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Các khoản trả lại
                if (kt.tongTienTraGasDu > 0 || kt.tongThuNoCu > 0)
                  _SectionCard(
                    title: 'Các khoản khác',
                    child: Column(
                      children: [
                        if (kt.tongTienTraGasDu > 0)
                          _InfoRow(
                              icon: Icons.local_gas_station_outlined,
                              label: 'Tiền trả gas dư',
                              value: _fmtCurrency.format(kt.tongTienTraGasDu),
                              valueColor: Colors.orange),
                        if (kt.tongTienTraGasDu > 0 && kt.tongThuNoCu > 0)
                          const SizedBox(height: 8),
                        if (kt.tongThuNoCu > 0)
                          _InfoRow(
                              icon: Icons.receipt_long_outlined,
                              label: 'Thu nợ cũ',
                              value: _fmtCurrency.format(kt.tongThuNoCu),
                              valueColor: Colors.purple),
                      ],
                    ),
                  ),

                if (kt.ghiChu != null && kt.ghiChu!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Ghi chú',
                    child: Text(kt.ghiChu!,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Tab 4: Ảnh xác nhận ─────────────────────────────────────────────────────

class _TabAnh extends StatelessWidget {
  final ChuyenXeModel cx;
  final bool uploading;
  final VoidCallback onUpload;
  final bool uploadingBanKe;
  final int uploadedBanKeCount;
  final int totalBanKeToUpload;
  final VoidCallback onChupAnhBanKe;
  final VoidCallback onChonNhieuAnhBanKe;
  final void Function(int anhId) onXoaAnhBanKe;

  const _TabAnh({
    required this.cx,
    required this.uploading,
    required this.onUpload,
    required this.uploadingBanKe,
    required this.uploadedBanKeCount,
    required this.totalBanKeToUpload,
    required this.onChupAnhBanKe,
    required this.onChonNhieuAnhBanKe,
    required this.onXoaAnhBanKe,
  });

  /// Mở dialog xem ảnh toàn màn hình, cho phép swipe và pinch-to-zoom.
  static void _showFullScreen(BuildContext context, String baseUrl,
      List<AnhChuyenXeModel> anhs, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullScreenGallery(
        baseUrl: baseUrl,
        anhs: anhs,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl =
        AppConstants.resolvedApiUrl.replaceFirst(RegExp(r'/apimanager$'), '');
    final canUpload = !uploading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress badge
          Row(
            children: [
              _SectionLabel('Ảnh xác nhận giao hàng'),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cx.anh.length >= 2
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cx.anh.length}/2',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cx.anh.length >= 2 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ảnh grid hoặc empty state
          if (cx.anh.isEmpty)
            _EmptyState(
                icon: Icons.camera_alt_outlined,
                label: 'Chưa có ảnh. Nhấn nút bên dưới để upload.')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: cx.anh.length,
              itemBuilder: (_, i) {
                final anh = cx.anh[i];
                return GestureDetector(
                  onTap: () => _showFullScreen(context, baseUrl, cx.anh, i),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '$baseUrl${anh.url}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                      // Overlay zoom hint góc trên phải
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _fmtDate.format(anh.uploadedAt.toLocal()),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          if (cx.anh.length >= 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text(
                  'Đã đủ 2 ảnh xác nhận',
                  style:
                      TextStyle(color: Colors.green.shade600, fontSize: 13),
                ),
              ],
            ),
          ],

          // Nút upload
          if (cx.anh.length < 2) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canUpload ? onUpload : null,
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_a_photo),
                label: Text(uploading ? 'Đang upload...' : 'Upload ảnh'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: uploading ? Colors.grey : null,
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),
          _SectionLabel('Ảnh xác nhận khách hàng'),
          const SizedBox(height: 12),
          _XacNhanKhachHangSection(cx: cx, baseUrl: baseUrl),

          const SizedBox(height: 28),
          _AnhBanKeSection(
            cx: cx,
            baseUrl: baseUrl,
            uploading: uploadingBanKe,
            uploadedCount: uploadedBanKeCount,
            totalToUpload: totalBanKeToUpload,
            onChupAnh: onChupAnhBanKe,
            onChonNhieuAnh: onChonNhieuAnhBanKe,
            onXoaAnh: onXoaAnhBanKe,
          ),
        ],
      ),
    );
  }
}

// Ảnh bản kê xác nhận (bản kê giấy đã in và ký, chụp lại sau khi kế toán phê duyệt chuyến xe)
class _AnhBanKeSection extends StatelessWidget {
  final ChuyenXeModel cx;
  final String baseUrl;
  final bool uploading;
  final int uploadedCount;
  final int totalToUpload;
  final VoidCallback onChupAnh;
  final VoidCallback onChonNhieuAnh;
  final void Function(int anhId) onXoaAnh;

  const _AnhBanKeSection({
    required this.cx,
    required this.baseUrl,
    required this.uploading,
    required this.uploadedCount,
    required this.totalToUpload,
    required this.onChupAnh,
    required this.onChonNhieuAnh,
    required this.onXoaAnh,
  });

  @override
  Widget build(BuildContext context) {
    final ketThuc = cx.ketThuc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel('Bản kê xác nhận'),
            const Spacer(),
            if (ketThuc != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ketThuc.anhBanKe.isNotEmpty
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ketThuc.anhBanKe.isNotEmpty ? '${ketThuc.anhBanKe.length} ảnh' : '⚠ Chưa có',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ketThuc.anhBanKe.isNotEmpty ? Colors.green : Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (ketThuc == null)
          _EmptyState(
            icon: Icons.pending_actions_outlined,
            label: 'Chuyến xe chưa được kế toán phê duyệt/chốt số liệu.',
          )
        else ...[
          if (ketThuc.anhBanKe.isEmpty)
            _EmptyState(
              icon: Icons.receipt_long_outlined,
              label: 'Chưa có ảnh bản kê. Chụp lại bản kê đã in và ký để lưu trữ.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: ketThuc.anhBanKe.length,
              itemBuilder: (_, i) {
                final anh = ketThuc.anhBanKe[i];
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
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                anh.nguoiUpload,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onXoaAnh(anh.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          if (uploading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(totalToUpload > 1
                    ? 'Đang upload $uploadedCount/$totalToUpload...'
                    : 'Đang upload...'),
              ],
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : onChupAnh,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : onChonNhieuAnh,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Chọn nhiều ảnh'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Danh sách ảnh biên lai / chữ ký xác nhận, group theo khách hàng (bản mới nhất mỗi khách)
class _XacNhanKhachHangSection extends StatelessWidget {
  final ChuyenXeModel cx;
  final String baseUrl;
  const _XacNhanKhachHangSection({required this.cx, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final xacNhanMap = <int, XacNhanKhachHangModel>{};
    for (final xn in cx.xacNhan) {
      final existing = xacNhanMap[xn.khachHangId];
      if (existing == null || xn.id > existing.id) {
        xacNhanMap[xn.khachHangId] = xn;
      }
    }
    final entries = xacNhanMap.values.where((xn) => xn.coAnh || xn.coChuKy).toList()
      ..sort((a, b) => (b.ngayXacNhan ?? DateTime(0)).compareTo(a.ngayXacNhan ?? DateTime(0)));

    if (entries.isEmpty) {
      return _EmptyState(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Chưa có ảnh xác nhận nào từ khách hàng.');
    }

    return Column(
      children: entries.map((xn) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      xn.tenKhachHang ?? 'KH#${xn.khachHangId}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (xn.ngayXacNhan != null)
                    Text(
                      _fmtDate.format(xn.ngayXacNhan!.toLocal()),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (xn.coAnh)
                    _thumb(context, xn.anhUrl!,
                        label: 'Biên lai', icon: Icons.image_outlined),
                  if (xn.coChuKy)
                    _thumb(context, xn.chuKyUrl!,
                        label: 'Chữ ký', icon: Icons.draw_outlined),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _thumb(BuildContext context, String relativeUrl,
      {required String label, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: Colors.black87,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: InteractiveViewer(
                  child: Image.network('$baseUrl$relativeUrl', fit: BoxFit.contain),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade100,
                child: Image.network(
                  '$baseUrl$relativeUrl',
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 5: Mua gas dư từ khách hàng ─────────────────────────────────────────

class _TabGasDu extends StatelessWidget {
  final ChuyenXeModel cx;
  const _TabGasDu({required this.cx});

  @override
  Widget build(BuildContext context) {
    final daDuyet = cx.ketThuc != null;
    final gasDu = daDuyet ? cx.ketThuc!.gasDu : cx.banHangGasDu;
    final tongTien = daDuyet
        ? cx.ketThuc!.tongTienTraGasDu
        : gasDu.fold<double>(0, (s, g) => s + g.thanhTien);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gasDu.isEmpty)
            _EmptyState(
                icon: Icons.local_gas_station_outlined,
                label: 'Không có mua gas dư trong chuyến này')
          else ...[
            if (!daDuyet) ...[
              const _GhiChuTamTinh(),
              const SizedBox(height: 8),
            ],
            _SummaryRow(
                label: 'Tổng tiền trả KH',
                value: _fmtCurrency.format(tongTien),
                valueColor: Colors.orange),
            const SizedBox(height: 12),
            _SectionLabel('Chi tiết gas dư'),
            const SizedBox(height: 8),
            ...gasDu.map((g) => _GasDuCard(item: g)),
          ],
        ],
      ),
    );
  }
}

// Card một dòng gas dư.
class _GasDuCard extends StatelessWidget {
  final GasDuChiTietModel item;
  const _GasDuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store_outlined,
                    size: 18, color: Color(0xFF00897B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tenKhachHang ?? 'Khách hàng #${item.khachHangId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Text(
                  _fmtCurrency.format(item.thanhTien),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DataChip(
                      label: 'Mặt hàng',
                      value: item.tenMatHang ?? 'ID ${item.matHangId}'),
                ),
                _DataChip(
                    label: 'Số kg',
                    value: '${item.soKg} kg'),
                const SizedBox(width: 8),
                _DataChip(
                    label: 'Đ/kg',
                    value: _fmtCurrency.format(item.donGia)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 6: Trả nợ ─────────────────────────────────────────────────────────

class _TabThuNo extends StatefulWidget {
  final ChuyenXeModel cx;
  const _TabThuNo({required this.cx});

  @override
  State<_TabThuNo> createState() => _TabThuNoState();
}

class _TabThuNoState extends State<_TabThuNo> {
  final _repo = CongNoRepository();
  Map<int, List<CongNoChuyenXeModel>> _congNoMap = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Lấy danh sách khách hàng từ banHang
    final khIds = widget.cx.banHang
        .map((b) => b.khachHangId)
        .toSet()
        .toList();
    if (khIds.isEmpty) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait(
        khIds.map((id) => _repo.getDuNo(id).then((list) => MapEntry(id, list))),
      );
      setState(() {
        _congNoMap = Map.fromEntries(results);
      });
    } catch (e) {
      debugPrint('[TabThuNo] Lỗi load: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final khachHangs = widget.cx.banHang
        .map((b) => b.khachHangId)
        .toSet()
        .where((id) => (_congNoMap[id] ?? []).isNotEmpty)
        .toList();

    if (_congNoMap.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        label: 'Không có lịch sử công nợ',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
        children: [
          for (final khId in khachHangs) ...[
            _buildKhachHangSection(context, khId),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildKhachHangSection(BuildContext context, int khId) {
    final tenKH = widget.cx.banHang
        .firstWhere((b) => b.khachHangId == khId,
            orElse: () => widget.cx.banHang.first)
        .tenKhachHang ?? 'KH#$khId';
    final nos = _congNoMap[khId] ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(tenKH,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
          ),
          for (final no in nos) (() {
            final daTra = no.daTra > 0;
            final conNo = no.conNo;
            final daTraXong = conNo <= 0;
            final ngay = DateTime.tryParse(no.ngayXuat);
            final ngayHienThi = ngay != null ? _fmtDateOnly.format(ngay) : no.ngayXuat;
            return ListTile(
              dense: true,
              title: Text('${no.maChuyenXe} — $ngayHienThi',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                'Nợ gốc: ${_fmtCurrency.format(no.soTienNo)}'
                '${daTra ? '  |  Đã trả: ${_fmtCurrency.format(no.daTra)}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: daTraXong
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Đã trả',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_fmtCurrency.format(conNo),
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('còn nợ',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
              onTap: daTraXong ? null : () => _showTraNoBottomSheet(context, khId, no),
            );
          })(),
        ],
      ),
    );
  }

  // Format số có dấu chấm nghìn và parse ngược lại
  String _fmtInput(String raw) {
    final digits = raw.replaceAll('.', '');
    if (digits.isEmpty) return '';
    final n = int.tryParse(digits) ?? 0;
    return _fmtCurrency.format(n).replaceAll(' ', '').replaceAll('₫', '').trim();
  }

  void _showTraNoBottomSheet(
      BuildContext context, int khachHangId, CongNoChuyenXeModel no) {
    final soTienCtrl = TextEditingController();
    final ghiChuCtrl = TextEditingController();
    String hinhThuc = 'tien-mat';
    int taiKhoanId = 0;
    List<Map<String, dynamic>> tkList = [];

    // Load tài khoản ngân hàng
    _repo.getTaiKhoanNganHang().then((list) {
      tkList = list;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trả nợ — ${no.maChuyenXe}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Còn nợ: ${_fmtCurrency.format(no.conNo)}',
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: soTienCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền trả (đ)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixText: 'đ',
                ),
                onChanged: (v) {
                  final formatted = _fmtInput(v);
                  soTienCtrl.value = soTienCtrl.value.copyWith(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: hinhThuc,
                decoration: const InputDecoration(
                    labelText: 'Hình thức', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'tien-mat', child: Text('Tiền mặt')),
                  DropdownMenuItem(value: 'chuyen-khoan', child: Text('Chuyển khoản')),
                ],
                onChanged: (v) => setBS(() => hinhThuc = v!),
              ),
              if (hinhThuc == 'chuyen-khoan') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: taiKhoanId == 0 ? null : taiKhoanId,
                  decoration: const InputDecoration(
                      labelText: 'Tài khoản CK', border: OutlineInputBorder(), isDense: true),
                  items: tkList.map((tk) => DropdownMenuItem<int>(
                    value: tk['id'] as int,
                    child: Text(tk['tenTaiKhoan'] as String),
                  )).toList(),
                  onChanged: (v) => setBS(() => taiKhoanId = v ?? 0),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: ghiChuCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ghi chú', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Xác nhận trả nợ',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final soTien = double.tryParse(
                            soTienCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
                        0;
                    if (soTien <= 0) return;
                    if (hinhThuc == 'chuyen-khoan' && taiKhoanId == 0) return;
                    try {
                      await _repo.traNo(
                        khachHangId: khachHangId,
                        chuyenXeId: no.chuyenXeId,
                        soTienTra: soTien,
                        hinhThuc: hinhThuc,
                        taiKhoanId: hinhThuc == 'chuyen-khoan' ? taiKhoanId : null,
                        ghiChu: ghiChuCtrl.text.trim().isEmpty ? null : ghiChuCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadAll(); // reload
                    } catch (e) {
                      debugPrint('[TabThuNo] Lỗi trả nợ: $e');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Tổng hợp bán hàng ──────────────────────────────────────────────────────

/// Hiển thị tổng hợp thống kê bán hàng: số bình, vỏ, tiền mặt, CK, nợ, gas dư...
class _BanHangSummaryCard extends StatelessWidget {
  final ChuyenXeModel cx;
  const _BanHangSummaryCard(this.cx);

  @override
  Widget build(BuildContext context) {
    // --- Tính từ cx.banHang ---
    final groups = <int, List<BanHangKhachHangModel>>{};
    for (final b in cx.banHang) {
      groups.putIfAbsent(b.khachHangId, () => []).add(b);
    }

    var tongBinhGas = 0;
    var tongTienPhai = 0.0;

    for (final rows in groups.values) {
      for (final b in rows) {
        if (b.soVoThu == 0 && b.soVoBan == 0) {
          tongBinhGas += b.soLuong;
          tongTienPhai += b.thanhTien;
        }
      }
    }
    // --- Vỏ / gas dư: dùng aggregate backend (đúng cho cả mobile-kết-thúc lẫn đã duyệt) ---
    final kt = cx.ketThuc;
    final tongGasDu     = cx.tongGasDuKg;      // kg gas dư (kt: KetThuc.GasDu; else: banHangGasDu)
    final tongTienGasDu = cx.tienMuaGasDu;     // tiền mua gas dư (lái xe trả lại khách — phải trừ khỏi tiền phải thu)
    final tongVoAggregate = cx.tongSoVo;       // tổng vỏ thu thực tế
    final tongNoDaTra   = kt?.tongThuNoCu ?? 0.0;

    // Thông tin thanh toán nằm ở list riêng cx.banHangThanhToan — cộng dồn toàn chuyến
    final tongTienMat = cx.banHangThanhToan.fold<double>(0, (s, t) => s + t.tienMat);
    final tongTienCK = cx.banHangThanhToan.fold<double>(0, (s, t) => s + t.tienCK);
    // tien phai thu THUC TE = tien ban hang + dieu chinh + chenh lech vo
    //                        - tien mua gas du (da tra lai khach)
    tongTienPhai += cx.banHangThanhToan
        .fold<double>(0, (s, t) => s + t.dieuChinhTien + t.tienChenhLechVo);
    tongTienPhai -= tongTienGasDu;
    final tongConNo =
        (tongTienPhai - tongTienMat - tongTienCK).clamp(0.0, double.infinity);
    final tongChenhLechVo = cx.banHangThanhToan
        .fold<double>(0, (s, t) => s + t.tienChenhLechVo);
    final tongNoVo = cx.banHangNoVo.fold<int>(0, (s, n) => s + n.soLuong);

    if (cx.banHang.isEmpty && kt == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng hợp bán hàng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- Từ banHang (mọi trạng thái) ---
            _BanHangSummaryRow('Số bình gas', '$tongBinhGas bình'),
            _BanHangSummaryRow('Số vỏ thu', '$tongVoAggregate vỏ'),
            _BanHangSummaryRow('Tiền phải thu', _fmtCurrency.format(tongTienPhai),
                bold: true),
            _BanHangSummaryRow('Tiền mặt đã thu', _fmtCurrency.format(tongTienMat)),
            _BanHangSummaryRow(
                'Tiền chuyển khoản', _fmtCurrency.format(tongTienCK)),
            _BanHangSummaryRow('Còn nợ', _fmtCurrency.format(tongConNo),
                color: tongConNo > 0 ? Colors.red.shade700 : null),

            // --- Chênh lệch đổi vỏ / Nợ vỏ (chỉ hiện khi khác 0) ---
            if (tongChenhLechVo != 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _BanHangSummaryRow(
                  'Chênh lệch đổi vỏ', _fmtCurrency.format(tongChenhLechVo),
                  color: tongChenhLechVo < 0
                      ? Colors.red.shade700
                      : Colors.green.shade700),
            ],
            if (tongNoVo > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _BanHangSummaryRow('Nợ vỏ', '$tongNoVo vỏ',
                  color: Colors.orange.shade700),
            ],

            // --- Gas dư (aggregate backend — hiện cho mọi trạng thái nếu có) ---
            if (tongGasDu > 0 || tongTienGasDu > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _BanHangSummaryRow('Gas dư', '${_fmtKg.format(tongGasDu)} kg'),
              _BanHangSummaryRow('Tiền mua gas dư', _fmtCurrency.format(tongTienGasDu)),
            ],

            // --- Nợ cũ đã thu (chỉ khi đã settle) ---
            if (kt != null && tongNoDaTra > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _BanHangSummaryRow('Nợ cũ đã thu', _fmtCurrency.format(tongNoDaTra)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một dòng trong bảng tổng hợp bán hàng (nhãn + giá trị).
class _BanHangSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _BanHangSummaryRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ── Fullscreen gallery ─────────────────────────────────────────────────────

/// Widget xem ảnh toàn màn hình: swipe ngang giữa các ảnh, pinch-to-zoom, timestamp.
class _FullScreenGallery extends StatefulWidget {
  final String baseUrl;
  final List<AnhChuyenXeModel> anhs;
  final int initialIndex;

  const _FullScreenGallery({
    required this.baseUrl,
    required this.anhs,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // PageView cho phép swipe ngang giữa các ảnh
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.anhs.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final anh = widget.anhs[i];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    '${widget.baseUrl}${anh.url}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),

          // Nút đóng góc trên phải
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Indicator X/N + timestamp — góc dưới giữa
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Text(
                    '${_current + 1} / ${widget.anhs.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtDate.format(widget.anhs[_current].uploadedAt.toLocal()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet: chi tiết một khách hàng trong chuyến ────────────────────

class _KhachHangDetailSheet extends StatelessWidget {
  final ChuyenXeModel cx;
  final int khachHangId;
  final String? tenKhachHang;

  const _KhachHangDetailSheet({
    required this.cx,
    required this.khachHangId,
    required this.tenKhachHang,
  });

  @override
  Widget build(BuildContext context) {
    final kt = cx.ketThuc;

    // Lọc dữ liệu của khách hàng này từ dữ liệu chuyến xe sẵn có
    final hangs   = kt?.chiTiet.where((c) => c.khachHangId == khachHangId).toList() ?? [];
    final gasDus  = kt?.gasDu.where((g) => g.khachHangId == khachHangId).toList() ?? [];
    final noCus   = kt?.traNoCu.where((n) => n.khachHangId == khachHangId).toList() ?? [];

    final tongHang  = hangs.fold(0.0, (s, c) => s + c.thanhTien);
    final tongGas   = gasDus.fold(0.0, (s, g) => s + g.thanhTien);
    final tongNo    = noCus.fold(0.0, (s, n) => s + n.soTien);
    final tongCong  = tongHang + tongGas + tongNo;

    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header: tên khách hàng
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: Color(0xFF00695C), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenKhachHang ?? 'Khách hàng #$khachHangId',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      Text(
                        '${cx.tenNhanVien ?? 'Lái xe'} • ${_fmtDateOnly.format(cx.ngayXuat.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Nội dung cuộn được
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hàng mua
                  if (hangs.isNotEmpty) ...[
                    _SheetSection(
                      icon: Icons.inventory_2_outlined,
                      title: 'Hàng mua',
                      color: const Color(0xFF00695C),
                    ),
                    const SizedBox(height: 8),
                    ...hangs.map((c) => _SheetHangRow(item: c)),
                    _SheetSubtotal(label: 'Tổng hàng', amount: tongHang,
                        color: const Color(0xFF00695C)),
                    const SizedBox(height: 16),
                  ],

                  // ── Gas dư mua lại
                  if (gasDus.isNotEmpty) ...[
                    _SheetSection(
                      icon: Icons.local_gas_station_outlined,
                      title: 'Gas dư mua lại',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    ...gasDus.map((g) => _SheetGasDuRow(item: g)),
                    _SheetSubtotal(label: 'Tổng gas dư', amount: tongGas,
                        color: Colors.orange),
                    const SizedBox(height: 16),
                  ],

                  // ── Thu nợ cũ
                  if (noCus.isNotEmpty) ...[
                    _SheetSection(
                      icon: Icons.receipt_long_outlined,
                      title: 'Thu nợ cũ',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    ...noCus.map((n) => _SheetNoCuRow(item: n)),
                    _SheetSubtotal(label: 'Tổng nợ', amount: tongNo,
                        color: Colors.purple),
                    const SizedBox(height: 16),
                  ],

                  // ── Tổng cộng
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền thu',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _fmtCurrency.format(tongCong),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tiêu đề section trong sheet
class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SheetSection(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// Một dòng hàng mua
class _SheetHangRow extends StatelessWidget {
  final KetThucChiTietModel item;
  const _SheetHangRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.tenMatHang ?? 'Mặt hàng #${item.matHangId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(
                _fmtCurrency.format(item.thanhTien),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00695C),
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _DataChip(label: 'SL', value: '${item.soLuong} bình'),
              const SizedBox(width: 8),
              _DataChip(
                  label: 'Đ/bình',
                  value: _fmtCurrency.format(item.donGia)),
              if (item.soVoThu > 0) ...[
                const SizedBox(width: 8),
                _DataChip(
                    label: 'Vỏ thu',
                    value: '${item.soVoThu}',
                    color: Colors.teal),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Một dòng gas dư
class _SheetGasDuRow extends StatelessWidget {
  final GasDuChiTietModel item;
  const _SheetGasDuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tenMatHang ?? 'Mặt hàng #${item.matHangId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _DataChip(label: 'Số kg', value: '${item.soKg} kg'),
                    const SizedBox(width: 8),
                    _DataChip(
                        label: 'Đ/kg',
                        value: _fmtCurrency.format(item.donGia)),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _fmtCurrency.format(item.thanhTien),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.orange,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Một dòng thu nợ cũ
class _SheetNoCuRow extends StatelessWidget {
  final TraNoCuModel item;
  const _SheetNoCuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nợ cũ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (item.ghiChu != null && item.ghiChu!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.ghiChu!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
          Text(
            _fmtCurrency.format(item.soTien),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.purple,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Dòng tổng phụ mỗi section
class _SheetSubtotal extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SheetSubtotal(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
          Text(
            _fmtCurrency.format(amount),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

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
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Card bao quanh một nhóm thông tin với tiêu đề.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề section nhỏ.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey));
  }
}

/// Hàng tóm tắt nổi bật (label — value).
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (valueColor ?? const Color(0xFF00897B)).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: valueColor ?? const Color(0xFF00897B))),
        ],
      ),
    );
  }
}

/// Hàng thông tin với icon — label: value.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label:',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip thông tin nhỏ trong card chi tiết.
class _DataChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _DataChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF00897B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: c.withValues(alpha: 0.7))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c)),
        ],
      ),
    );
  }
}

/// Chip icon + label nhỏ dùng trong stats footer của customer card.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      );
}

/// Chip thông tin với icon + label + value theo hàng ngang.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: color)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

/// Trạng thái rỗng (empty state) cho các tab không có dữ liệu.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 56, color: Colors.black26),
            const SizedBox(height: 14),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
