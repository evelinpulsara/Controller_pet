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

/// Usa Gemini si hay clave; si no, el asistente local de plantillas.
PetSafetyAiService _buildAiService() => _geminiApiKey.isEmpty
    ? MockPetSafetyAiService()
    : GeminiPetSafetyAiService(
        apiKey: _geminiApiKey,
        models: _geminiModel.isEmpty
            ? GeminiPetSafetyAiService.defaultModels
            : [_geminiModel, ...GeminiPetSafetyAiService.defaultModels],
        fallback: MockPetSafetyAiService());

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
