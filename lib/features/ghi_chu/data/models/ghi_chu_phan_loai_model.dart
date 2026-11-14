// lib/features/ghi_chu/data/models/ghi_chu_phan_loai_model.dart
import 'package:flutter/material.dart';

/// Phân loại ghi chú do user tự tạo; [mau] là mã hex dạng '#RRGGBB'.
class GhiChuPhanLoaiModel {
  final int id;
  final String ten;
  final String? mau;
  final int sortOrder;
  final int soGhiChu;

  const GhiChuPhanLoaiModel({
    required this.id,
    required this.ten,
    this.mau,
    this.sortOrder = 0,
    this.soGhiChu = 0,
  });

  factory GhiChuPhanLoaiModel.fromJson(Map<String, dynamic> json) => GhiChuPhanLoaiModel(
        id: json['id'] as int,
        ten: (json['ten'] as String?) ?? '',
        mau: json['mau'] as String?,
        sortOrder: (json['sortOrder'] as int?) ?? 0,
        soGhiChu: (json['soGhiChu'] as int?) ?? 0,
      );

  Color get color => phanLoaiColor(mau);
}

/// Bảng màu gợi ý khi tạo phân loại.
const List<String> phanLoaiPalette = [
  '#009688', '#2196F3', '#4CAF50', '#FF9800', '#F44336', '#9C27B0', '#795548', '#607D8B',
];

/// Chuyển mã hex '#RRGGBB' thành Color; null hoặc sai định dạng thì trả màu xám.
Color phanLoaiColor(String? hex) {
  if (hex == null) return Colors.blueGrey;
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? Colors.blueGrey : Color(v);
}
