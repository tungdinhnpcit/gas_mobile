// lib/features/tong_quan/presentation/screens/dai_ly_chi_tiet_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../khach_hang/data/models/khach_hang_model.dart';
import '../../../khach_hang/presentation/providers/khach_hang_provider.dart';
import '../../data/models/tong_quan_model.dart';
import '../providers/tong_quan_provider.dart';

final _vnd  = NumberFormat('#,###', 'vi_VN');
final _num  = NumberFormat('#,###');
final _date = DateFormat('dd/MM/yyyy');

class DaiLyChiTietScreen extends ConsumerStatefulWidget {
  final int khachHangId;
  final DateTime? tuNgay;
  final DateTime? denNgay;
  const DaiLyChiTietScreen({
    super.key,
    required this.khachHangId,
    this.tuNgay,
    this.denNgay,
  });

  @override
  ConsumerState<DaiLyChiTietScreen> createState() => _DaiLyChiTietScreenState();
}

class _DaiLyChiTietScreenState extends ConsumerState<DaiLyChiTietScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _tuNgay;
  late DateTime _denNgay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _tuNgay  = widget.tuNgay ?? today;
    _denNgay = widget.denNgay ?? today;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _tuNgay : _denNgay;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Text(isFrom ? 'Từ ngày' : 'Đến ngày',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              CalendarDatePicker(
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateChanged: (picked) {
                  setState(() {
                    if (isFrom) {
                      _tuNgay = picked;
                      if (_tuNgay.isAfter(_denNgay)) _denNgay = _tuNgay;
                    } else {
                      _denNgay = picked;
                      if (_denNgay.isBefore(_tuNgay)) _tuNgay = _denNgay;
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mở app điện thoại với số đã cho
  Future<void> _goiDienThoai(String sdt) async {
    final uri = Uri.parse('tel:$sdt');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Mở Google Maps chỉ đường theo tọa độ hoặc fallback địa chỉ
  Future<void> _chiDuong({double? lat, double? lng, String? diaChi}) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Platform.isIOS
          ? Uri.parse('maps://?daddr=$lat,$lng')
          : Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    } else if (diaChi != null && diaChi.isNotEmpty) {
      final q = Uri.encodeComponent(diaChi);
      uri = Uri.parse('https://www.google.com/maps/search/?q=$q');
    } else {
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (lat != null && lng != null) {
        final fallback = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final khAsync = ref.watch(khachHangDetailProvider(widget.khachHangId));
    final tenKhachHang = khAsync.valueOrNull?.tenKhachHang ?? 'Đại lý';

    return Scaffold(
      appBar: AppBar(
        title: Text(tenKhachHang, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Bán hàng'),
            Tab(icon: Icon(Icons.info_outline), text: 'Thông tin'),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BanHangTab(
            khachHangId: widget.khachHangId,
            tuNgay: _tuNgay,
            denNgay: _denNgay,
            onPickDate: _pickDate,
          ),
          _ThongTinTab(
            khAsync: khAsync,
            onCall: _goiDienThoai,
            onMap: _chiDuong,
          ),
        ],
      ),
    );
  }
}

// ── Tab Bán hàng ─────────────────────────────────────────────────────────────

class _BanHangTab extends ConsumerWidget {
  final int khachHangId;
  final DateTime tuNgay;
  final DateTime denNgay;
  final Future<void> Function({required bool isFrom}) onPickDate;

  const _BanHangTab({
    required this.khachHangId,
    required this.tuNgay,
    required this.denNgay,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(
      daiLyBanHangProvider((khachHangId, tuNgay, denNgay)),
    );

    return Column(
      children: [
        // ── Date filter ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              _DateBtn(label: 'Từ', date: tuNgay,  onTap: () => onPickDate(isFrom: true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              _DateBtn(label: 'Đến', date: denNgay, onTap: () => onPickDate(isFrom: false)),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Không có giao dịch trong khoảng ngày này',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              final tongTien = list.fold(0.0, (s, x) => s + x.tongTienBan);
              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ChuyenXeCard(item: list[i]),
                    ),
                  ),
                  // Footer tổng cộng
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withValues(alpha: 0.08),
                      border: const Border(top: BorderSide(color: Color(0xFF00897B), width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${list.length} chuyến xe',
                            style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(
                          'Tổng: ${_vnd.format(tongTien)} đ',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00695C)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChuyenXeCard extends StatelessWidget {
  final DaiLyBanHangModel item;
  const _ChuyenXeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: mã chuyến + ngày + badge nợ
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.maChuyenXe,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Text(
                  _date.format(item.ngayXuat.toLocal()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (item.tienNo > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Nợ: ${_vnd.format(item.tienNo)}đ',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 12),
            // Chi tiết mặt hàng
            ...item.chiTiet.map((ct) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(ct.tenMatHang,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${_num.format(ct.soLuong)} bình × ${_vnd.format(ct.giaBan)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )),
            // Tổng tiền chuyến
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_vnd.format(item.tongTienBan)} đ',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00695C)),
              ),
            ),
            // Ảnh xác nhận: biên lai ký tay + chữ ký trên app (nếu có)
            if ((item.anhUrl != null && item.anhUrl!.isNotEmpty) ||
                (item.chuKyUrl != null && item.chuKyUrl!.isNotEmpty)) ...[
              const Divider(height: 16),
              const Text('Xác nhận khách hàng:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.anhUrl != null && item.anhUrl!.isNotEmpty)
                    _XacNhanThumbnail(url: item.anhUrl!, label: 'Ảnh biên lai', icon: Icons.image_outlined),
                  if (item.chuKyUrl != null && item.chuKyUrl!.isNotEmpty)
                    _XacNhanThumbnail(url: item.chuKyUrl!, label: 'Chữ ký', icon: Icons.draw_outlined),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Thumbnail ảnh xác nhận (biên lai/chữ ký) — bấm mở dialog phóng to
class _XacNhanThumbnail extends StatelessWidget {
  final String url;    // đường dẫn tương đối trả về từ API (vd /uploads/xac-nhan/..)
  final String label;  // nhãn hiển thị dưới thumbnail
  final IconData icon; // icon minh họa loại xác nhận

  const _XacNhanThumbnail({required this.url, required this.label, required this.icon});

  // build URL đầy đủ: bỏ suffix /apimanager vì static file serve từ root server
  String get _fullUrl =>
      AppConstants.staticBaseUrl + url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _xemAnh(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 84,
                height: 84,
                color: Colors.grey.shade100,
                child: Image.network(
                  _fullUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
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

  // mở dialog phóng to ảnh, cho phép pinch-to-zoom qua InteractiveViewer
  void _xemAnh(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF00695C)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _fullUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
                  errorBuilder: (c, e, s) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Không tải được ảnh'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Tab Thông tin ─────────────────────────────────────────────────────────────

class _ThongTinTab extends StatelessWidget {
  final AsyncValue<KhachHangModel> khAsync;
  final Future<void> Function(String sdt) onCall;
  final Future<void> Function({double? lat, double? lng, String? diaChi}) onMap;

  const _ThongTinTab({
    required this.khAsync,
    required this.onCall,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    return khAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e.toString(),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      data: (kh) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + tên
                  Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                      child: Text(
                        kh.tenKhachHang.isNotEmpty
                            ? kh.tenKhachHang[0].toUpperCase()
                            : 'K',
                        style: const TextStyle(
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kh.maKhachHang,
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(kh.tenKhachHang,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ]),
                  const Divider(height: 24),
                  if (kh.diaChi != null)
                    _InfoRow(icon: Icons.location_on_outlined, label: 'Địa chỉ', value: kh.diaChi!),
                  if (kh.soDienThoai != null)
                    _InfoRow(icon: Icons.phone_outlined, label: 'SĐT', value: kh.soDienThoai!),
                  if (kh.email != null)
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: kh.email!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (kh.soDienThoai != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onCall(kh.soDienThoai!),
                icon: const Icon(Icons.phone),
                label: Text('Gọi ${kh.soDienThoai}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  side: const BorderSide(color: Color(0xFF00897B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (kh.diaChi != null || kh.hasLocation) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onMap(
                  lat: kh.latitude,
                  lng: kh.longitude,
                  diaChi: kh.diaChi,
                ),
                icon: const Icon(Icons.directions),
                label: const Text('Chỉ đường'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateBtn({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(_date.format(date),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
