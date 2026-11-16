import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/perf/perf_monitor.dart';
import 'core/routes/app_routes.dart';
import 'core/sound/alert_sound.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/storage/repository_factory.dart';
import 'core/storage/switching_repositories.dart';
import 'core/supabase/supabase_config.dart';
import 'features/authentication/data/auth_service.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/pet_palette.dart';
import 'features/assistant/ai_service_factory.dart';
import 'features/assistant/pet_safety_ai_service.dart';
import 'features/tracking/data/collar_service_factory.dart';
import 'features/tracking/presentation/app_controller.dart';

const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const _geminiModel = String.fromEnvironment('GEMINI_MODEL');
const _backendUrl = String.fromEnvironment('BACKEND_URL');

AppController buildController(LocalStore store, {PetSafetyAiService? ai, AlertSound? sound, SupabaseClient? db}) {
  final mode = StorageMode();
  final repos = SwitchingRepositoryFactory(
    mode,
    LocalRepositoryFactory(store),
    db == null ? null : SupabaseRepositoryFactory(db),
  );
  const aiFactory = AiServiceFactory(backendUrl: _backendUrl, geminiKey: _geminiApiKey, geminiModel: _geminiModel);
  return AppController(
    store: store,
    storageMode: mode,
    auth: db == null ? null : SupabaseAuthService(db),
    petRepository: repos.pets(),
    trackerRepository: repos.trackers(),
    locationRepository: repos.locations(),
    safeZoneRepository: repos.zones(),
    alertRepository: repos.alerts(),
    contactRepository: repos.contacts(),
    walkRepository: repos.walks(),
    activityRepository: repos.activity(),
    healthRepository: repos.health(),
    aiService: ai ?? aiFactory.create(),
    sound: sound ?? AudioAlertSound(),
    collarFactory: CollarServiceFactory(mode: mode, db: db).create,
  );
}

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
  PerfMonitor.instance.start();
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
