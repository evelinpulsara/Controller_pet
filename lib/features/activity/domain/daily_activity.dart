/// Actividad de una mascota en un día: distancia recorrida y minutos en movimiento.
class DailyActivity {
  final String petId;
  /// Día en formato AAAA-MM-DD.
  final String day;
  final double distanceMeters;
  final int activeSeconds;
  /// true si son datos de ejemplo (generados desde el Modo prueba).
  final bool sample;
  const DailyActivity({
    required this.petId,
    required this.day,
    this.distanceMeters = 0,
    this.activeSeconds = 0,
    this.sample = false,
  });

  int get activeMinutes => activeSeconds ~/ 60;

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DailyActivity add({double meters = 0, int seconds = 0}) => DailyActivity(
      petId: petId, day: day, distanceMeters: distanceMeters + meters,
      activeSeconds: activeSeconds + seconds, sample: sample);

  Map<String, dynamic> toJson() =>
      {'petId': petId, 'day': day, 'm': distanceMeters, 's': activeSeconds, 'sample': sample};
  factory DailyActivity.fromJson(Map<String, dynamic> j) => DailyActivity(
      petId: j['petId'], day: j['day'], distanceMeters: (j['m'] as num?)?.toDouble() ?? 0,
      activeSeconds: (j['s'] as num?)?.toInt() ?? 0, sample: j['sample'] ?? false);
}

abstract class ActivityRepository {
  Future<List<DailyActivity>> getActivity(String petId);
  Future<void> saveDay(DailyActivity day);
}
