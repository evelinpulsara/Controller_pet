import 'dart:convert';
import 'dart:math';

class RouteAnalysis {
  RouteAnalysis.fromJson(Map<String, dynamic> j)
      : points = (j['points'] as num).toInt(),
        distanceM = (j['distanceM'] as num).toDouble(),
        maxSpeedKmh = (j['maxSpeedKmh'] as num).toDouble(),
        avgSpeedKmh = (j['avgSpeedKmh'] as num).toDouble(),
        totalMs = (j['totalMs'] as num).toDouble(),
        outsideMs = (j['outsideMs'] as num).toDouble(),
        zoneMs = {for (final e in (j['zoneMs'] as Map).entries) '${e.key}': (e.value as num).toDouble()},
        topPlaces = [for (final p in (j['topPlaces'] as List)) [for (final v in p as List) (v as num).toDouble()]],
        elapsedMs = (j['elapsedMs'] as num).toDouble(),
        thread = j['thread'] as String;

  final int points;
  final double distanceM, maxSpeedKmh, avgSpeedKmh, totalMs, outsideMs, elapsedMs;
  final Map<String, double> zoneMs;
  final List<List<double>> topPlaces;
  final String thread;

  double get insidePct => totalMs <= 0 ? 100 : (1 - outsideMs / totalMs) * 100;
}

Map<String, dynamic> analyzeRouteJson(String input, {String thread = 'main-thread'}) {
  final sw = Stopwatch()..start();
  final j = jsonDecode(input) as Map<String, dynamic>;
  final zones = [for (final z in (j['zones'] as List? ?? [])) z as List];
  final n = (j['synthetic'] as num?)?.toInt() ?? 0;
  final points = n > 0 ? _synthetic(n, zones) : [for (final p in (j['points'] as List? ?? [])) [for (final v in p as List) (v as num).toDouble()]];
  final r = _analyze(points, zones);
  r['elapsedMs'] = sw.elapsedMicroseconds / 1000;
  r['thread'] = thread;
  return r;
}

double _hav(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0, rad = pi / 180;
  final dLat = (lat2 - lat1) * rad, dLng = (lng2 - lng1) * rad;
  final a = pow(sin(dLat / 2), 2) + cos(lat1 * rad) * cos(lat2 * rad) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a));
}

List<List<double>> _synthetic(int n, List<List> zones) {
  final home = zones.isNotEmpty ? zones.first : [1.21361, -77.28111, 100, 'Casa'];
  var s = 42;
  double rnd() {
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return s / 4294967296;
  }

  var lat = (home[0] as num).toDouble(), lng = (home[1] as num).toDouble(), t = 0.0;
  final hLat = lat, hLng = lng;
  return List.generate(n, (_) {
    lat += (rnd() - 0.5) * 0.0004 + (hLat - lat) * 0.02;
    lng += (rnd() - 0.5) * 0.0004 + (hLng - lng) * 0.02;
    t += 60000;
    return [lat, lng, t];
  });
}

Map<String, dynamic> _analyze(List<List<double>> points, List<List> zones) {
  var distance = 0.0, maxSpeed = 0.0, outsideMs = 0.0, totalMs = 0.0;
  final zoneMs = <String, double>{for (final z in zones) '${z[3]}': 0};
  final cells = <String, int>{};
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final key = '${(p[0] * 1000).round()},${(p[1] * 1000).round()}';
    cells[key] = (cells[key] ?? 0) + 1;
    if (i == 0) continue;
    final q = points[i - 1];
    final d = _hav(q[0], q[1], p[0], p[1]);
    final dt = p[2] - q[2];
    distance += d;
    if (dt > 0) {
      totalMs += dt;
      final kmh = d / (dt / 1000) * 3.6;
      if (kmh > maxSpeed && kmh < 200) maxSpeed = kmh;
      String? inside;
      for (final z in zones) {
        if (_hav((z[0] as num).toDouble(), (z[1] as num).toDouble(), q[0], q[1]) <= (z[2] as num).toDouble()) {
          inside = '${z[3]}';
          break;
        }
      }
      if (inside == null) {
        outsideMs += dt;
      } else {
        zoneMs[inside] = zoneMs[inside]! + dt;
      }
    }
  }
  final top = cells.entries
      .map((e) {
        final parts = e.key.split(',');
        return [int.parse(parts[0]) / 1000, int.parse(parts[1]) / 1000, e.value.toDouble()];
      })
      .toList()
    ..sort((a, b) => b[2].compareTo(a[2]));
  return {
    'points': points.length,
    'distanceM': distance,
    'maxSpeedKmh': maxSpeed,
    'avgSpeedKmh': totalMs > 0 ? distance / (totalMs / 1000) * 3.6 : 0,
    'totalMs': totalMs,
    'outsideMs': outsideMs,
    'zoneMs': zoneMs,
    'topPlaces': top.take(5).toList(),
  };
}
