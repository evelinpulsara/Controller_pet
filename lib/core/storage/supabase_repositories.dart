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
