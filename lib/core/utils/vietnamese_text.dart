// lib/core/utils/vietnamese_text.dart

/// Loại bỏ dấu tiếng Việt, trả về chuỗi ASCII lowercase để so sánh.
String removeDiacritics(String s) {
  const Map<String, String> diacriticsMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a', 'â': 'a', 'ă': 'a',
    'ắ': 'a', 'ặ': 'a', 'ẵ': 'a', 'ẳ': 'a', 'ằ': 'a',
    'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẫ': 'a', 'ẩ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e', 'ê': 'e', 'ë': 'e',
    'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ễ': 'e', 'ể': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o', 'ô': 'o', 'ö': 'o', 'ơ': 'o',
    'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ỗ': 'o', 'ổ': 'o',
    'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ỡ': 'o', 'ở': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u', 'û': 'u', 'ü': 'u', 'ư': 'u',
    'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ữ': 'u', 'ử': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd', 'ñ': 'n', 'ç': 'c',
  };
  // Duyệt từng ký tự ghi vào StringBuffer — tránh tạo List trung gian của split/map/join
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final c = lower[i];
    buf.write(diacriticsMap[c] ?? c);
  }
  return buf.toString();
}
