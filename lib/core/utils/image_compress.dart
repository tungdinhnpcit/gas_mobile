// lib/core/utils/image_compress.dart
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Nén ảnh xuống ≤ [maxBytes] (mặc định 1MB) bằng cách giảm dần chất lượng JPEG;
/// ảnh đã nhỏ hơn giới hạn thì trả nguyên. Không nén được thì trả bản nhỏ nhất đã thử.
Future<XFile> compressImageUnder(XFile photo, {int maxBytes = 1024 * 1024}) async {
  if (await photo.length() <= maxBytes) return photo;

  final tmpDir = Directory.systemTemp;
  var quality = 85;
  XFile? result;
  while (quality >= 20) {
    final outPath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    result = await FlutterImageCompress.compressAndGetFile(
      photo.path,
      outPath,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (result != null && await result.length() <= maxBytes) return result;
    quality -= 10;
  }
  return result ?? photo;
}
