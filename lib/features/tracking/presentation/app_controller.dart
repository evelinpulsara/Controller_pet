import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/location/owner_location.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/sound/alert_sound.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/supabase_repositories.dart';
import '../../../core/storage/switching_repositories.dart';
import '../../../core/util/ids.dart';
import '../../authentication/data/auth_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../../activity/domain/daily_activity.dart';
import '../../alerts/domain/pet_alert.dart';
import '../../assistant/domain/pet_emergency.dart';
import '../../assistant/pet_safety_ai_service.dart';
import '../../authentication/domain/user.dart';
import '../../contacts/domain/emergency_contact.dart';
import '../../geofencing/domain/safe_zone.dart';
import '../../health/domain/health_record.dart';
import '../../pets/domain/pet.dart';
import '../../walks/domain/walk.dart';
import '../domain/location_data.dart';
import 'pet_session.dart';

typedef CollarFactory = LocationService Function(Pet pet, double homeLat, double homeLng, bool demo);

class AppController extends ChangeNotifier implements PetSessionListener {
  AppController({
    required this.store,
    required this.petRepository,
    required this.trackerRepository,
    required this.locationRepository,
    required this.safeZoneRepository,
    required this.alertRepository,
    required this.contactRepository,
    required this.walkRepository,
    required this.activityRepository,
    required this.healthRepository,
    required this.aiService,
    required this.collarFactory,
    AlertSound? sound,
    this.auth,
    StorageMode? storageMode,
  })  : sound = sound ?? SilentAlertSound(),
        storageMode = storageMode ?? StorageMode();

  final AuthService? auth;

  final StorageMode storageMode;

  bool get usesCloud => storageMode.remote;

  final AlertSound sound;

  final LocalStore store;
  final PetRepository petRepository;
  final TrackerRepository trackerRepository;
  final LocationRepository locationRepository;
  final SafeZoneRepository safeZoneRepository;
  final AlertRepository alertRepository;
  final ContactRepository contactRepository;
  final WalkRepository walkRepository;
  final ActivityRepository activityRepository;
  final HealthRepository healthRepository;
  final PetSafetyAiService aiService;
  final CollarFactory collarFactory;

  static const demoEmail = 'demo@pettracker.app';
  static const demoPassword = 'demo1234';

  User? user;
  List<Pet> pets = [];

  LatLng? ownerPosition;
  double? ownerAccuracy;
  StreamSubscription<OwnerFix>? _ownerSub;
  bool get ownerTracking => _ownerSub != null;
  bool _relocating = false;

  bool get isDemo => user?.email.toLowerCase() == demoEmail;

  static String userIdFor(String email) => email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  final Map<String, PetSession> sessions = {};
  String? _selectedId;

  bool notifyZone = true, notifyBattery = true, metric = true;
  int intervalSeconds = 3;
  String locale = 'es';
  ThemeMode themeMode = ThemeMode.system;
  String ownerPhone = '';
  bool onboarded = false;
  bool soundEnabled = true;

  int celebrateTick = 0;
  String celebratePetName = '';

  Future<void> init() async {
    final s = store.readGlobal('settings');
    if (s is Map) {
      notifyZone = s['notifyZone'] ?? true;
      notifyBattery = s['notifyBattery'] ?? true;
      metric = s['metric'] ?? true;
      intervalSeconds = (s['interval'] as num?)?.toInt() ?? 3;
      locale = s['locale'] ?? 'es';
      themeMode = ThemeMode.values.firstWhere((m) => m.name == s['theme'], orElse: () => ThemeMode.system);
      ownerPhone = s['ownerPhone'] ?? '';
      soundEnabled = s['sound'] ?? true;
    }
    onboarded = store.getGlobalBool('onboarded') ?? false;
    final u = store.readGlobal('user');
    if (u is Map) {
      final email = (u['email'] as String).toLowerCase();
      final demo = email == demoEmail;
      if (!demo && auth != null && auth!.currentEmail?.toLowerCase() != email) {
        await store.removeGlobal('user');
      } else {
        user = User(id: userIdFor(email), email: email, name: u['name']);
        storageMode.remote = !demo && auth != null;
        store.setScope(user!.id);
        try {
          await _loadPets();
        } catch (e) {
          debugPrint('[Datos] No se pudieron cargar las mascotas: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _saveSettings() => store.writeGlobal('settings', {
        'notifyZone': notifyZone, 'notifyBattery': notifyBattery, 'metric': metric,
        'interval': intervalSeconds, 'locale': locale, 'theme': themeMode.name, 'ownerPhone': ownerPhone,
        'sound': soundEnabled,
      });

  void setSoundEnabled(bool on) {
    soundEnabled = on;
    _saveSettings();
    notifyListeners();
  }

  void testAlarm() => sound.alarm();
  void testChime() => sound.chime();

  Future<LoginResult> login(String email, String password, {bool register = false}) async {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@') || password.length < 4) return const LoginResult(LoginStatus.invalid);
    final demo = clean == demoEmail;
    if (demo && password != demoPassword) return const LoginResult(LoginStatus.invalid);

    if (!demo && auth != null) {
      if (register && password.length < 6) {
        return const LoginResult(LoginStatus.error, 'La contraseña debe tener al menos 6 caracteres.');
      }
      final r = register ? await auth!.signUp(clean, password) : await auth!.signIn(clean, password);
      if (!r.ok) return r;
    }

    user = User(id: userIdFor(clean), email: clean, name: demo ? 'Demo' : clean.split('@').first);
    storageMode.remote = !demo && auth != null;
    await store.writeGlobal('user', {'id': user!.id, 'email': clean, 'name': user!.name});
    store.setScope(user!.id);
    _clearCaches();
    try {
      if (demo && (await petRepository.getPets()).isEmpty) await _seedDemo();
      await _loadPets();
    } catch (e) {
      notifyListeners();
      return LoginResult(LoginStatus.error, 'No se pudieron cargar tus datos: $e');
    }
    notifyListeners();
    return LoginResult.success;
  }

  Future<void> logout() async {
    for (final s in sessions.values) {
      s.stop();
    }
    sessions.clear();
    pets = [];
    user = null;
    _selectedId = null;
    _stopOwnerSub();
    await store.removeGlobal('user');
    store.setScope(null);
    _clearCaches();
    if (storageMode.remote) await auth?.signOut();
    storageMode.remote = false;
    notifyListeners();
  }

  bool get needsSetup => user != null && pets.isEmpty;

  Future<void> completeOnboarding() async {
    onboarded = true;
    await store.setGlobalBool('onboarded', true);
    notifyListeners();
  }

  Future<void> _loadPets() async {
    pets = await petRepository.getPets();
    for (final p in pets) {
      if (!sessions.containsKey(p.id)) await _startSession(p);
    }
    if (store.getBool('ownerLoc') == true) _resumeOwnerTracking();
    final saved = store.getString('selectedPet');
    _selectedId = pets.any((p) => p.id == saved) ? saved : (pets.isEmpty ? null : pets.first.id);
  }

  Future<void> _startSession(Pet p) async {
    var tracker = await trackerRepository.getTracker(p.trackerId);
    if (isDemo && tracker.batteryLevel == 0 && !tracker.isConnected) {
      tracker = tracker.copyWith(batteryLevel: 100, isConnected: true, lastUpdate: DateTime.now());
      await trackerRepository.saveTracker(tracker);
    }
    var zones = await safeZoneRepository.getZones(p.id);
    if (zones.isEmpty) {
      final z = SafeZone(
        id: newId(), petId: p.id, name: locale == 'es' ? 'Casa' : 'Home',
        latitude: AppConstants.homeLatitude, longitude: AppConstants.homeLongitude,
        radius: 100, isEnabled: true,
      );
      await safeZoneRepository.saveZone(z);
      zones = [z];
    }
    final home = zones.first;
    final s = PetSession(
      pet: p,
      tracker: tracker,
      service: collarFactory(p, home.latitude, home.longitude, isDemo),
      listener: this,
      zones: zones,
      history: await locationRepository.getHistory(p.id),
      alerts: await alertRepository.getAlerts(p.id),
      contacts: await contactRepository.getContacts(p.id),
      walks: await walkRepository.getWalks(p.id),
      activity: await activityRepository.getActivity(p.id),
      health: await healthRepository.getRecords(p.id),
    );
    sessions[p.id] = s;
    s.start(_intervalFor(tracker));
    _checkHealthReminders(s);
  }

  Duration _intervalFor(TrackerDevice t) => Duration(seconds: intervalSeconds * (t.powerSave ? 3 : 1));

  PetSession? get session => _selectedId == null ? null : sessions[_selectedId];
  Pet? get selectedPet => session?.pet;
  TrackerDevice? get tracker => session?.tracker;
  LocationData? get current => session?.current;
  List<SafeZone> get zones => session?.zones ?? const [];
  SafeZone? get zone => session?.homeZone;
  List<LocationHistory> get history => session?.history ?? const [];
  List<PetAlert> get alerts => session?.alerts ?? const [];
  bool get insideZone => session?.insideZone ?? true;
  List<EmergencyContact> get contacts => session?.contacts ?? const [];
  PetEmergency? get emergency => session?.emergency;
  List<Walk> get walks => session?.walks ?? const [];
  Walk? get activeWalk => session?.activeWalk;
  List<HealthRecord> get health => session?.health ?? const [];
  double? get distanceFromCenter => session?.distanceFromHome;
  bool get simulateLeaving => session?.simulateLeaving ?? false;
  bool get simulateFrozen => session?.simulateFrozen ?? false;
  bool get simulateSpeeding => session?.simulateSpeeding ?? false;

  List<PetEmergency> get activeEmergencies =>
      [for (final s in sessions.values) if (s.emergency?.isActive == true) s.emergency!];

  Future<void> selectPet(Pet p) async {
    _selectedId = p.id;
    await store.setString('selectedPet', p.id);
    notifyListeners();
  }

  void selectPetById(String id) {
    final p = pets.where((x) => x.id == id);
    if (p.isNotEmpty) selectPet(p.first);
  }

  Future<void> addPet(Pet p, {SafeZone? homeZone}) async {
    await petRepository.addPet(p);
    if (homeZone != null) await safeZoneRepository.saveZone(homeZone);
    pets = await petRepository.getPets();
    await _startSession(p);
    await selectPet(p);
  }

  Future<void> updatePet(Pet p) async {
    await petRepository.updatePet(p);
    pets = await petRepository.getPets();
    sessions[p.id]?.pet = p;
    notifyListeners();
  }

  Future<void> deletePet(String id) async {
    sessions.remove(id)?.stop();
    await petRepository.deletePet(id);
    pets = await petRepository.getPets();
    if (_selectedId == id) _selectedId = pets.isEmpty ? null : pets.first.id;
    notifyListeners();
  }

  void setLocale(String loc) {
    locale = loc;
    _saveSettings();
    notifyListeners();
    for (final s in sessions.values) {
      final e = s.emergency;
      if (e != null && e.isActive && !e.isWriting) _composeMessages(s, e);
    }
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _saveSettings();
    notifyListeners();
  }

  void setOwnerPhone(String phone) {
    ownerPhone = phone.trim();
    _saveSettings();
    notifyListeners();
  }

  void setPrefs({bool? zoneAlerts, bool? batteryAlerts, bool? isMetric, int? seconds}) {
    notifyZone = zoneAlerts ?? notifyZone;
    notifyBattery = batteryAlerts ?? notifyBattery;
    metric = isMetric ?? metric;
    if (seconds != null) {
      intervalSeconds = seconds;
      for (final s in sessions.values) {
        s.service.setInterval(_intervalFor(s.tracker));
      }
    }
    _saveSettings();
    notifyListeners();
  }

  Future<void> linkCollar(String code) async {
    final s = session;
    if (s == null) return;
    final p = s.pet.copyWith(trackerId: code.trim().toUpperCase());
    await petRepository.updatePet(p);
    pets = await petRepository.getPets();
    sessions.remove(p.id)?.stop();
    await _startSession(p);
    notifyListeners();
  }

  Future<void> setCollarKey(String key) async {
    final s = session;
    final r = trackerRepository;
    final active = r is SwitchingTrackerRepository ? r.active : r;
    if (s == null || active is! SupabaseTrackerRepository) {
      throw StateError('Solo disponible en cuentas conectadas a la base de datos');
    }
    await active.setDeviceKey(s.pet.trackerId, key);
  }

  Future<void> setPowerSave(bool on) async {
    final s = session;
    if (s == null) return;
    s.tracker = s.tracker.copyWith(powerSave: on);
    s.service.setInterval(_intervalFor(s.tracker));
    await trackerRepository.saveTracker(s.tracker);
    notifyListeners();
  }

  Future<void> saveZone(SafeZone z) async {
    final s = session;
    if (s == null) return;
    final zone = SafeZone(
        id: z.id, petId: s.pet.id, name: z.name, latitude: z.latitude, longitude: z.longitude,
        radius: z.radius, isEnabled: z.isEnabled);
    final oldHome = s.homeZone;
    await safeZoneRepository.saveZone(zone);
    s.zones = await safeZoneRepository.getZones(s.pet.id);
    final movedHome = oldHome != null &&
        oldHome.id == zone.id &&
        GeoUtils.distanceMeters(oldHome.latitude, oldHome.longitude, zone.latitude, zone.longitude) > 30;
    if (movedHome && s.mock != null) {
      sessions.remove(s.pet.id)?.stop();
      await _startSession(s.pet);
    }
    notifyListeners();
  }

  Future<void> deleteZone(String id) async {
    final s = session;
    if (s == null) return;
    await safeZoneRepository.deleteZone(id);
    s.zones = await safeZoneRepository.getZones(s.pet.id);
    notifyListeners();
  }

  void setSimulateLeaving(bool v) {
    final s = session;
    if (s == null || !isDemo) return;
    s.simulateLeaving = v;
    s.mock?.escaping = v;
    notifyListeners();
  }

  void setSimulateFrozen(bool v) {
    final s = session;
    if (s == null || !isDemo) return;
    s.simulateFrozen = v;
    s.mock?.frozen = v;
    notifyListeners();
  }

  void setSimulateSpeeding(bool v) {
    final s = session;
    if (s == null || !isDemo) return;
    s.simulateSpeeding = v;
    s.mock?.speeding = v;
    notifyListeners();
  }

  void toggleDisconnect() {
    final s = session;
    if (s == null || !isDemo) return;
    s.tracker = s.tracker.copyWith(isConnected: !s.tracker.isConnected);
    if (!s.tracker.isConnected) {
      _raise(s, AlertType.trackerDisconnected, {'tracker': s.tracker.id, 'pet': s.pet.name});
    }
    notifyListeners();
  }

  Future<void> fillSampleWeek() async {
    final s = session;
    if (s == null || !isDemo) return;
    final rnd = Random();
    final now = DateTime.now();
    for (var i = 1; i <= 6; i++) {
      final d = DailyActivity(
        petId: s.pet.id,
        day: DailyActivity.keyFor(now.subtract(Duration(days: i))),
        distanceMeters: s.pet.dailyGoalMeters * (0.4 + rnd.nextDouble() * 0.9),
        activeSeconds: (30 + rnd.nextInt(70)) * 60,
        sample: true,
      );
      await activityRepository.saveDay(d);
    }
    s.activity = await activityRepository.getActivity(s.pet.id);
    notifyListeners();
  }

  void startOwnerTracking(OwnerFix first) {
    store.setBool('ownerLoc', true);
    _setOwner(first);
    _ownerSub?.cancel();
    _ownerSub = OwnerLocation.watch().listen((f) {
      if (f.ok) _setOwner(f);
    }, onError: (_) {});
    notifyListeners();
  }

  void stopOwnerTracking() {
    store.setBool('ownerLoc', false);
    _stopOwnerSub();
    notifyListeners();
  }

  void _stopOwnerSub() {
    _ownerSub?.cancel();
    _ownerSub = null;
    ownerPosition = null;
    ownerAccuracy = null;
  }

  Future<void> _resumeOwnerTracking() async {
    final fix = await OwnerLocation.current();
    if (fix.ok && user != null && !_disposed) startOwnerTracking(fix);
  }

  void _setOwner(OwnerFix f) {
    ownerPosition = f.position;
    ownerAccuracy = f.accuracyMeters;
    notifyListeners();
    if (isDemo && store.getBool('demoPlaced') != true && f.position != null) relocateDemoTo(f.position!);
  }

  Future<void> relocateDemoTo(LatLng to) async {
    if (!isDemo || _relocating) return;
    final home = sessions.values.map((s) => s.homeZone).whereType<SafeZone>().firstOrNull;
    if (home == null) return;
    _relocating = true;
    try {
      await store.setBool('demoPlaced', true);
      final dLat = to.latitude - home.latitude, dLng = to.longitude - home.longitude;
      if (dLat.abs() < 1e-6 && dLng.abs() < 1e-6) return;
      for (final s in sessions.values.toList()) {
        for (final z in s.zones) {
          await safeZoneRepository.saveZone(z.copyWith(latitude: z.latitude + dLat, longitude: z.longitude + dLng));
        }
        for (final w in await walkRepository.getWalks(s.pet.id)) {
          await walkRepository.saveWalk(w.copyWith(points: [
            for (final p in w.points)
              LocationData(latitude: p.latitude + dLat, longitude: p.longitude + dLng, accuracy: p.accuracy, timestamp: p.timestamp),
          ]));
        }
        sessions.remove(s.pet.id)?.stop();
        await _startSession(s.pet);
      }
    } finally {
      _relocating = false;
      notifyListeners();
    }
  }

  void _clearCaches() {
    final r = locationRepository;
    try {
      (r as dynamic).clearCache();
    } catch (_) {}
  }

  Future<void> resetDemo() async {
    if (!isDemo) return;
    for (final s in sessions.values) {
      s.stop();
    }
    sessions.clear();
    await store.clearScope();
    _clearCaches();
    await _seedDemo();
    await _loadPets();
    if (ownerTracking) {
      await store.setBool('ownerLoc', true);
      if (ownerPosition != null) await relocateDemoTo(ownerPosition!);
    }
    notifyListeners();
  }

  Future<void> _seedDemo() async {
    const lat = AppConstants.homeLatitude, lng = AppConstants.homeLongitude;
    final now = DateTime.now();
    const luna = Pet(id: 'demo-luna', name: 'Luna', species: 'Perro', breed: 'Labrador', age: 3, weight: 24,
        trackerId: 'DEMO-1001', colorValue: 0xFF2FB592);
    const iker = Pet(id: 'demo-iker', name: 'Iker', species: 'Gato', breed: 'Criollo', age: 2, weight: 4.2,
        trackerId: 'DEMO-2002', colorValue: 0xFF8F6EEB, dailyGoalMeters: 800);
    for (final p in [luna, iker]) {
      await petRepository.addPet(p);
      await safeZoneRepository.saveZone(SafeZone(
          id: 'z-${p.id}', petId: p.id, name: 'Casa', latitude: lat, longitude: lng, radius: 100, isEnabled: true));
    }
    await safeZoneRepository.saveZone(const SafeZone(
        id: 'z-demo-parque', petId: 'demo-luna', name: 'Parque', latitude: lat + 0.0016, longitude: lng + 0.0017,
        radius: 80, isEnabled: true));
    for (final r in [
      HealthRecord(id: 'h-demo-1', petId: 'demo-luna', type: HealthType.vaccine, title: 'Rabia',
          date: now.subtract(const Duration(days: 362)), nextDue: now.add(const Duration(days: 3))),
      HealthRecord(id: 'h-demo-2', petId: 'demo-luna', type: HealthType.deworming, title: 'Desparasitante interno',
          date: now.subtract(const Duration(days: 60)), nextDue: now.add(const Duration(days: 30))),
      HealthRecord(id: 'h-demo-3', petId: 'demo-iker', type: HealthType.vet, title: 'Control anual',
          date: now.subtract(const Duration(days: 120))),
    ]) {
      await healthRepository.saveRecord(r);
    }
    final rnd = Random(7);
    for (final p in [luna, iker]) {
      for (var i = 1; i <= 6; i++) {
        await activityRepository.saveDay(DailyActivity(
          petId: p.id,
          day: DailyActivity.keyFor(now.subtract(Duration(days: i))),
          distanceMeters: p.dailyGoalMeters * (0.4 + rnd.nextDouble() * 0.9),
          activeSeconds: (30 + rnd.nextInt(70)) * 60,
          sample: true,
        ));
      }
    }
    final start = now.subtract(const Duration(days: 1, hours: 2));
    await walkRepository.saveWalk(Walk(
      id: 'w-demo-1', petId: 'demo-luna', start: start, end: start.add(const Duration(minutes: 24)),
      points: [
        for (var i = 0; i <= 40; i++)
          LocationData(
            latitude: lat + 0.0022 * sin(i / 40 * 2 * pi),
            longitude: lng + 0.0030 * (1 - cos(i / 40 * 2 * pi)) / 2,
            accuracy: 5,
            timestamp: start.add(Duration(seconds: i * 36)),
          ),
      ],
    ));
  }

  @override
  void onSessionChanged(PetSession s) => notifyListeners();

  @override
  void onLeftAllZones(PetSession s) {
    if (s.activeWalk != null) return;
    if (!notifyZone) return;
    _raise(s, AlertType.leftSafeZone, {'pet': s.pet.name, 'zone': s.nearestZoneName});
    if (s.isNight) _raise(s, AlertType.anomaly, {'kind': 'night', 'pet': s.pet.name});
    _startEmergency(s);
  }

  @override
  void onBackInZone(PetSession s) {
    if (s.activeWalk != null) return;
    if (notifyZone) _raise(s, AlertType.enteredSafeZone, {'pet': s.pet.name});
    final e = s.emergency;
    if (e != null && e.isActive && !e.manual) {
      e.resolvedAt = DateTime.now();
      _celebrate(s);
    }
  }

  @override
  void onAlert(PetSession s, AlertType type, Map<String, String> params) {
    if (type == AlertType.lowBattery && !notifyBattery) return;
    _raise(s, type, params);
  }

  @override
  void onLocationSaved(PetSession s, LocationHistory entry) =>
      locationRepository.addLocation(entry).catchError((e) => debugPrint('[Datos] ubicación no guardada: $e'));

  @override
  void onActivityChanged(PetSession s, DailyActivity today) =>
      activityRepository.saveDay(today).catchError((e) => debugPrint('[Datos] actividad no guardada: $e'));

  @override
  void onTrackerChanged(PetSession s) =>
      trackerRepository.saveTracker(s.tracker).catchError((e) => debugPrint('[Datos] collar no guardado: $e'));

  @override
  void onWalkPoint(PetSession s) {}

  void _raise(PetSession s, AlertType type, Map<String, String> params) {
    final msg = AppL10n.fromLocale(locale).alertMessage(type, params);
    final a = PetAlert(
        id: newId(), petId: s.pet.id, type: type,
        message: msg, timestamp: DateTime.now(), params: params);
    s.alerts.insert(0, a);
    alertRepository.addAlert(a).catchError((e) => debugPrint('[Datos] alerta no guardada: $e'));
    _playFor(type);
    notifyListeners();
  }

  void _playFor(AlertType type) {
    if (!soundEnabled) return;
    switch (type) {
      case AlertType.leftSafeZone || AlertType.anomaly || AlertType.trackerDisconnected:
        sound.alarm();
      case AlertType.enteredSafeZone || AlertType.lowBattery || AlertType.gpsLost:
        sound.chime();
      case AlertType.healthReminder:
        break;
    }
  }

  Future<void> clearAlerts() async {
    final s = session;
    if (s == null) return;
    await alertRepository.clear(s.pet.id);
    s.alerts = [];
    notifyListeners();
  }

  void _celebrate(PetSession s) {
    celebratePetName = s.pet.name;
    celebrateTick++;
    notifyListeners();
  }

  void _startEmergency(PetSession s, {bool manual = false}) {
    if (s.emergency?.isActive == true) return;
    final now = DateTime.now();
    final e = PetEmergency(
        id: '${s.pet.id}-${now.microsecondsSinceEpoch}', petId: s.pet.id,
        report: _reportFor(s, time: now), manual: manual);
    s.emergency = e;
    notifyListeners();
    _composeMessages(s, e);
  }

  void startLostMode() {
    final s = session;
    if (s == null) return;
    _startEmergency(s, manual: true);
  }

  void markFound() {
    final s = session;
    final e = s?.emergency;
    if (s == null || e == null || !e.isActive) return;
    e.resolvedAt = DateTime.now();
    _celebrate(s);
  }

  LostPetReport _reportFor(PetSession s, {DateTime? time}) {
    final l = s.current;
    final home = s.homeZone;
    return LostPetReport(
      petName: s.pet.name, species: s.pet.species, breed: s.pet.breed, age: s.pet.age,
      ownerName: user?.name ?? '', zoneName: s.nearestZoneName,
      distanceOutsideMeters: s.metersOutside, batteryLevel: s.tracker.batteryLevel,
      latitude: l?.latitude ?? home?.latitude ?? AppConstants.homeLatitude,
      longitude: l?.longitude ?? home?.longitude ?? AppConstants.homeLongitude,
      time: time ?? DateTime.now(), locale: locale,
    );
  }

  Future<void> _composeMessages(PetSession s, PetEmergency e) async {
    final r = _reportFor(s, time: e.report.time);
    e.messages = null;
    notifyListeners();
    final m = await aiService.composeLostPetAlert(r);
    if (s.emergency != e) return;
    e.messages = m;
    notifyListeners();
  }

  Future<void> requestPoster() async {
    final s = session;
    final e = s?.emergency;
    if (s == null || e == null || e.posterLoading) return;
    e.posterLoading = true;
    notifyListeners();
    try {
      e.poster = await aiService.composePoster(_reportFor(s, time: e.report.time));
    } finally {
      e.posterLoading = false;
      notifyListeners();
    }
  }

  String contactMessageNow([PetSession? which]) {
    final s = which ?? session;
    final e = s?.emergency;
    if (s == null || e == null || e.messages == null) return '';
    final base = e.messages!.contactMessage.split('\n\n📍').first;
    return withLocation(base, _reportFor(s, time: e.report.time));
  }

  String foundMessage() {
    final name = session?.pet.name ?? '';
    return locale == 'es'
        ? '✅ ¡Buenas noticias! $name ya regresó a casa y está bien. ¡Muchas gracias por estar pendiente y ayudarme! 🐾'
        : '✅ Good news! $name is back home and safe. Thank you so much for keeping an eye out! 🐾';
  }

  void markNotified(String contactId) {
    emergency?.notifiedContactIds.add(contactId);
    notifyListeners();
  }

  void markThanked(String contactId) {
    emergency?.thankedContactIds.add(contactId);
    notifyListeners();
  }

  void dismissEmergency() {
    session?.emergency = null;
    notifyListeners();
  }

  Future<void> addContact(EmergencyContact ct) async {
    await contactRepository.addContact(ct);
    final s = sessions[ct.petId];
    if (s != null) s.contacts = await contactRepository.getContacts(ct.petId);
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    final s = session;
    if (s == null) return;
    await contactRepository.deleteContact(id);
    s.contacts = await contactRepository.getContacts(s.pet.id);
    notifyListeners();
  }

  void startWalk() {
    final s = session;
    if (s == null || s.activeWalk != null) return;
    final now = DateTime.now();
    s.activeWalk = Walk(
        id: newId(), petId: s.pet.id, start: now,
        points: [if (s.current != null) s.current!]);
    s.mock?.walking = true;
    notifyListeners();
  }

  Future<Walk?> stopWalk() async {
    final s = session;
    final w = s?.activeWalk;
    if (s == null || w == null) return null;
    final done = w.copyWith(end: DateTime.now());
    s.activeWalk = null;
    s.mock?.walking = false;
    await walkRepository.saveWalk(done);
    s.walks = await walkRepository.getWalks(s.pet.id);
    notifyListeners();
    return done;
  }

  Future<void> deleteWalk(String id) async {
    final s = session;
    if (s == null) return;
    await walkRepository.deleteWalk(id);
    s.walks = await walkRepository.getWalks(s.pet.id);
    notifyListeners();
  }

  DailyActivity get today =>
      session?.today ?? DailyActivity(petId: '', day: DailyActivity.keyFor(DateTime.now()));

  List<DailyActivity> get lastSevenDays {
    final s = session;
    if (s == null) return const [];
    final now = DateTime.now();
    final out = <DailyActivity>[];
    for (var i = 6; i >= 0; i--) {
      final k = DailyActivity.keyFor(now.subtract(Duration(days: i)));
      out.add(i == 0
          ? s.today
          : s.activity.firstWhere((d) => d.day == k, orElse: () => DailyActivity(petId: s.pet.id, day: k)));
    }
    return out;
  }

  List<Walk> get walksToday {
    final k = DailyActivity.keyFor(DateTime.now());
    return walks.where((w) => DailyActivity.keyFor(w.start) == k).toList();
  }

  Future<void> requestDaySummary() async {
    final s = session;
    if (s == null || s.summaryLoading) return;
    s.summaryLoading = true;
    notifyListeners();
    final k = DailyActivity.keyFor(DateTime.now());
    final wt = walksToday;
    final alertsToday = s.alerts.where((a) => DailyActivity.keyFor(a.timestamp) == k).toList();
    final l = AppL10n.fromLocale(locale);
    try {
      final stream = aiService.summarizeDayStream(DaySummaryInput(
        petName: s.pet.name,
        species: s.pet.species,
        distanceMeters: s.today.distanceMeters,
        goalMeters: s.pet.dailyGoalMeters,
        activeMinutes: s.today.activeMinutes,
        walks: wt.length,
        walkMinutes: wt.fold(0, (t, w) => t + w.duration.inMinutes),
        alertsToday: alertsToday.length,
        minutesOutside: s.minutesOutsideToday,
        placesVisited: s.placesToday,
        unusual: [
          for (final a in alertsToday.where((a) => a.type == AlertType.anomaly)) l.alertMessage(a.type, a.params)
        ],
        locale: locale,
      ));
      await for (final partial in stream) {
        s.daySummary = partial;
        s.daySummaryDay = k;
        s.summaryLoading = false;
        notifyListeners();
      }
      s.daySummaryDay = k;
    } finally {
      s.summaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDailyGoal(double meters) async {
    final p = selectedPet;
    if (p == null) return;
    await updatePet(p.copyWith(dailyGoalMeters: meters));
  }

  Future<void> saveHealthRecord(HealthRecord r) async {
    await healthRepository.saveRecord(r);
    final s = sessions[r.petId];
    if (s != null) {
      s.health = await healthRepository.getRecords(r.petId);
      _checkHealthReminders(s);
    }
    notifyListeners();
  }

  Future<void> deleteHealthRecord(String id) async {
    final s = session;
    if (s == null) return;
    await healthRepository.deleteRecord(id);
    s.health = await healthRepository.getRecords(s.pet.id);
    notifyListeners();
  }

  List<HealthRecord> get reminders =>
      health.where((r) => r.needsAttention).toList()..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

  void _checkHealthReminders(PetSession s) {
    final today = DailyActivity.keyFor(DateTime.now());
    for (final r in s.health.where((r) => r.needsAttention)) {
      final key = 'remind.${r.id}';
      if (store.getString(key) == today) continue;
      store.setString(key, today);
      _raise(s, AlertType.healthReminder, {'pet': s.pet.name, 'title': r.title, 'days': '${r.daysUntilDue()}'});
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in sessions.values) {
      s.stop();
    }
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
