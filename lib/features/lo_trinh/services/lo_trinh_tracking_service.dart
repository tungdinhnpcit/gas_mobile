// lib/features/lo_trinh/services/lo_trinh_tracking_service.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;

import '../../../core/database/local_database.dart';
import '../data/models/lo_trinh_model.dart';
import '../data/repositories/lo_trinh_repository.dart';

/// Trạng thái ghi lộ trình hiện tại trên máy.
class LoTrinhTrackingState {
  final LoTrinhModel? loTrinh; // lộ trình đang ghi (null = không ghi)
  final List<LoTrinhDiemModel> diem; // điểm đã ghi trong phiên (để vẽ polyline live)
  final double quangDuongM; // quãng đường tính cục bộ
  final bool dangXuLy; // đang bắt đầu/kết thúc
  final int soDiemCho; // số điểm chưa đẩy được lên server

  const LoTrinhTrackingState({
    this.loTrinh,
    this.diem = const [],
    this.quangDuongM = 0,
    this.dangXuLy = false,
    this.soDiemCho = 0,
  });

  bool get dangGhi => loTrinh != null;

  LoTrinhTrackingState copyWith({
    LoTrinhModel? loTrinh,
    bool xoaLoTrinh = false,
    List<LoTrinhDiemModel>? diem,
    double? quangDuongM,
    bool? dangXuLy,
    int? soDiemCho,
  }) =>
      LoTrinhTrackingState(
        loTrinh: xoaLoTrinh ? null : (loTrinh ?? this.loTrinh),
        diem: diem ?? this.diem,
        quangDuongM: quangDuongM ?? this.quangDuongM,
        dangXuLy: dangXuLy ?? this.dangXuLy,
        soDiemCho: soDiemCho ?? this.soDiemCho,
      );
}

/// Ghi lộ trình GPS: stream vị trí của geolocator chạy kèm foreground service Android
/// (thông báo cố định) nên vẫn ghi khi tắt màn hình. Điểm được ghi vào SQLite trước,
/// sau đó đẩy batch lên server mỗi 30 giây hoặc khi đủ 20 điểm → mất sóng không mất điểm.
class LoTrinhTrackingNotifier extends StateNotifier<LoTrinhTrackingState> {
  LoTrinhTrackingNotifier() : super(const LoTrinhTrackingState());

  static const _batchSize = 20;
  static const _maxDoChinhXacM = 25.0; // bỏ điểm sai số lớn (phố đông, dưới tán cây)
  static const _maxTocDoMs = 40.0; // ~144 km/h — vượt mức này coi là điểm "nhảy"
  static const _tocDoDungYenMs = 1.0; // dưới mức này coi như đang đứng yên
  static const _distanceFilterM = 8;
  static const _bang = 'lo_trinh_diem_cho';

  final _repo = LoTrinhRepository();
  StreamSubscription<Position>? _sub;
  Timer? _flushTimer;
  bool _dangDay = false;

  /// Khôi phục khi mở app: nếu server còn lộ trình đang ghi → tiếp tục ghi; đồng thời đẩy bù điểm tồn.
  Future<void> khoiPhuc() async {
    try {
      await _dayDiemCho();
      if (state.dangGhi) return;
      final lt = await _repo.getDangGhi();
      if (lt == null) return;
      state = state.copyWith(loTrinh: lt, quangDuongM: lt.tongQuangDuongM);
      await _batDauStream();
    } catch (e) {
      debugPrint('[LO_TRINH] khôi phục lỗi: $e');
    }
  }

  /// Xin quyền vị trí; trả thông báo lỗi (null = OK). Quyền "Luôn cho phép" là khuyến nghị, không bắt buộc
  /// vì foreground service vẫn được phép lấy vị trí với quyền "Khi dùng ứng dụng".
  Future<String?> _xinQuyen() async {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Vui lòng bật GPS (định vị) trên điện thoại';
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) return 'Bạn chưa cấp quyền vị trí';
    if (p == LocationPermission.deniedForever) {
      return 'Quyền vị trí đã bị chặn, vui lòng mở Cài đặt ứng dụng để cấp lại';
    }
    if (p == LocationPermission.whileInUse) {
      // Hỏi nâng lên "Luôn cho phép" — người dùng từ chối vẫn ghi được nhờ foreground service
      await Geolocator.requestPermission();
    }
    return null;
  }

  /// Bắt đầu ghi lộ trình mới. Trả thông báo lỗi nếu thất bại.
  Future<String?> batDau({String? ten}) async {
    if (state.dangGhi || state.dangXuLy) return null;
    final loiQuyen = await _xinQuyen();
    if (loiQuyen != null) return loiQuyen;
    state = state.copyWith(dangXuLy: true);
    try {
      final lt = await _repo.batDau(ten: ten);
      state = LoTrinhTrackingState(loTrinh: lt, quangDuongM: lt.tongQuangDuongM);
      await _batDauStream();
      return null;
    } catch (e) {
      state = state.copyWith(dangXuLy: false);
      debugPrint('[LO_TRINH] bắt đầu lỗi: $e');
      return 'Không bắt đầu được lộ trình: ${_loiTuServer(e)}';
    }
  }

  /// Kết thúc lộ trình: dừng GPS, đẩy hết điểm còn lại rồi báo server. Trả id lộ trình đã kết thúc.
  Future<int?> ketThuc() async {
    final lt = state.loTrinh;
    if (lt == null) return null;
    state = state.copyWith(dangXuLy: true);
    await _dungStream();
    await _dayDiemCho();
    try {
      await _repo.ketThuc(lt.id);
    } catch (e) {
      debugPrint('[LO_TRINH] kết thúc lỗi (sẽ được kết thúc lại khi mở app): $e');
    }
    state = const LoTrinhTrackingState();
    return lt.id;
  }

  /// Huỷ lộ trình đang ghi: dừng GPS, bỏ điểm chờ cục bộ, xoá lộ trình trên server.
  /// Trả null nếu thành công; lỗi → ghi tiếp lộ trình và trả thông báo lỗi.
  Future<String?> huy() async {
    final lt = state.loTrinh;
    if (lt == null || state.dangXuLy) return null;
    state = state.copyWith(dangXuLy: true);
    await _dungStream();
    try {
      final db = await LocalDatabase.instance.db;
      await db.delete(_bang, where: 'lo_trinh_id = ?', whereArgs: [lt.id]);
      await _repo.delete(lt.id);
      state = const LoTrinhTrackingState();
      return null;
    } catch (e) {
      debugPrint('[LO_TRINH] huỷ lỗi: $e');
      await _batDauStream(); // server vẫn còn lộ trình → ghi tiếp, tránh lệch trạng thái
      return 'Không huỷ được lộ trình: ${_loiTuServer(e)}';
    }
  }

  /// Lấy message thân thiện từ response backend ({ message: ... }); lỗi mạng → thông báo chung.
  String _loiTuServer(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      if (e.response == null) return 'Không kết nối được máy chủ, vui lòng kiểm tra mạng';
      return 'Lỗi máy chủ (${e.response?.statusCode})';
    }
    return e.toString();
  }

  Future<void> _batDauStream() async {
    await _dungStream();
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilterM,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Đang ghi lộ trình',
              notificationText: 'Ứng dụng đang ghi lại vị trí di chuyển của bạn',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
            ? AppleSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: _distanceFilterM,
                allowBackgroundLocationUpdates: true,
                pauseLocationUpdatesAutomatically: false,
                showBackgroundLocationIndicator: true,
              )
            : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterM);

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onViTri,
      onError: (e) => debugPrint('[LO_TRINH] stream lỗi: $e'),
    );
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _dayDiemCho());
    state = state.copyWith(dangXuLy: false);
  }

  Future<void> _dungStream() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Số điểm liên tiếp bị loại vì "nhảy" — đủ ngưỡng thì chấp nhận lại, tránh kẹt khi chính điểm trước bị sai.
  int _soLanNhayLienTiep = 0;

  /// Kiểm tra điểm mới so với điểm hợp lệ trước đó; trả false nếu là nhiễu cần bỏ:
  /// - Tốc độ suy ra (quãng đường / thời gian) vượt [_maxTocDoMs] → điểm nhảy.
  /// - Đang đứng yên (tốc độ thấp) mà dịch chuyển nhỏ hơn sai số GPS → trôi tại chỗ.
  bool _hopLe(Position p) {
    if (state.diem.isEmpty) return true;
    final truoc = state.diem.last;
    final d = Geolocator.distanceBetween(truoc.lat, truoc.lng, p.latitude, p.longitude);
    final giay = p.timestamp.difference(truoc.thoiGian).inMilliseconds / 1000;

    if (giay > 0 && d / giay > _maxTocDoMs) {
      _soLanNhayLienTiep++;
      if (_soLanNhayLienTiep < 3) return false;
      // 3 điểm liên tiếp cùng "nhảy" → nhiều khả năng điểm trước mới là điểm sai, chấp nhận vị trí mới
    }
    _soLanNhayLienTiep = 0;

    final dungYen = p.speed >= 0 && p.speed < _tocDoDungYenMs;
    if (dungYen && d < p.accuracy) return false;
    return true;
  }

  /// Nhận 1 vị trí mới: lọc điểm kém chính xác / nhảy / trôi khi đứng yên, lưu SQLite,
  /// cập nhật polyline + quãng đường.
  Future<void> _onViTri(Position p) async {
    final lt = state.loTrinh;
    if (lt == null || p.accuracy > _maxDoChinhXacM) return;
    if (!_hopLe(p)) return;
    final diem = LoTrinhDiemModel(
      lat: p.latitude,
      lng: p.longitude,
      doChinhXac: p.accuracy,
      tocDo: p.speed,
      thoiGian: p.timestamp,
    );
    final db = await LocalDatabase.instance.db;
    await db.insert(_bang, {
      'lo_trinh_id': lt.id,
      'lat': diem.lat,
      'lng': diem.lng,
      'do_chinh_xac': diem.doChinhXac,
      'toc_do': diem.tocDo,
      'thoi_gian': diem.thoiGian.toUtc().toIso8601String(),
    });
    final them = state.diem.isEmpty
        ? 0.0
        : Geolocator.distanceBetween(state.diem.last.lat, state.diem.last.lng, diem.lat, diem.lng);
    state = state.copyWith(
      diem: [...state.diem, diem],
      quangDuongM: state.quangDuongM + them,
      soDiemCho: state.soDiemCho + 1,
    );
    if (state.soDiemCho >= _batchSize) unawaited(_dayDiemCho());
  }

  /// Đẩy các điểm đang chờ trong SQLite lên server theo từng lộ trình; xoá khi thành công.
  /// Lỗi mạng → giữ nguyên để lần sau đẩy lại.
  Future<void> _dayDiemCho() async {
    if (_dangDay) return;
    _dangDay = true;
    try {
      final db = await LocalDatabase.instance.db;
      final rows = await db.query(_bang, orderBy: 'id', limit: 500);
      if (rows.isEmpty) return;
      final theoLoTrinh = <int, List<Map<String, Object?>>>{};
      for (final r in rows) {
        theoLoTrinh.putIfAbsent(r['lo_trinh_id'] as int, () => []).add(r);
      }
      for (final entry in theoLoTrinh.entries) {
        final diem = entry.value
            .map((r) => LoTrinhDiemModel(
                  lat: r['lat'] as double,
                  lng: r['lng'] as double,
                  doChinhXac: r['do_chinh_xac'] as double?,
                  tocDo: r['toc_do'] as double?,
                  thoiGian: DateTime.parse(r['thoi_gian'] as String),
                ))
            .toList();
        await _repo.themDiem(entry.key, diem);
        final maxId = entry.value.last['id'] as int;
        await db.delete(_bang, where: 'lo_trinh_id = ? AND id <= ?', whereArgs: [entry.key, maxId]);
      }
      final conLai = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_bang')) ?? 0;
      if (mounted) state = state.copyWith(soDiemCho: conLai);
    } catch (e) {
      debugPrint('[LO_TRINH] đẩy điểm lỗi (giữ lại để đẩy sau): $e');
    } finally {
      _dangDay = false;
    }
  }

  @override
  void dispose() {
    _dungStream();
    super.dispose();
  }
}

/// Provider toàn cục (không autoDispose) để việc ghi không dừng khi rời màn hình.
final loTrinhTrackingProvider =
    StateNotifierProvider<LoTrinhTrackingNotifier, LoTrinhTrackingState>((ref) => LoTrinhTrackingNotifier());
