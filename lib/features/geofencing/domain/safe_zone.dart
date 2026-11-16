class SafeZone {
  final String id, petId, name;
  final double latitude, longitude, radius;
  final bool isEnabled;
  const SafeZone({
    required this.id,
    this.petId = '',
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isEnabled,
  });
  SafeZone copyWith({String? name, double? radius, bool? isEnabled, double? latitude, double? longitude}) =>
      SafeZone(
        id: id, petId: petId, name: name ?? this.name,
        latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude,
        radius: radius ?? this.radius, isEnabled: isEnabled ?? this.isEnabled);

  Map<String, dynamic> toJson() => {
        'id': id, 'petId': petId, 'name': name, 'lat': latitude, 'lng': longitude,
        'radius': radius, 'enabled': isEnabled,
      };
  factory SafeZone.fromJson(Map<String, dynamic> j) => SafeZone(
        id: j['id'], petId: j['petId'] ?? '', name: j['name'] ?? '',
        latitude: (j['lat'] as num).toDouble(), longitude: (j['lng'] as num).toDouble(),
        radius: (j['radius'] as num).toDouble(), isEnabled: j['enabled'] ?? true,
      );
}

abstract class SafeZoneRepository {
  Future<List<SafeZone>> getZones(String petId);
  Future<void> saveZone(SafeZone zone);
  Future<void> deleteZone(String id);
}
