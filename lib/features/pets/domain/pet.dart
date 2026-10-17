import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import '../../../core/theme/pet_palette.dart';

class Pet {
  final String id, name, species, breed, trackerId, emergencyContact;
  final int age;
  final double weight;
  /// Color personal de la mascota (tiñe la app cuando está seleccionada).
  final int colorValue;
  /// Foto de perfil (null = se muestra la inicial del nombre).
  final Uint8List? photo;
  /// Meta diaria de distancia, en metros.
  final double dailyGoalMeters;
  const Pet({
    required this.id, required this.name, required this.species, required this.breed,
    required this.age, required this.weight, required this.trackerId,
    this.emergencyContact = '',
    this.colorValue = 0xFF2FB592,
    this.photo,
    this.dailyGoalMeters = 3000,
  });

  Color get color => Color(colorValue);

  Pet copyWith({String? name, String? species, String? breed, int? age, double? weight,
          Color? color, Uint8List? photo, String? trackerId, double? dailyGoalMeters}) =>
      Pet(
        id: id,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        age: age ?? this.age,
        weight: weight ?? this.weight,
        trackerId: trackerId ?? this.trackerId,
        emergencyContact: emergencyContact,
        colorValue: color?.toARGB32() ?? colorValue,
        photo: photo ?? this.photo,
        dailyGoalMeters: dailyGoalMeters ?? this.dailyGoalMeters,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'species': species, 'breed': breed, 'age': age, 'weight': weight,
        'trackerId': trackerId, 'emergencyContact': emergencyContact, 'color': colorValue,
        'photo': photo == null ? null : base64Encode(photo!), 'goal': dailyGoalMeters,
      };

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'], name: j['name'], species: j['species'] ?? '', breed: j['breed'] ?? '',
        age: (j['age'] as num?)?.toInt() ?? 1, weight: (j['weight'] as num?)?.toDouble() ?? 5,
        trackerId: j['trackerId'] ?? '', emergencyContact: j['emergencyContact'] ?? '',
        colorValue: (j['color'] as num?)?.toInt() ?? PetPalette.defaultColor.toARGB32(),
        photo: j['photo'] == null ? null : base64Decode(j['photo']),
        dailyGoalMeters: (j['goal'] as num?)?.toDouble() ?? 3000,
      );

  /// Meta sugerida según la especie.
  static double suggestedGoal(String species) {
    final s = species.toLowerCase();
    if (s.startsWith('gat') || s.startsWith('cat')) return 800;
    if (s.startsWith('perr') || s.startsWith('dog')) return 3000;
    return 1500;
  }
}

/// Color por defecto para mascotas nuevas.
const defaultPetColor = PetPalette.defaultColor;

/// Collar GPS de una mascota.
class TrackerDevice {
  final String id;
  final int batteryLevel;
  final bool isConnected;
  final DateTime lastUpdate;
  /// Modo ahorro: envía la ubicación con menos frecuencia para durar más.
  final bool powerSave;
  /// Calidad de señal de 0 a 4 (según la precisión del GPS).
  final int signal;
  const TrackerDevice({
    required this.id, required this.batteryLevel,
    required this.isConnected, required this.lastUpdate,
    this.powerSave = false, this.signal = 4,
  });
  TrackerDevice copyWith({int? batteryLevel, bool? isConnected, DateTime? lastUpdate, bool? powerSave, int? signal}) =>
      TrackerDevice(
        id: id,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        isConnected: isConnected ?? this.isConnected,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        powerSave: powerSave ?? this.powerSave,
        signal: signal ?? this.signal,
      );

  /// Horas aproximadas que le quedan a la batería.
  double get estimatedHoursLeft => batteryLevel * (powerSave ? 0.72 : 0.36);

  Map<String, dynamic> toJson() => {
        'id': id, 'battery': batteryLevel, 'connected': isConnected,
        'last': lastUpdate.toIso8601String(), 'powerSave': powerSave, 'signal': signal,
      };
  factory TrackerDevice.fromJson(Map<String, dynamic> j) => TrackerDevice(
        id: j['id'], batteryLevel: (j['battery'] as num?)?.toInt() ?? 100,
        isConnected: j['connected'] ?? true,
        lastUpdate: DateTime.tryParse(j['last'] ?? '') ?? DateTime.now(),
        powerSave: j['powerSave'] ?? false, signal: (j['signal'] as num?)?.toInt() ?? 4,
      );
}

/// Cambiar por versiones que usen la API del backend cuando esté lista.
abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
  Future<void> updatePet(Pet pet);
  Future<void> deletePet(String id);
}

abstract class TrackerRepository {
  Future<TrackerDevice> getTracker(String trackerId);
  Future<void> saveTracker(TrackerDevice tracker);
}
