import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/perf/perf_monitor.dart';
import 'core/routes/app_routes.dart';
import 'core/sound/alert_sound.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/storage/local_repositories.dart';
import 'core/storage/supabase_repositories.dart';
import 'core/storage/switching_repositories.dart';
import 'core/supabase/supabase_config.dart';
import 'features/authentication/data/auth_service.dart';
import 'features/tracking/data/supabase_collar_service.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/pet_palette.dart';
import 'features/assistant/backend_pet_ai_service.dart';
import 'features/assistant/gemini_pet_safety_ai_service.dart';
import 'features/assistant/pet_safety_ai_service.dart';
import 'features/tracking/data/future_location_services.dart';
import 'features/tracking/data/mock_location_service.dart';
import 'features/tracking/presentation/app_controller.dart';

/// Clave de Gemini, se lee de secrets.json al correr la app:
///   flutter run -d chrome --dart-define-from-file=secrets.json
const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
/// Opcional: forzar un modelo concreto con GEMINI_MODEL en secrets.json.
const _geminiModel = String.fromEnvironment('GEMINI_MODEL');

/// Dirección del backend en Render (si existe, la IA pasa por él y la app
/// no necesita la clave de Gemini). Se define al compilar:
///   --dart-define=BACKEND_URL=https://tu-backend.onrender.com
const _backendUrl = String.fromEnvironment('BACKEND_URL');

/// IA: backend (Render) > Gemini directo (desarrollo) > plantillas locales.
PetSafetyAiService _buildAiService() {
  if (_backendUrl.isNotEmpty) {
    return BackendPetAiService(baseUrl: _backendUrl, fallback: MockPetSafetyAiService());
  }
  if (_geminiApiKey.isNotEmpty) {
    return GeminiPetSafetyAiService(
        apiKey: _geminiApiKey,
        models: _geminiModel.isEmpty
            ? GeminiPetSafetyAiService.defaultModels
            : [_geminiModel, ...GeminiPetSafetyAiService.defaultModels],
        fallback: MockPetSafetyAiService());
  }
  return MockPetSafetyAiService();
}

/// Construye el controlador con todo lo que necesita.
/// Aquí es donde se cambian las piezas simuladas por las reales:
///  - Repositorios locales  -> versiones que usen la API del backend.
///  - MockLocationService   -> el servicio del collar GPS real.
AppController buildController(LocalStore store, {PetSafetyAiService? ai, AlertSound? sound, SupabaseClient? db}) {
  final mode = StorageMode();
  // Cuenta demo -> todo en el dispositivo. Cuentas reales -> Supabase (si hay conexión configurada).
  return AppController(
    store: store,
    storageMode: mode,
    auth: db == null ? null : SupabaseAuthService(db),
    petRepository: SwitchingPetRepository(mode, LocalPetRepository(store), db == null ? null : SupabasePetRepository(db)),
    trackerRepository:
        SwitchingTrackerRepository(mode, LocalTrackerRepository(store), db == null ? null : SupabaseTrackerRepository(db)),
    locationRepository:
        SwitchingLocationRepository(mode, LocalLocationRepository(store), db == null ? null : SupabaseLocationRepository(db)),
    safeZoneRepository:
        SwitchingSafeZoneRepository(mode, LocalSafeZoneRepository(store), db == null ? null : SupabaseSafeZoneRepository(db)),
    alertRepository: SwitchingAlertRepository(mode, LocalAlertRepository(store), db == null ? null : SupabaseAlertRepository(db)),
    contactRepository:
        SwitchingContactRepository(mode, LocalContactRepository(store), db == null ? null : SupabaseContactRepository(db)),
    walkRepository: SwitchingWalkRepository(mode, LocalWalkRepository(store), db == null ? null : SupabaseWalkRepository(db)),
    activityRepository:
        SwitchingActivityRepository(mode, LocalActivityRepository(store), db == null ? null : SupabaseActivityRepository(db)),
    healthRepository:
        SwitchingHealthRepository(mode, LocalHealthRepository(store), db == null ? null : SupabaseHealthRepository(db)),
    aiService: ai ?? _buildAiService(),
    sound: sound ?? AudioAlertSound(),
    // Cuenta demo: collar SIMULADO (se mueve solo, para probar).
    // Cuentas reales: collar real; sus ubicaciones llegan a Supabase (report_location)
    // y la app las lee de ahí. Sin Supabase, el collar queda esperando señal.
    collarFactory: (pet, lat, lng, demo) {
      if (demo) return MockLocationService(homeLat: lat, homeLng: lng, seed: pet.id.hashCode);
      if (db != null && mode.remote) return SupabaseCollarService(db, pet.id);
      return PendingCollarService(pet.trackerId);
    },
  );
}

/// Conecta con Supabase (esquema `pettracker`). Si falla, la app sigue funcionando sin la nube.
Future<SupabaseClient?> _connectSupabase() async {
  if (!SupabaseConfig.configured) return null;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      postgrestOptions: const PostgrestClientOptions(schema: SupabaseConfig.schema),
    );
    return Supabase.instance.client;
  } catch (e) {
    debugPrint('[Supabase] No se pudo iniciar: $e');
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final db = await _connectSupabase();
  final controller = buildController(store, db: db);
  PerfMonitor.instance.start(); // mide el INP desde el inicio
  await controller.init();
  runApp(PetTrackerApp(controller: controller));
}

class PetTrackerApp extends StatelessWidget {
  const PetTrackerApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            final accent = controller.selectedPet?.color ?? PetPalette.defaultColor;
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              // El color de la mascota seleccionada tiñe toda la app (con transición).
              theme: AppTheme.light(accent),
              darkTheme: AppTheme.dark(accent),
              themeMode: controller.themeMode,
              themeAnimationDuration: const Duration(milliseconds: 600),
              themeAnimationCurve: Curves.easeInOutCubic,
              locale: Locale(controller.locale),
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              initialRoute: AppRoutes.splash,
              routes: AppRoutes.routes,
            );
          },
        ),
      );
}
