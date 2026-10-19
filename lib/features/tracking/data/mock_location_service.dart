import 'dart:async';
import 'dart:math';
import '../domain/location_data.dart';

/// Collar GPS SIMULADO para una mascota (uno por mascota).
/// Cuando tengas el GPS real, crea una clase que implemente [LocationService]
/// y úsala en `collarFactory` de main.dart en lugar de esta.
class MockLocationService implements LocationService {
  MockLocationService({required this.homeLat, required this.homeLng, int? seed})
      : _lat = homeLat,
        _lng = homeLng,
        _rnd = Random(seed);

  final double homeLat, homeLng;
  double _lat, _lng;
  final Random _rnd;

  /// Simulación: la mascota se aleja de casa.
  bool escaping = false;
  /// Simulación: la mascota no se mueve nada.
  bool frozen = false;
  /// Simulación: va de paseo (camina a ritmo constante y regresa).
  bool walking = false;
  /// Simulación: corre muy rápido (como si fuera en un carro).
  bool speeding = false;

  double _heading = 0;
  Duration _interval = const Duration(seconds: 3);
  Timer? _timer;
  final _ctrl = StreamController<LocationData>.broadcast();

  LocationData _snapshot() => LocationData(
        latitude: _lat, longitude: _lng, timestamp: DateTime.now(),
        accuracy: _rnd.nextDouble() < 0.03 ? 30 : 3 + _rnd.nextDouble() * 5,
      );

  /// Metros -> grados aproximados.
  double _mLat(double m) => m / 110540;
  double _mLng(double m) => m / (111320 * cos(homeLat * pi / 180));

  LocationData _next() {
    final secs = _interval.inMilliseconds / 1000;
    if (frozen) return _snapshot();
    if (escaping || speeding) {
      final speed = speeding ? 12.0 : 5.0; // m/s (huyendo ~18 km/h, en carro ~43 km/h)
      _lat += _mLat(speed * secs * (0.8 + _rnd.nextDouble() * 0.4));
      _lng += _mLng(speed * secs * (_rnd.nextDouble() - 0.3) * 0.5);
    } else if (walking) {
      // Paseo: avanza ~1.3 m/s girando suavemente.
      _heading += (_rnd.nextDouble() - 0.5) * 0.5;
