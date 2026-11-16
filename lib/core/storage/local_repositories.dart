import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';
import 'local_store.dart';

class LocalPetRepository implements PetRepository {
  LocalPetRepository(this._s);
  final LocalStore _s;
  static const _k = 'pets';
  List<Pet> _all() => _s.readList(_k, Pet.fromJson);
  Future<void> _save(List<Pet> l) => _s.writeList(_k, l, (p) => p.toJson());

  @override
  Future<List<Pet>> getPets() async => _all();
  @override
  Future<void> addPet(Pet pet) => _save([..._all(), pet]);
  @override
  Future<void> updatePet(Pet pet) => _save([for (final p in _all()) p.id == pet.id ? pet : p]);
  @override
  Future<void> deletePet(String id) => _save(_all().where((p) => p.id != id).toList());
}

class LocalTrackerRepository implements TrackerRepository {
  LocalTrackerRepository(this._s);
  final LocalStore _s;
  static const _k = 'trackers';
  List<TrackerDevice> _all() => _s.readList(_k, TrackerDevice.fromJson);

  @override
  Future<TrackerDevice> getTracker(String id) async {
    final found = _all().where((t) => t.id == id);
    if (found.isNotEmpty) return found.first;
    final t = TrackerDevice(id: id, batteryLevel: 0, isConnected: false, lastUpdate: DateTime.fromMillisecondsSinceEpoch(0));
    await saveTracker(t);
    return t;
  }

  @override
  Future<void> saveTracker(TrackerDevice t) =>
      _s.writeList(_k, [..._all().where((x) => x.id != t.id), t], (x) => x.toJson());
}

class LocalSafeZoneRepository implements SafeZoneRepository {
  LocalSafeZoneRepository(this._s);
  final LocalStore _s;
  static const _k = 'zones';
  List<SafeZone> _all() => _s.readList(_k, SafeZone.fromJson);

  @override
  Future<List<SafeZone>> getZones(String petId) async => _all().where((z) => z.petId == petId).toList();
  @override
  Future<void> saveZone(SafeZone z) {
    final all = _all();
    final i = all.indexWhere((x) => x.id == z.id);
    if (i >= 0) {
      all[i] = z;
    } else {
      all.add(z);
    }
    return _s.writeList(_k, all, (x) => x.toJson());
  }

  @override
  Future<void> deleteZone(String id) => _s.writeList(_k, _all().where((z) => z.id != id).toList(), (x) => x.toJson());
}

class LocalAlertRepository implements AlertRepository {
  LocalAlertRepository(this._s);
  final LocalStore _s;
  String _k(String petId) => 'alerts.$petId';

  @override
  Future<List<PetAlert>> getAlerts(String petId) async => _s.readList(_k(petId), PetAlert.fromJson);
  @override
  Future<void> addAlert(PetAlert a) {
    final l = [a, ..._s.readList(_k(a.petId), PetAlert.fromJson)];
    return _s.writeList(_k(a.petId), l.take(100).toList(), (x) => x.toJson());
  }

  @override
  Future<void> clear(String petId) => _s.remove(_k(petId));
}

class LocalLocationRepository implements LocationRepository {
  LocalLocationRepository(this._s);
  final LocalStore _s;
  String _k(String petId) => 'history.$petId';
  final Map<String, List<LocationHistory>> _cache = {};
  final Map<String, int> _pending = {};
  String _c(String petId) => '${_s.scope}|$petId';

  @override
  Future<List<LocationHistory>> getHistory(String petId) async =>
      List.of(_cache[_c(petId)] ??= _s.readList(_k(petId), LocationHistory.fromJson));

  void clearCache() {
    _cache.clear();
    _pending.clear();
  }

  @override
  Future<void> addLocation(LocationHistory e) async {
    final l = _cache[_c(e.petId)] ??= _s.readList(_k(e.petId), LocationHistory.fromJson);
    l.insert(0, e);
    if (l.length > 300) l.removeRange(300, l.length);
    final n = (_pending[_c(e.petId)] ?? 0) + 1;
    _pending[_c(e.petId)] = n % 10;
    if (n >= 10) await _s.writeList(_k(e.petId), l, (x) => x.toJson());
  }
}

class LocalContactRepository implements ContactRepository {
  LocalContactRepository(this._s);
  final LocalStore _s;
  static const _k = 'contacts';
  List<EmergencyContact> _all() => _s.readList(_k, EmergencyContact.fromJson);

  @override
  Future<List<EmergencyContact>> getContacts(String petId) async => _all().where((c) => c.petId == petId).toList();
  @override
  Future<void> addContact(EmergencyContact c) => _s.writeList(_k, [..._all(), c], (x) => x.toJson());
  @override
  Future<void> deleteContact(String id) =>
      _s.writeList(_k, _all().where((c) => c.id != id).toList(), (x) => x.toJson());
}

class LocalWalkRepository implements WalkRepository {
  LocalWalkRepository(this._s);
  final LocalStore _s;
  String _k(String petId) => 'walks.$petId';
  final Map<String, String> _petOf = {};

  @override
  Future<List<Walk>> getWalks(String petId) async {
    final l = _s.readList(_k(petId), Walk.fromJson)..sort((a, b) => b.start.compareTo(a.start));
    for (final w in l) {
      _petOf[w.id] = petId;
    }
    return l;
  }

  @override
  Future<void> saveWalk(Walk w) async {
    _petOf[w.id] = w.petId;
    final l = (await getWalks(w.petId)).where((x) => x.id != w.id).toList()..insert(0, w);
    await _s.writeList(_k(w.petId), l.take(50).toList(), (x) => x.toJson());
  }

  @override
  Future<void> deleteWalk(String id) async {
    final petId = _petOf[id];
    if (petId == null) return;
    final l = (await getWalks(petId)).where((x) => x.id != id).toList();
    await _s.writeList(_k(petId), l, (x) => x.toJson());
  }
}

class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this._s);
  final LocalStore _s;
  String _k(String petId) => 'activity.$petId';

  @override
  Future<List<DailyActivity>> getActivity(String petId) async => _s.readList(_k(petId), DailyActivity.fromJson);
  @override
  Future<void> saveDay(DailyActivity d) async {
    final l = (await getActivity(d.petId)).where((x) => x.day != d.day).toList()..add(d);
    l.sort((a, b) => a.day.compareTo(b.day));
    await _s.writeList(_k(d.petId), l.length > 60 ? l.sublist(l.length - 60) : l, (x) => x.toJson());
  }
}

class LocalHealthRepository implements HealthRepository {
  LocalHealthRepository(this._s);
  final LocalStore _s;
  static const _k = 'health';
  List<HealthRecord> _all() => _s.readList(_k, HealthRecord.fromJson);

  @override
  Future<List<HealthRecord>> getRecords(String petId) async =>
      _all().where((r) => r.petId == petId).toList()..sort((a, b) => b.date.compareTo(a.date));
  @override
  Future<void> saveRecord(HealthRecord r) =>
      _s.writeList(_k, [..._all().where((x) => x.id != r.id), r], (x) => x.toJson());
  @override
  Future<void> deleteRecord(String id) =>
      _s.writeList(_k, _all().where((x) => x.id != id).toList(), (x) => x.toJson());
}
