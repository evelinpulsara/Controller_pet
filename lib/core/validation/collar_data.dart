import '../../features/tracking/domain/location_data.dart';

LocationData? parseCollarLocation(Map<String, dynamic> r) {
  final lat = _num(r['latitude']), lon = _num(r['longitude']);
  if (lat == null || lon == null) return null;
  if (!lat.isFinite || !lon.isFinite || lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  if (lat == 0 && lon == 0) return null;

  final t = r['recorded_at'] is String ? DateTime.tryParse(r['recorded_at']) : null;
  if (t == null) return null;
  if (t.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) return null;

  final acc = _num(r['accuracy_m']);
  final battery = _num(r['battery_pct'])?.round();
  return LocationData(
    latitude: lat,
    longitude: lon,
    timestamp: t.toLocal(),
    accuracy: (acc == null || acc < 0 || acc > 10000) ? 50 : acc,
    battery: (battery == null || battery < 0 || battery > 100) ? null : battery,
  );
}

double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
