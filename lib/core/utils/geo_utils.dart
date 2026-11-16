import 'dart:math';

class GeoUtils {
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
    return 2 * r * asin(sqrt(a));
  }
}

class Fmt {
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  static String distance(double m, bool metric) {
    if (!metric) return '${(m * 3.28084).round()} ft';
    return m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.round()} m';
  }
}
