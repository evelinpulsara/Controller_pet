import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/activity/domain/daily_activity.dart';
import '../../features/alerts/domain/pet_alert.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/health/domain/health_record.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import '../../features/walks/domain/walk.dart';
import '../validation/collar_data.dart';

/// Repositorios que guardan en Supabase (esquema `pettracker`).
/// La seguridad la pone la base de datos (RLS): cada usuario solo ve lo suyo.
/// El cliente debe estar configurado con el esquema `pettracker` por defecto.

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double _d(Object? v, [double or = 0]) => v == null ? or : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();
DateTime _t(Object? v) => DateTime.parse(v as String).toLocal();

class SupabasePetRepository implements PetRepository {
  SupabasePetRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<List<Pet>> getPets() async {
    final rows = await _db.from('pets').select('*, tracker_devices(device_uid)').order('created_at');
    return [
      for (final r in rows)
        Pet(
          id: r['id'],
          name: r['name'],
          species: r['species'] ?? '',
          breed: r['breed'] ?? '',
          age: _i(r['age_years']) ?? 1,
          weight: _d(r['weight_kg'], 1),
          trackerId: ((r['tracker_devices'] as List?)?.isNotEmpty ?? false)
              ? (r['tracker_devices'] as List).first['device_uid']
              : '',
          colorValue: _i(r['color_argb']) ?? 0xFF2FB592,
          photo: r['photo_data'] == null ? null : base64Decode(r['photo_data']),
          dailyGoalMeters: _d(r['daily_goal_m'], 3000),
        ),
    ];
  }

  Map<String, dynamic> _row(Pet p) => {
        'id': p.id,
        'name': p.name,
        'species': p.species,
        'breed': p.breed,
        'age_years': p.age,
        'weight_kg': p.weight > 0 ? p.weight : null,
        'color_argb': p.colorValue,
        'photo_data': p.photo == null ? null : base64Encode(p.photo!),
        'daily_goal_m': p.dailyGoalMeters,
      };

  @override
  Future<void> addPet(Pet pet) async {
    await _db.from('pets').insert(_row(pet));
    if (pet.trackerId.isNotEmpty) {
      await _db.from('tracker_devices').insert({'pet_id': pet.id, 'device_uid': pet.trackerId});
    }
  }

  @override
  Future<void> updatePet(Pet pet) async {
    await _db.from('pets').update(_row(pet)..remove('id')).eq('id', pet.id);
    // Si cambió el código del collar, se actualiza (o se crea) su registro.
    final dev = await _db.from('tracker_devices').select('id, device_uid').eq('pet_id', pet.id).maybeSingle();
    if (dev == null && pet.trackerId.isNotEmpty) {
      await _db.from('tracker_devices').insert({'pet_id': pet.id, 'device_uid': pet.trackerId});
    } else if (dev != null && dev['device_uid'] != pet.trackerId) {
      await _db.from('tracker_devices').update({
        'device_uid': pet.trackerId,
        'device_key_hash': null, // collar nuevo: necesita su propia clave
        'is_online': false,
        'battery_level': null,
        'last_seen_at': null,
      }).eq('id', dev['id']);
    }
  }

  @override
  Future<void> deletePet(String id) => _db.from('pets').delete().eq('id', id);
}

class SupabaseTrackerRepository implements TrackerRepository {
  SupabaseTrackerRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<TrackerDevice> getTracker(String trackerId) async {
    final r = await _db.from('tracker_devices').select().eq('device_uid', trackerId).maybeSingle();
    if (r == null) {
      return TrackerDevice(id: trackerId, batteryLevel: 0, isConnected: false, lastUpdate: DateTime.fromMillisecondsSinceEpoch(0));
    }
    return TrackerDevice(
      id: trackerId,
      batteryLevel: _i(r['battery_level']) ?? 0,
      isConnected: r['is_online'] ?? false,
      lastUpdate: r['last_seen_at'] == null ? DateTime.fromMillisecondsSinceEpoch(0) : _t(r['last_seen_at']),
      powerSave: r['power_save'] ?? false,
      signal: _i(r['signal']) ?? 0,
    );
  }

  /// La app solo cambia lo que el dueño decide (modo ahorro). La batería y la
  /// conexión las escribe el collar real al enviar su ubicación.
  @override
  Future<void> saveTracker(TrackerDevice t) =>
      _db.from('tracker_devices').update({'power_save': t.powerSave}).eq('device_uid', t.id);

  /// El dueño le pone una clave secreta al collar (para que pueda enviar ubicaciones).
  Future<void> setDeviceKey(String deviceUid, String key) =>
      _db.rpc('set_device_key', params: {'p_device_uid': deviceUid, 'p_key': key});
}

class SupabaseSafeZoneRepository implements SafeZoneRepository {
  SupabaseSafeZoneRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<List<SafeZone>> getZones(String petId) async {
    final rows =
        await _db.from('safe_zones').select().eq('pet_id', petId).order('is_home', ascending: false).order('created_at');
    return [
      for (final r in rows)
        SafeZone(
          id: r['id'],
          petId: r['pet_id'],
          name: r['name'],
          latitude: _d(r['center_lat']),
          longitude: _d(r['center_lon']),
          radius: _d(r['radius_m'], 100),
          isEnabled: r['is_active'] ?? true,
        ),
    ];
  }

  @override
  Future<void> saveZone(SafeZone z) async {
    final existing = await _db.from('safe_zones').select('id').eq('pet_id', z.petId).limit(1);
    await _db.from('safe_zones').upsert({
      'id': z.id,
      'pet_id': z.petId,
      'name': z.name,
      'center_lat': z.latitude,
      'center_lon': z.longitude,
      'radius_m': z.radius.clamp(10, 50000),
      'is_active': z.isEnabled,
      // La primera zona de la mascota es su "Casa".
      if (existing.isEmpty || existing.first['id'] == z.id) 'is_home': true,
    });
  }

  @override
  Future<void> deleteZone(String id) => _db.from('safe_zones').delete().eq('id', id);
}

class SupabaseAlertRepository implements AlertRepository {
  SupabaseAlertRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<List<PetAlert>> getAlerts(String petId) async {
    final rows = await _db.from('alerts').select().eq('pet_id', petId).order('created_at', ascending: false).limit(100);
    return [
      for (final r in rows)
        PetAlert(
          id: r['id'],
          petId: r['pet_id'],
          type: AlertType.values.firstWhere((t) => t.name == r['alert_type'], orElse: () => AlertType.anomaly),
          message: r['message'] ?? '',
          timestamp: _t(r['created_at']),
          params: Map<String, String>.from((r['params'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
        ),
    ];
  }

  @override
  Future<void> addAlert(PetAlert a) => _db.from('alerts').insert({
        'id': a.id,
        'pet_id': a.petId,
        'alert_type': a.type.name,
        'params': a.params,
        'message': a.message,
        'created_at': a.timestamp.toUtc().toIso8601String(),
      });

  @override
  Future<void> clear(String petId) => _db.from('alerts').delete().eq('pet_id', petId);
}

class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository(this._db);
  final SupabaseClient _db;
