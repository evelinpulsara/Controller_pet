enum AlertType {
  leftSafeZone,
  enteredSafeZone,
  lowBattery,
  gpsLost,
  trackerDisconnected,
  /// Comportamiento fuera de lo normal (sin moverse mucho rato, muy rápido, de noche fuera...).
  anomaly,
  /// Vacuna, desparasitación o cita próxima.
  healthReminder,
}

class PetAlert {
  final String id, petId, message;
  final AlertType type;
  final DateTime timestamp;
  /// Datos para armar el mensaje en el idioma elegido (nombre, zona, batería...).
  final Map<String, String> params;
  const PetAlert({required this.id, required this.petId, required this.type, required this.message, required this.timestamp, this.params = const {}});

  Map<String, dynamic> toJson() => {
        'id': id, 'petId': petId, 'type': type.name, 'message': message,
        't': timestamp.toIso8601String(), 'params': params,
      };
  factory PetAlert.fromJson(Map<String, dynamic> j) => PetAlert(
        id: j['id'], petId: j['petId'],
        type: AlertType.values.firstWhere((t) => t.name == j['type'], orElse: () => AlertType.anomaly),
        message: j['message'] ?? '', timestamp: DateTime.parse(j['t']),
        params: Map<String, String>.from(j['params'] ?? const {}));
}

abstract class AlertRepository {
  Future<List<PetAlert>> getAlerts(String petId);
  Future<void> addAlert(PetAlert alert);
  Future<void> clear(String petId);
}
