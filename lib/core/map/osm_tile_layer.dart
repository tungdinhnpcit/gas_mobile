// lib/core/map/osm_tile_layer.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

import '../constants/app_constants.dart';

/// URL template tile bản đồ.
/// - Server production (apimba): đi qua nginx `/osm-tile/` — mạng 4G từ chối kết nối TCP thẳng
///   tới tile.openstreetmap.org (Connection refused), nên để máy chủ 147 tải hộ.
/// - Backend local khi dev (không có nginx): gọi thẳng OpenStreetMap.
String get _urlTemplate {
  final base = AppConstants.staticBaseUrl;
  return base.contains('apimba')
      ? '$base/osm-tile/{z}/{x}/{y}.png'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

/// Lớp nền bản đồ OpenStreetMap dùng chung cho toàn app; log lỗi khi tải tile thất bại
/// (xem bằng `adb logcat | findstr MAP`).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: _urlTemplate,
      userAgentPackageName: 'com.npc.quan_ly_gas',
      maxNativeZoom: 19,
      errorTileCallback: (tile, error, _) =>
          debugPrint('[MAP] Lỗi tải tile ${tile.coordinates}: $error'),
    );
