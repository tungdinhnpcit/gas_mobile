// lib/features/lo_trinh/presentation/screens/lo_trinh_list_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/vietnamese_text.dart';
import '../../data/models/lo_trinh_model.dart';
import '../../services/lo_trinh_tracking_service.dart';
import '../providers/lo_trinh_provider.dart';
import '../widgets/doi_ten_lo_trinh_dialog.dart';

/// Danh sách lộ trình (root navigator — có Scaffold/AppBar riêng, không hiện bottom tabs):
/// lọc theo ngày tạo, tạo lộ trình mới, xoá lộ trình.
class LoTrinhListScreen extends ConsumerStatefulWidget {
  const LoTrinhListScreen({super.key});

  @override
  ConsumerState<LoTrinhListScreen> createState() => _LoTrinhListScreenState();
}

class _LoTrinhListScreenState extends ConsumerState<LoTrinhListScreen> {
  bool _dangXoa = false;
  final _timKiemCtrl = TextEditingController();
  String _tuKhoa = ''; // đã bỏ dấu + lowercase

  @override
  void dispose() {
    _timKiemCtrl.dispose();
    super.dispose();
  }

  /// Áp dụng từ khoá đang nhập để lọc danh sách theo tên (không phân biệt hoa thường/dấu).
  void _timKiem() {
    FocusScope.of(context).unfocus();
    setState(() => _tuKhoa = removeDiacritics(_timKiemCtrl.text.trim()));
  }

  /// Xoá từ khoá, hiện lại toàn bộ danh sách.
  void _xoaTimKiem() {
    _timKiemCtrl.clear();
    _timKiem();
  }

  /// Lọc lộ trình có tên chứa từ khoá; lộ trình chưa đặt tên không khớp khi đang tìm.
  List<LoTrinhModel> _locTheoTen(List<LoTrinhModel> items) {
    if (_tuKhoa.isEmpty) return items;
    return items.where((lt) => removeDiacritics(lt.ten ?? '').contains(_tuKhoa)).toList();
  }

  /// Mở bộ chọn khoảng ngày và cập nhật bộ lọc.
  Future<void> _chonNgay() async {
    final f = ref.read(loTrinhFilterProvider);
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: f.tuNgay, end: f.denNgay),
    );
    if (r != null) ref.read(loTrinhFilterProvider.notifier).state = (tuNgay: r.start, denNgay: r.end);
  }

  /// Đặt nhanh bộ lọc N ngày gần nhất (tính cả hôm nay).
  void _locNhanh(int soNgay) {
    final now = DateTime.now();
    final homNay = DateTime(now.year, now.month, now.day);
    ref.read(loTrinhFilterProvider.notifier).state =
        (tuNgay: homNay.subtract(Duration(days: soNgay - 1)), denNgay: now);
  }

  /// Mở màn ghi lộ trình; khi quay về thì tải lại danh sách.
  Future<void> _taoMoi() async {
    await context.push(AppRoutes.loTrinhGhi);
    if (mounted) ref.invalidate(loTrinhListProvider);
  }

  /// Mở hộp thoại đổi tên lộ trình, gọi API rồi tải lại danh sách.
  Future<void> _doiTen(LoTrinhModel lt) async {
    final ten = await showDoiTenLoTrinhDialog(context, tenHienTai: lt.ten, tieuDe: 'Đổi tên lộ trình');
    if (ten == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loTrinhRepositoryProvider).doiTen(lt.id, ten);
      ref.invalidate(loTrinhListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu tên lộ trình'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(loiDoiTen(e)), backgroundColor: Colors.red));
    }
  }

  /// Xác nhận rồi xoá lộ trình; trả true nếu xoá thành công (dùng cho Dismissible).
  Future<bool> _xoa(LoTrinhModel lt) async {
    final messenger = ScaffoldMessenger.of(context);
    if (lt.dangGhi) {
      messenger.showSnackBar(const SnackBar(content: Text('Hãy kết thúc lộ trình trước khi xoá')));
      return false;
    }
    if (_dangXoa) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá lộ trình?'),
        content: const Text('Lộ trình và toàn bộ điểm GPS sẽ bị xoá vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    setState(() => _dangXoa = true);
    try {
      await ref.read(loTrinhRepositoryProvider).delete(lt.id);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá lộ trình'), backgroundColor: Colors.green));
      ref.invalidate(loTrinhListProvider);
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map && data['message'] != null ? data['message'].toString() : 'Xoá thất bại';
      messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      return false;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Xoá thất bại: $e'), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted) setState(() => _dangXoa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(loTrinhFilterProvider);
    // Lọc theo từ khoá tên ngay trên dữ liệu đã tải theo khoảng ngày
    final async = ref.watch(loTrinhListProvider).whenData(_locTheoTen);
    final dangGhi = ref.watch(loTrinhTrackingProvider).dangGhi;
    final dfNgay = DateFormat('dd/MM/yyyy');
    final dfGio = DateFormat('HH:mm dd/MM');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ trình'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lo_trinh_tao_moi',
        onPressed: _taoMoi,
        backgroundColor: dangGhi ? Colors.orange : null,
        icon: Icon(dangGhi ? Icons.radio_button_checked : Icons.add),
        label: Text(dangGhi ? 'Đang ghi — mở' : 'Tạo lộ trình'),
      ),
      body: Column(children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: Text('${dfNgay.format(f.tuNgay)} – ${dfNgay.format(f.denNgay)}'),
          subtitle: const Text('Lọc theo ngày tạo'),
          trailing: const Icon(Icons.edit_calendar),
          onTap: _chonNgay,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final (soNgay, nhan) in const [(1, 'Hôm nay'), (7, '7 ngày'), (30, '30 ngày')])
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: ActionChip(label: Text(nhan), onPressed: () => _locNhanh(soNgay)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _timKiemCtrl,
                builder: (_, v, __) => TextField(
                  controller: _timKiemCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _timKiem(),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên lộ trình',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: v.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.clear), onPressed: _xoaTimKiem),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _timKiem,
              icon: const Icon(Icons.search),
              label: const Text('Tìm'),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (_dangXoa) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(loTrinhListProvider.future),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text('Lỗi tải dữ liệu: $e')),
              ]),
              data: (items) => items.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(_tuKhoa.isEmpty
                              ? 'Chưa có lộ trình nào trong khoảng ngày này.'
                              : 'Không tìm thấy lộ trình có tên phù hợp.'),
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88), // chừa chỗ cho FAB
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final lt = items[i];
                        return Dismissible(
                          key: ValueKey('lo_trinh_${lt.id}'),
                          direction: lt.dangGhi ? DismissDirection.none : DismissDirection.endToStart,
                          // Luôn trả false: danh sách được reload từ provider sau khi xoá,
                          // tránh lỗi "dismissed Dismissible is still part of the tree".
                          confirmDismiss: (_) async {
                            await _xoa(lt);
                            return false;
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: lt.dangGhi ? Colors.orange.shade100 : Colors.blue.shade50,
                              child: Icon(lt.dangGhi ? Icons.radio_button_checked : Icons.route,
                                  color: lt.dangGhi ? Colors.orange : Colors.blue),
                            ),
                            title: Text(
                                lt.ten?.isNotEmpty == true ? lt.ten! : 'Lộ trình ${dfGio.format(lt.batDauLuc)}'),
                            subtitle: Text([
                              fmtQuangDuong(lt.tongQuangDuongM),
                              fmtThoiLuong(lt.thoiLuong),
                              if (lt.dangGhi) 'Đang ghi',
                              if (lt.tenNhanVien != null) lt.tenNhanVien!,
                            ].join(' • ')),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'xoa') _xoa(lt);
                                if (v == 'doi_ten') _doiTen(lt);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'doi_ten',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Đổi tên'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'xoa',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline, color: Colors.red),
                                    title: Text('Xoá'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => context.push(AppRoutes.loTrinhDetail(lt.id)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}
