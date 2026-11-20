// lib/features/lich_tuan/presentation/screens/lich_tuan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/notification_service.dart';
import '../../domain/entities/lich_tuan_entity.dart';
import '../providers/lich_tuan_provider.dart';

/// Màn Lịch tuần (nằm trong ShellRoute — AppBar do _MainShell cung cấp).
/// Gồm thanh chọn tuần + 5 tab: Của tôi, Lãnh đạo, Của ban, Khác, Lịch xe.
class LichTuanScreen extends ConsumerStatefulWidget {
  const LichTuanScreen({super.key});

  @override
  ConsumerState<LichTuanScreen> createState() => _LichTuanScreenState();
}

class _LichTuanScreenState extends ConsumerState<LichTuanScreen> {
  final _rangeFmt = DateFormat('dd/MM');
  final _yearFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Chỉ lên nhắc lịch cho lịch cá nhân — lịch chung đơn vị không nhắc
    ref.listenManual(lichTuanProvider(LichTuanLoai.caNhan), (_, next) {
      next.whenData(NotificationService.scheduleWeeklyScheduleReminders);
    });
  }

  /// Dịch khoảng đang xem sang tuần trước/sau theo số tuần [delta]
  void _shiftWeek(int delta) {
    final cur = ref.read(lichTuanRangeProvider);
    ref.read(lichTuanRangeProvider.notifier).state =
        weekOf(cur.start.add(Duration(days: 7 * delta)));
  }

  /// Mở hộp chọn khoảng ngày tuỳ ý
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: ref.read(lichTuanRangeProvider),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      ref.read(lichTuanRangeProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(lichTuanRangeProvider);
    final cs = Theme.of(context).colorScheme;
    final isThisWeek = range.start == weekOf(DateTime.now()).start &&
        range.end == weekOf(DateTime.now()).end;

    return DefaultTabController(
      length: LichTuanLoai.values.length,
      child: Column(
        children: [
          // Thanh chọn tuần
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Tuần trước',
                  onPressed: () => _shiftWeek(-1),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickDateRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month,
                              size: 18, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${_rangeFmt.format(range.start)} – ${_yearFmt.format(range.end)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isThisWeek)
                  TextButton(
                    onPressed: () => ref
                        .read(lichTuanRangeProvider.notifier)
                        .state = weekOf(DateTime.now()),
                    child: const Text('Tuần này'),
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Tuần sau',
                  onPressed: () => _shiftWeek(1),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final l in LichTuanLoai.values) Tab(text: l.label)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final l in LichTuanLoai.values) _LichTuanList(loai: l),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Danh sách lịch của một tab, nhóm theo ngày, có kéo xuống để làm mới
class _LichTuanList extends ConsumerWidget {
  const _LichTuanList({required this.loai});
  final LichTuanLoai loai;

  static final _dayFmt = DateFormat('EEEE, dd/MM/yyyy', 'vi');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(lichTuanGroupedProvider(loai));
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<void> refresh() => ref.refresh(lichTuanProvider(loai).future);

    return groupedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Không tải được lịch\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(lichTuanProvider(loai)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (grouped) {
        final dates = grouped.keys.toList()..sort();
        return RefreshIndicator(
          onRefresh: refresh,
          child: dates.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Không có lịch trong khoảng thời gian này')),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    final events = grouped[date]!;
                    final isToday = date == today;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              if (isToday) ...[
                                Icon(Icons.today,
                                    size: 18, color: cs.onPrimaryContainer),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _dayFmt.format(date).toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isToday
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Text('${events.length} lịch',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isToday
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        ...events.map((e) => _EventCard(
                              event: e,
                              isToday: isToday,
                              isXe: loai == LichTuanLoai.xe,
                            )),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Thẻ một sự kiện lịch — bấm để mở rộng xem chi tiết
class _EventCard extends StatefulWidget {
  const _EventCard(
      {required this.event, required this.isToday, required this.isXe});
  final LichTuanEntity event;
  final bool isToday;
  final bool isXe;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _expanded = false;

  String _ttLabel(String tt) {
    switch (tt) {
      case 'BT':
        return 'Bình thường';
      case 'BS':
        return 'Bổ sung';
      case 'TD':
        return 'Thay đổi';
      default:
        return tt;
    }
  }

  /// Dòng thông tin nhỏ có icon
  Widget _infoRow(IconData icon, String text, {int? maxLines = 1}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: cs.outline),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: _expanded ? null : maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Khối nhãn + nội dung khi mở rộng
  Widget _section(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ]), style: Theme.of(context).textTheme.bodySmall),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.event;
    final htmlStyle = {
      'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(13)),
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      color: widget.isToday ? cs.primaryContainer : cs.surfaceContainerLow,
      elevation: widget.isToday ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: widget.isToday
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.isXe ? Icons.directions_car : Icons.access_time,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(e.gio,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: cs.primary)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('(${e.thoiGian})',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  if (e.isTruyenHinh)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.videocam_outlined,
                          size: 16, color: cs.outline),
                    ),
                  if (e.taiLieuHop)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.attach_file, size: 16, color: cs.outline),
                    ),
                  if (e.tt.isNotEmpty && e.tt != 'BT')
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_ttLabel(e.tt),
                          style: TextStyle(
                              fontSize: 10, color: cs.onTertiaryContainer)),
                    ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: cs.outline),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                e.noiDung,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (e.diaDiem.isNotEmpty)
                _infoRow(Icons.location_on_outlined, e.diaDiem),
              if (e.chuTri.isNotEmpty)
                _infoRow(Icons.person_outline, 'Chủ trì: ${e.chuTri}'),
              // Lịch xe: luôn hiện thông tin xe
              if (widget.isXe && e.chiTietXe.isNotEmpty) ...[
                const Divider(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Expanded(child: Html(data: e.chiTietXe, style: htmlStyle)),
                  ],
                ),
              ],
              if (_expanded) ...[
                const Divider(height: 16),
                if (e.thayDoi.isNotEmpty) _section('Thay đổi', e.thayDoi),
                if (e.dvChuanBi.isNotEmpty)
                  _section('Đơn vị chuẩn bị', e.dvChuanBi),
                if (e.thanhPhanThamGia.isNotEmpty)
                  _section('Thành phần tham gia', e.thanhPhanThamGia),
                if (e.thamGiaChitiet.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Chi tiết tham gia:',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Html(data: e.thamGiaChitiet, style: htmlStyle),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
