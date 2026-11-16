import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus { ok, serviceOff, denied, deniedForever, error }

class OwnerFix {
  const OwnerFix(this.status, [this.position, this.accuracyMeters]);
  final LocationStatus status;
  final LatLng? position;
  final double? accuracyMeters;
  bool get ok => status == LocationStatus.ok;
}

class OwnerLocation {
  static Future<LocationStatus> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationStatus.serviceOff;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) return LocationStatus.deniedForever;
    if (p == LocationPermission.denied) return LocationStatus.denied;
    return LocationStatus.ok;
  }

  static Future<OwnerFix> current() async {
    try {
      final st = await _ensurePermission();
      if (st != LocationStatus.ok) return OwnerFix(st);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
      );
      return OwnerFix(LocationStatus.ok, LatLng(pos.latitude, pos.longitude), pos.accuracy);
    } catch (_) {
      return const OwnerFix(LocationStatus.error);
    }
  }

  static Stream<OwnerFix> watch() async* {
    final st = await _ensurePermission();
    if (st != LocationStatus.ok) {
      yield OwnerFix(st);
      return;
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).map((p) => OwnerFix(LocationStatus.ok, LatLng(p.latitude, p.longitude), p.accuracy));
  }

  static Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}
