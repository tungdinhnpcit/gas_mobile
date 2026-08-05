// lib/core/utils/date_query_ext.dart

/// Format ngày cho query param API dạng 'yyyy-MM-dd' (date-only, không kèm time/timezone)
/// — khớp định dạng backend mong đợi, tránh gửi ISO datetime đầy đủ gây lỗi filter ngày.
extension DateQueryExt on DateTime {
  String toApiDateString() => toIso8601String().substring(0, 10);
}
