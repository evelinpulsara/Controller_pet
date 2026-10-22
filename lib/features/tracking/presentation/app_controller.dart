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

/// Crea el servicio de ubicación del collar de una mascota.
/// Hoy devuelve un collar simulado; con el GPS real, devuelve el servicio real.
/// [demo] = true solo en la cuenta demo (collar simulado).
typedef CollarFactory = LocationService Function(Pet pet, double homeLat, double homeLng, bool demo);

/// Controlador principal: usuario, mascotas, configuración y una
/// [PetSession] por mascota (todas vigiladas al mismo tiempo).
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

  /// Inicio de sesión de las cuentas reales (Supabase). null = sin conexión a Supabase.
  final AuthService? auth;

  /// Dónde se guardan los datos: demo -> dispositivo; cuentas reales -> Supabase.
  final StorageMode storageMode;

  /// ¿Los datos de este usuario se guardan en Supabase?
  bool get usesCloud => storageMode.remote;

  /// Alarma y timbre de la app.
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

  /// Cuenta demo: la única con collar simulado, datos de ejemplo y Modo prueba.
  static const demoEmail = 'demo@pettracker.app';
  static const demoPassword = 'demo1234';

  User? user;
  List<Pet> pets = [];

  // ── Ubicación del dueño (punto azul) ──────────────────────────────────────
  LatLng? ownerPosition;
  double? ownerAccuracy;
  StreamSubscription<OwnerFix>? _ownerSub;
  bool get ownerTracking => _ownerSub != null;
  bool _relocating = false;

  /// ¿Es la cuenta demo?
  bool get isDemo => user?.email.toLowerCase() == demoEmail;

  /// Identificador del espacio de datos de cada usuario (según su correo).
  static String userIdFor(String email) => email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  final Map<String, PetSession> sessions = {};
  String? _selectedId;

  // Configuración (se guarda en el dispositivo)
  bool notifyZone = true, notifyBattery = true, metric = true;
  int intervalSeconds = 3;
  String locale = 'es';
  ThemeMode themeMode = ThemeMode.system;
  String ownerPhone = '';
  bool onboarded = false;
  /// Sonar la alarma con las alertas importantes.
  bool soundEnabled = true;

  /// Sube en 1 cada vez que una mascota vuelve a casa tras una emergencia (para celebrar).
  int celebrateTick = 0;
  String celebratePetName = '';

  // ── Arranque ──────────────────────────────────────────────────────────────

  /// Carga la configuración y, si había sesión abierta, la recupera.
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
      // Cuenta real: solo se recupera si Supabase todavía tiene la sesión abierta.
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
