import 'dart:async';
import 'dart:math';
import '../../../core/utils/geo_utils.dart';
import '../../activity/domain/daily_activity.dart';
import '../../alerts/domain/pet_alert.dart';
import '../../assistant/domain/pet_emergency.dart';
import '../../contacts/domain/emergency_contact.dart';
import '../../geofencing/domain/safe_zone.dart';
import '../../health/domain/health_record.dart';
import '../../pets/domain/pet.dart';
import '../../walks/domain/walk.dart';
import '../data/mock_location_service.dart';
import '../domain/location_data.dart';

abstract class PetSessionListener {
  void onSessionChanged(PetSession s);
  void onLeftAllZones(PetSession s);
  void onBackInZone(PetSession s);
  void onAlert(PetSession s, AlertType type, Map<String, String> params);
  void onLocationSaved(PetSession s, LocationHistory entry);
  void onActivityChanged(PetSession s, DailyActivity today);
  void onTrackerChanged(PetSession s);
  void onWalkPoint(PetSession s);
}

class PetSession {
  PetSession({
    required this.pet,
    required this.tracker,
    required this.service,
    required this.listener,
    required this.zones,
    required this.history,
    required this.alerts,
    required this.contacts,
    required this.walks,
    required this.activity,
    required this.health,
  });

  Pet pet;
  TrackerDevice tracker;
  final LocationService service;
  final PetSessionListener listener;
  List<SafeZone> zones;
  List<LocationHistory> history;
  List<PetAlert> alerts;
  List<EmergencyContact> contacts;
  List<Walk> walks;
  List<DailyActivity> activity;
  List<HealthRecord> health;

  LocationData? current;
  bool insideZone = true;
  PetEmergency? emergency;
  Walk? activeWalk;

  bool simulateLeaving = false, simulateFrozen = false, simulateSpeeding = false;

  String? daySummary;
  String? daySummaryDay;
  bool summaryLoading = false;

  StreamSubscription<LocationData>? _sub;
  LocationData? _prev;
  LocationData? _anchor;
  int _ticks = 0;
  bool _lowBatteryRaised = false;
  DateTime _lastMoved = DateTime.now();
  bool _stationaryRaised = false;
  int _fastTicks = 0;
  DateTime? _lastGpsLost;
  DateTime? _lastSpeedAlert;
  final List<LocationData> _speedWindow = [];
  static const speedWindow = Duration(seconds: 8);
  int _secondsOutsideToday = 0;
  final Set<String> _placesToday = {};

  MockLocationService? get mock => service is MockLocationService ? service as MockLocationService : null;

  static const stationaryLimit = Duration(minutes: 3);
  static const fastKmh = 25.0;

  bool _stopped = false;

  void start(Duration interval) {
    service.setInterval(interval);
    _sub ??= service.watchLocation().listen(_onLocation);
    service.getCurrentLocation().then((l) {
      if (_stopped) return;
      current ??= l;
      _updateInside(l, raise: false);
      listener.onSessionChanged(this);
    }, onError: (_) {
    });
  }

  void stop() {
    _stopped = true;
    _sub?.cancel();
    _sub = null;
    service.dispose();
  }

  List<SafeZone> get enabledZones => zones.where((z) => z.isEnabled).toList();

  SafeZone? get homeZone => zones.isEmpty ? null : zones.first;

  SafeZone? get currentZone {
    final l = current;
    if (l == null) return null;
    for (final z in enabledZones) {
      if (_dist(z, l) <= z.radius) return z;
    }
    return null;
  }

  double _dist(SafeZone z, LocationData l) =>
      GeoUtils.distanceMeters(z.latitude, z.longitude, l.latitude, l.longitude);

  bool isInsideZones(LocationData l) => enabledZones.isEmpty || enabledZones.any((z) => _dist(z, l) <= z.radius);

  double? get distanceFromHome {
    final h = homeZone, l = current;
    if (h == null || l == null) return null;
    return _dist(h, l);
  }

  double get metersOutside {
    final l = current;
    if (l == null || enabledZones.isEmpty) return 0;
    return enabledZones.map((z) => max(0.0, _dist(z, l) - z.radius)).reduce(min);
  }

  String get nearestZoneName {
    final l = current;
    if (l == null || zones.isEmpty) return '';
    final sorted = [...zones]..sort((a, b) => _dist(a, l).compareTo(_dist(b, l)));
    return sorted.first.name;
  }

  void _updateInside(LocationData l, {required bool raise}) {
    final was = insideZone;
    insideZone = enabledZones.isEmpty || enabledZones.any((z) => _dist(z, l) <= z.radius);
    final z = currentZone;
    if (z != null) _placesToday.add(z.name);
    if (!raise) return;
    if (was && !insideZone) listener.onLeftAllZones(this);
    if (!was && insideZone) listener.onBackInZone(this);
  }

  DailyActivity get today {
    final k = DailyActivity.keyFor(DateTime.now());
    return activity.firstWhere((d) => d.day == k, orElse: () => DailyActivity(petId: pet.id, day: k));
  }

  int get minutesOutsideToday => (_secondsOutsideToday / 60).ceil();
  List<String> get placesToday => _placesToday.toList();

  void _addActivity(double meters, int seconds) {
    final t = today.add(meters: meters, seconds: seconds);
    activity = [...activity.where((d) => d.day != t.day), t];
    if (_ticks % 10 == 0) listener.onActivityChanged(this, t);
  }

  bool get hasSignal => current != null;

  void _onLocation(LocationData l) {
    if (_stopped) return;
    if (!tracker.isConnected) {
      if (mock != null) return;
      tracker = tracker.copyWith(isConnected: true);
    }
    final prev = _prev ?? current;
    current = l;
    _prev = l;
    _ticks++;

    var battery = l.battery ?? tracker.batteryLevel;
    if (mock != null && _ticks % (tracker.powerSave ? 8 : 4) == 0 && battery > 1) battery--;
    final signal = l.accuracy > 25 ? 1 : (l.accuracy > 10 ? 3 : 4);
    tracker = tracker.copyWith(batteryLevel: battery, lastUpdate: l.timestamp, signal: signal);
    if (_ticks % 10 == 0) listener.onTrackerChanged(this);

    final reliable = l.accuracy <= 25;
    double step = 0;
    int ms = 0;
    if (prev != null && reliable) {
      step = GeoUtils.distanceMeters(prev.latitude, prev.longitude, l.latitude, l.longitude);
      ms = l.timestamp.difference(prev.timestamp).inMilliseconds;
    }
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = l;
      _addActivity(0, 0);
    } else if (reliable) {
      final moved = GeoUtils.distanceMeters(anchor.latitude, anchor.longitude, l.latitude, l.longitude);
      if (moved >= 3) {
        final secs = max(1, l.timestamp.difference(anchor.timestamp).inSeconds);
        _anchor = l;
        _lastMoved = l.timestamp;
        _stationaryRaised = false;
        _addActivity(moved, secs);
      } else {
        _addActivity(0, 0);
      }
    }
    final seconds = (ms / 1000).ceil();

    _updateInside(l, raise: true);
    if (!insideZone) _secondsOutsideToday += max(1, seconds);

    final w = activeWalk;
    if (w != null) {
      activeWalk = w.copyWith(points: [...w.points, l]);
      listener.onWalkPoint(this);
    }

    _checkUnusual(l, prev, step, ms);

    if (battery < 20 && !_lowBatteryRaised) {
      _lowBatteryRaised = true;
      listener.onAlert(this, AlertType.lowBattery, {'battery': '$battery', 'pet': pet.name});
    }
    if (!reliable && (_lastGpsLost == null || l.timestamp.difference(_lastGpsLost!) > const Duration(minutes: 5))) {
      _lastGpsLost = l.timestamp;
      listener.onAlert(this, AlertType.gpsLost, {'pet': pet.name});
    }

    final entry = LocationHistory(
        id: '${pet.id}-${l.timestamp.microsecondsSinceEpoch}', petId: pet.id, location: l,
        status: insideZone ? 'Inside safe zone' : 'Outside safe zone');
    history.insert(0, entry);
    if (history.length > 300) history.removeLast();
    listener.onLocationSaved(this, entry);
    listener.onSessionChanged(this);
  }

  void _checkUnusual(LocationData l, LocationData? prev, double step, int ms) {
    if (!_stationaryRaised && l.timestamp.difference(_lastMoved) >= stationaryLimit) {
      _stationaryRaised = true;
      listener.onAlert(this, AlertType.anomaly, {
        'kind': 'stationary',
        'pet': pet.name,
        'minutes': '${l.timestamp.difference(_lastMoved).inMinutes}',
      });
    }
    if (l.accuracy <= 25) _speedWindow.add(l);
    while (_speedWindow.length > 2 && l.timestamp.difference(_speedWindow[1].timestamp) >= speedWindow) {
      _speedWindow.removeAt(0);
    }
    final first = _speedWindow.first;
    final span = l.timestamp.difference(first.timestamp);
    if (span >= speedWindow) {
      final d = GeoUtils.distanceMeters(first.latitude, first.longitude, l.latitude, l.longitude);
      final kmh = d / (span.inMilliseconds / 1000) * 3.6;
      _fastTicks = kmh > fastKmh ? _fastTicks + 1 : 0;
      final cooledDown = _lastSpeedAlert == null || l.timestamp.difference(_lastSpeedAlert!) > const Duration(minutes: 10);
      if (_fastTicks >= 2 && cooledDown) {
        _lastSpeedAlert = l.timestamp;
        listener.onAlert(this, AlertType.anomaly, {'kind': 'speed', 'pet': pet.name, 'kmh': '${kmh.round()}'});
      }
    }
  }

  bool get isNight {
    final h = DateTime.now().hour;
    return h >= 22 || h < 6;
  }

  void resetBatteryFlag() => _lowBatteryRaised = false;
}
