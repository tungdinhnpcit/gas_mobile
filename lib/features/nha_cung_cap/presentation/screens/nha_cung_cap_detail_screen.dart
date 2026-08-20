// lib/features/nha_cung_cap/presentation/screens/nha_cung_cap_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/nha_cung_cap_provider.dart';

class NhaCungCapDetailScreen extends ConsumerWidget {
  const NhaCungCapDetailScreen({super.key, required this.nhaCungCapId});
  final int nhaCungCapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nhaCungCapDetailProvider(nhaCungCapId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết nhà cung cấp')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Không tải được thông tin')),
        data: (ncc) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.business_rounded,
                              color: Color(0xFF00897B), size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${ncc.maNCC} - ${ncc.tenNCC}',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (ncc.isActive
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444))
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  ncc.isActive ? 'Đang hợp tác' : 'Ngừng hợp tác',
                                  style: TextStyle(
                                    color: ncc.isActive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin liên hệ',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                        const Divider(height: 16),
                        _InfoRow(Icons.person_outline, 'Người liên hệ',
                            ncc.nguoiLienHe ?? '—'),
                        _InfoRow(Icons.phone_outlined, 'Điện thoại',
                            ncc.soDienThoai ?? '—'),
                        _InfoRow(Icons.email_outlined, 'Email', ncc.email ?? '—'),
                        _InfoRow(Icons.location_on_outlined, 'Địa chỉ',
                            ncc.diaChi ?? '—'),
                        _InfoRow(Icons.access_time_outlined, 'Ngày tạo',
                            DateFormat('dd/MM/yyyy').format(ncc.createdAt.toLocal())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
