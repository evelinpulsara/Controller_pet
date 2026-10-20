import 'dart:async';
import '../domain/location_data.dart';

/// Collar REAL que todavía no ha enviado ninguna ubicación.
/// Es el que usan los usuarios normales: no inventa nada; la mascota no se
/// mueve, la batería no baja y no hay alertas hasta que llegue una señal real.
///
/// AQUÍ SE CONECTARÁ EL GPS CON ARDUINO: cuando el collar envíe su ubicación
/// (por Bluetooth, Wi-Fi o a través del backend), se emite en [watchLocation].
class PendingCollarService extends LocationService {
  PendingCollarService(this.trackerId);
  final String trackerId;
  final _ctrl = StreamController<LocationData>.broadcast();

  /// Sin señal todavía.
  @override
  Future<LocationData> getCurrentLocation() => Future.error(StateError('El collar $trackerId aún no envía su ubicación'));

  @override
  Stream<LocationData> watchLocation() => _ctrl.stream;

  /// Para cuando el collar real envíe una ubicación.
  void push(LocationData l) {
    if (!_ctrl.isClosed) _ctrl.add(l);
  }

  @override
  void dispose() => _ctrl.close();
}

/// PARA EL GPS REAL (vía servidor): el collar envía su ubicación al backend
/// y la app la lee de la API (REST / WebSocket).
class ApiLocationService extends LocationService {
  ApiLocationService(this.baseUrl, this.trackerId);
  final String baseUrl, trackerId;
  @override
  Future<LocationData> getCurrentLocation() => throw UnimplementedError('GET $baseUrl/trackers/$trackerId/location');
  @override
  Stream<LocationData> watchLocation() => throw UnimplementedError('WebSocket / consulta periódica aquí');
}
