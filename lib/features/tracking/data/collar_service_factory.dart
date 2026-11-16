import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/storage/switching_repositories.dart';
import '../../pets/domain/pet.dart';
import '../domain/location_data.dart';
import 'future_location_services.dart';
import 'mock_location_service.dart';
import 'supabase_collar_service.dart';

class CollarServiceFactory {
  CollarServiceFactory({required this.mode, this.db});

  final StorageMode mode;
  final SupabaseClient? db;

  LocationService create(Pet pet, double homeLat, double homeLng, bool demo) {
    if (demo) return MockLocationService(homeLat: homeLat, homeLng: homeLng, seed: pet.id.hashCode);
    final client = db;
    if (client != null && mode.remote) return SupabaseCollarService(client, pet.id);
    return PendingCollarService(pet.trackerId);
  }
}
