class LocationData {
  final double latitude, longitude, accuracy;
  final DateTime timestamp;
  /// Batería del collar en ese momento (si el collar la envía).
  final int? battery;
  const LocationData({required this.latitude, required this.longitude, required this.timestamp, required this.accuracy, this.battery});

  Map<String, dynamic> toJson() =>
      {'lat': latitude, 'lng': longitude, 'acc': accuracy, 't': timestamp.toIso8601String()};
  factory LocationData.fromJson(Map<String, dynamic> j) => LocationData(
        latitude: (j['lat'] as num).toDouble(), longitude: (j['lng'] as num).toDouble(),
        accuracy: (j['acc'] as num?)?.toDouble() ?? 5, timestamp: DateTime.parse(j['t']));
}

class LocationHistory {
  final String id, petId, status;
  final LocationData location;
  const LocationHistory({required this.id, required this.petId, required this.location, required this.status});

  bool get inside => status.startsWith('Inside');

  Map<String, dynamic> toJson() => {'id': id, 'petId': petId, 'status': status, 'loc': location.toJson()};
  factory LocationHistory.fromJson(Map<String, dynamic> j) => LocationHistory(
        id: j['id'], petId: j['petId'], status: j['status'] ?? 'Inside safe zone',
        location: LocationData.fromJson(Map<String, dynamic>.from(j['loc'])));
}

/// Fuente de ubicaciones de UN collar. Hoy es simulada ([MockLocationService]);
/// cuando el GPS real esté listo, se cambia por una que lea del collar o del backend.
abstract class LocationService {
  Future<LocationData> getCurrentLocation();
  Stream<LocationData> watchLocation();
  void setInterval(Duration d) {}
  void dispose() {}
}

abstract class LocationRepository {
  Future<List<LocationHistory>> getHistory(String petId);
  Future<void> addLocation(LocationHistory entry);
}
