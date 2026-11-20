// lib/core/widgets/anh_gallery_viewer.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Mở danh sách ảnh toàn màn hình: vuốt ngang chuyển ảnh, phóng to/thu nhỏ từng ảnh.
/// [chuThich] (tuỳ chọn) cùng độ dài với [urls] — hiển thị dưới số thứ tự ảnh.
void xemDanhSachAnh(BuildContext context, List<String> urls, {List<String>? chuThich, int batDau = 0}) {
  if (urls.isEmpty) return;
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: _AnhGalleryViewer(urls: urls, chuThich: chuThich, batDau: batDau),
    ),
  );
}

/// Trình xem nhiều ảnh dạng PageView, hiển thị "i/n" và chú thích ảnh hiện tại.
class _AnhGalleryViewer extends StatefulWidget {
  final List<String> urls;
  final List<String>? chuThich;
  final int batDau;
  const _AnhGalleryViewer({required this.urls, this.chuThich, required this.batDau});

  @override
  State<_AnhGalleryViewer> createState() => _AnhGalleryViewerState();
}

class _AnhGalleryViewerState extends State<_AnhGalleryViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.batDau);
  late int _trang = widget.batDau;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ct = widget.chuThich;
    final chuThich = ct != null && _trang < ct.length && ct[_trang].isNotEmpty ? ' • ${ct[_trang]}' : '';
    return Stack(children: [
      Positioned.fill(
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _trang = i),
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 5,
            child: CachedNetworkImage(
              imageUrl: widget.urls[i],
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: SafeArea(
          child: Text('${_trang + 1}/${widget.urls.length}$chuThich',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: SafeArea(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    ]);
  }
}

/// Thumbnail ảnh vuông bo góc (mặc định 48x48); [badgeColor] != null → chấm màu góc trên phải.
class AnhThumbnail extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  final double size;
  final Color? badgeColor;
  const AnhThumbnail({super.key, required this.url, this.onTap, this.size = 48, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    // Decode đúng kích thước hiển thị (theo mật độ điểm ảnh) thay vì ảnh gốc vài nghìn px → hết giật khi cuộn
    final cachePx = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return RepaintBoundary(
      child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              memCacheWidth: cachePx,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade200),
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
            ),
          ),
          if (badgeColor != null)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
      ),
    );
  }
}

/// Nút "xem ảnh" có badge số lượng ảnh — dùng ở trailing của item danh sách.
class XemAnhButton extends StatelessWidget {
  final int soAnh;
  final VoidCallback onPressed;
  const XemAnhButton({super.key, required this.soAnh, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Xem ảnh',
        onPressed: onPressed,
        icon: Badge(label: Text('$soAnh'), child: const Icon(Icons.photo_library_outlined)),
      );
}
