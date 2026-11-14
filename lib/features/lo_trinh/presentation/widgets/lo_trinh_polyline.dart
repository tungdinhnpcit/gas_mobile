// lib/features/lo_trinh/presentation/widgets/lo_trinh_polyline.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/lo_trinh_model.dart';

/// Khoảng trống giữa 2 điểm vượt một trong các ngưỡng này coi là mất tín hiệu GPS.
const _gapThoiGian = Duration(minutes: 2);
const _gapKhoangCachM = 500.0;

/// Dựng polyline cho lộ trình: các đoạn ghi liên tục vẽ nét liền xanh; chỗ mất tín hiệu
/// (cách nhau > 2 phút hoặc > 500 m) không nối liền mà vẽ nét đứt xám để không hiểu nhầm là đường đi thật.
List<Polyline> dungPolylineLoTrinh(List<LoTrinhDiemModel> diem) {
  if (diem.length < 2) return const [];
  final ketQua = <Polyline>[];
  var doan = [diem.first.latLng];

  for (var i = 1; i < diem.length; i++) {
    final truoc = diem[i - 1];
    final sau = diem[i];
    final mat = sau.thoiGian.difference(truoc.thoiGian) > _gapThoiGian ||
        Geolocator.distanceBetween(truoc.lat, truoc.lng, sau.lat, sau.lng) > _gapKhoangCachM;
    if (mat) {
      if (doan.length >= 2) {
        ketQua.add(Polyline(points: doan, strokeWidth: 5, color: Colors.blue));
      }
      ketQua.add(Polyline(
        points: [truoc.latLng, sau.latLng],
        strokeWidth: 3,
        color: Colors.grey,
        pattern: StrokePattern.dashed(segments: const [8, 8]),
      ));
      doan = [sau.latLng];
    } else {
      doan.add(sau.latLng);
    }
  }
  if (doan.length >= 2) ketQua.add(Polyline(points: doan, strokeWidth: 5, color: Colors.blue));
  return ketQua;
}
