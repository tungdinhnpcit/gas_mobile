// lib/core/widgets/swipe_back_wrapper.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Bọc 1 màn hình để vuốt từ trái sang phải ở bất kỳ vị trí nào sẽ quay lại màn trước.
/// - Mặc định gọi Navigator.maybePop() → tôn trọng PopScope (màn đang nhập dở vẫn hỏi xác nhận).
/// - Không pop được → về trang chủ.
/// - Widget con có gesture ngang riêng (TabBarView, PageView, bản đồ) thắng gesture arena nên không xung đột.
class SwipeBackWrapper extends StatefulWidget {
  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.enabled = true,
    this.onBack,
  });

  final Widget child;
  final bool enabled; // false = tắt vuốt back (vd: tab chính, màn ký tay)
  final VoidCallback? onBack; // hành động back tuỳ chỉnh, null = maybePop

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper> {
  static const _minDistance = 80.0; // quãng đường vuốt tối thiểu (px)
  static const _minVelocity = 250.0; // vận tốc vuốt tối thiểu (px/s)

  double _dx = 0; // tổng quãng đường vuốt ngang của gesture hiện tại

  /// Thực hiện quay lại: ưu tiên callback, sau đó maybePop, cuối cùng về trang chủ.
  Future<void> _goBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
    } else if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final gesture = GestureDetector(
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        if (_dx > _minDistance && (d.primaryVelocity ?? 0) > _minVelocity) {
          _goBack();
        }
        _dx = 0;
      },
      child: widget.child,
    );
    // Có onBack (shell tự xử lý back hệ thống) → chỉ cần gesture
    if (widget.onBack != null) return gesture;

    // Route root mở bằng context.go (không còn màn phía dưới): back hệ thống / vuốt mép
    // của Android sẽ thoát app → chặn lại và về trang chủ.
    final canPopNav = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPopNav,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !canPopNav) context.go(AppRoutes.home);
      },
      child: gesture,
    );
  }
}
