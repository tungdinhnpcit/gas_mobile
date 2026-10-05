// lib/features/cai_dat/presentation/screens/dong_bo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/sync_provider.dart';
import '../../../../core/services/sync_service.dart';

/// Màn hình làm mới cache danh mục thủ công. App chỉ chạy online nên không còn
/// phần upload dữ liệu offline; danh mục vẫn tự đồng bộ mỗi lần mở app.
class DongBoScreen extends ConsumerStatefulWidget {
  const DongBoScreen({super.key});

  @override
  ConsumerState<DongBoScreen> createState() => _DongBoScreenState();
}

class _DongBoScreenState extends ConsumerState<DongBoScreen> {
  DateTime? _lastSyncAt;
  bool _catalogSyncing = false;
  String? _lastResult;
  bool _lastIsError = false;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  /// Đọc thời điểm đồng bộ danh mục gần nhất để hiển thị.
  Future<void> _loadLastSync() async {
    final last = await SyncService.instance.lastSyncAt();
    if (mounted) setState(() => _lastSyncAt = last);
  }

  /// Kéo lại toàn bộ danh mục từ server về cache local.
  Future<void> _syncCatalog() async {
    setState(() {
      _catalogSyncing = true;
      _lastResult = null;
    });
    try {
      final result = await ref.read(syncNotifierProvider.notifier).syncCatalog();
      await _loadLastSync();
      if (mounted) {
        setState(() {
          _lastIsError = false;
          _lastResult = result.hasNewItems ? result.summary : 'Danh mục đã cập nhật.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastIsError = true;
          _lastResult = 'Lỗi cập nhật danh mục: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _catalogSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _lastIsError ? const Color(0xFFE53935) : const Color(0xFF4CAF50);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cập nhật danh mục',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Mặt hàng, khách hàng, xe, lái xe, tài khoản, giá bán ngày. '
                    'Tự động cập nhật mỗi lần mở app.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastSyncAt != null
                        ? 'Lần cuối: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncAt!)}'
                        : 'Chưa cập nhật lần nào',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _catalogSyncing ? null : _syncCatalog,
                      icon: _catalogSyncing
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_rounded),
                      label: Text(_catalogSyncing ? 'Đang cập nhật...' : 'Cập nhật ngay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Row(
                children: [
                  Icon(_lastIsError ? Icons.error_outline : Icons.check_circle, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_lastResult!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
