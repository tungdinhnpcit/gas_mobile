// lib/features/nha_cung_cap/presentation/screens/nha_cung_cap_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../providers/nha_cung_cap_provider.dart';

class NhaCungCapListScreen extends ConsumerStatefulWidget {
  const NhaCungCapListScreen({super.key});

  @override
  ConsumerState<NhaCungCapListScreen> createState() => _NhaCungCapListScreenState();
}

class _NhaCungCapListScreenState extends ConsumerState<NhaCungCapListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(nhaCungCapListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(nhaCungCapListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm mã, tên nhà cung cấp...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(nhaCungCapListProvider.notifier).load();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onSubmitted: (_) =>
                ref.read(nhaCungCapListProvider.notifier).load(search: _searchCtrl.text.trim()),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(nhaCungCapListProvider.notifier).load(search: _searchCtrl.text.trim()),
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Column(children: [
                      Icon(Icons.business_outlined, size: 64, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('Không có nhà cung cấp nào',
                          style: TextStyle(color: Colors.white38)),
                    ])),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final ncc = list[i];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => ctx.push(AppRoutes.nhaCungCapDetail(ncc.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.business_rounded,
                                    color: Color(0xFF00897B), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${ncc.maNCC} - ${ncc.tenNCC}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (ncc.nguoiLienHe != null) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.person_outline,
                                            size: 13, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(ncc.nguoiLienHe!,
                                            style:
                                                const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ]),
                                    ],
                                    if (ncc.soDienThoai != null) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 13, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(ncc.soDienThoai!,
                                            style:
                                                const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),
                              if (!ncc.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Ngừng HĐ',
                                      style: TextStyle(color: Colors.red, fontSize: 10)),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
