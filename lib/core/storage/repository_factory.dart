import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';
import 'local_repositories.dart';
import 'local_store.dart';
import 'supabase_repositories.dart';
import 'switching_repositories.dart';

abstract class RepositoryFactory {
  PetRepository pets();
  TrackerRepository trackers();
  LocationRepository locations();
  SafeZoneRepository zones();
  AlertRepository alerts();
  ContactRepository contacts();
  WalkRepository walks();
  ActivityRepository activity();
  HealthRepository health();
}

class LocalRepositoryFactory implements RepositoryFactory {
  LocalRepositoryFactory(this.store);
  final LocalStore store;

  @override
  PetRepository pets() => LocalPetRepository(store);
  @override
  TrackerRepository trackers() => LocalTrackerRepository(store);
  @override
  LocationRepository locations() => LocalLocationRepository(store);
  @override
  SafeZoneRepository zones() => LocalSafeZoneRepository(store);
  @override
  AlertRepository alerts() => LocalAlertRepository(store);
  @override
  ContactRepository contacts() => LocalContactRepository(store);
  @override
  WalkRepository walks() => LocalWalkRepository(store);
  @override
  ActivityRepository activity() => LocalActivityRepository(store);
  @override
  HealthRepository health() => LocalHealthRepository(store);
}

class SupabaseRepositoryFactory implements RepositoryFactory {
  SupabaseRepositoryFactory(this.db);
  final SupabaseClient db;

  @override
  PetRepository pets() => SupabasePetRepository(db);
  @override
  TrackerRepository trackers() => SupabaseTrackerRepository(db);
  @override
  LocationRepository locations() => SupabaseLocationRepository(db);
  @override
  SafeZoneRepository zones() => SupabaseSafeZoneRepository(db);
  @override
  AlertRepository alerts() => SupabaseAlertRepository(db);
  @override
  ContactRepository contacts() => SupabaseContactRepository(db);
  @override
  WalkRepository walks() => SupabaseWalkRepository(db);
  @override
  ActivityRepository activity() => SupabaseActivityRepository(db);
  @override
  HealthRepository health() => SupabaseHealthRepository(db);
}

class SwitchingRepositoryFactory implements RepositoryFactory {
  SwitchingRepositoryFactory(this.mode, this.local, this.remote);
  final StorageMode mode;
  final RepositoryFactory local;
  final RepositoryFactory? remote;

  @override
  PetRepository pets() => SwitchingPetRepository(mode, local.pets(), remote?.pets());
  @override
  TrackerRepository trackers() => SwitchingTrackerRepository(mode, local.trackers(), remote?.trackers());
  @override
  LocationRepository locations() => SwitchingLocationRepository(mode, local.locations(), remote?.locations());
  @override
  SafeZoneRepository zones() => SwitchingSafeZoneRepository(mode, local.zones(), remote?.zones());
  @override
  AlertRepository alerts() => SwitchingAlertRepository(mode, local.alerts(), remote?.alerts());
  @override
  ContactRepository contacts() => SwitchingContactRepository(mode, local.contacts(), remote?.contacts());
  @override
  WalkRepository walks() => SwitchingWalkRepository(mode, local.walks(), remote?.walks());
  @override
  ActivityRepository activity() => SwitchingActivityRepository(mode, local.activity(), remote?.activity());
  @override
  HealthRepository health() => SwitchingHealthRepository(mode, local.health(), remote?.health());
}
