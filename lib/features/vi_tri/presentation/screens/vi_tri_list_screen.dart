// lib/features/vi_tri/presentation/screens/vi_tri_list_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../data/models/vi_tri_chia_se_model.dart';
import '../providers/vi_tri_provider.dart';

/// Danh sách điện thoại đang chia sẻ vị trí.
/// Nằm trong ShellRoute nên KHÔNG bọc Scaffold/AppBar (xem rules mobile_screen_navigation).
class ViTriListScreen extends ConsumerStatefulWidget {
  const ViTriListScreen({super.key});

  @override
  ConsumerState<ViTriListScreen> createState() => _ViTriListScreenState();
}

class _ViTriListScreenState extends ConsumerState<ViTriListScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tự làm mới mỗi 30 giây để thấy vị trí/thời gian cập nhật mới
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(viTriListProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(viTriListProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(viTriListProvider.future),
      child: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 120),
          Center(child: Text('Lỗi tải danh sách: $e', textAlign: TextAlign.center)),
        ]),
        data: (list) => list.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.location_off_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('Chưa có điện thoại nào đang chia sẻ vị trí')),
              ])
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) => _ViTriTile(item: list[i]),
              ),
      ),
    );
  }
}

class _ViTriTile extends StatelessWidget {
  final ViTriChiaSeModel item;
  const _ViTriTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cu = item.isCu;
    final mau = cu ? Colors.grey : Colors.green;
    final avatar = item.avatarUrl?.isNotEmpty == true ? '${AppConstants.staticBaseUrl}${item.avatarUrl}' : null;
    return ListTile(
      leading: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.teal.shade100,
          backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
          child: avatar == null
              ? Text(item.tenHienThi.isNotEmpty ? item.tenHienThi[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold))
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: mau,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ]),
      title: Text(item.tenHienThi, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.deviceInfo?.isNotEmpty == true)
          Text(item.deviceInfo!, style: Theme.of(context).textTheme.bodySmall),
        Text(
          cu ? 'Mất tín hiệu · cập nhật ${item.capNhatLuc}' : 'Cập nhật ${item.capNhatLuc}',
          style: TextStyle(fontSize: 12, color: cu ? Colors.orange.shade800 : Colors.green.shade700),
        ),
      ]),
      isThreeLine: item.deviceInfo?.isNotEmpty == true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.viTriDetail(item.id)),
    );
  }
}
