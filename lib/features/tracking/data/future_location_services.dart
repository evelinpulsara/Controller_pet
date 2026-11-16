import 'dart:async';
import '../domain/location_data.dart';

class PendingCollarService extends LocationService {
  PendingCollarService(this.trackerId);
  final String trackerId;
  final _ctrl = StreamController<LocationData>.broadcast();

  @override
  Future<LocationData> getCurrentLocation() => Future.error(StateError('El collar $trackerId aún no envía su ubicación'));

  @override
  Stream<LocationData> watchLocation() => _ctrl.stream;

  void push(LocationData l) {
    if (!_ctrl.isClosed) _ctrl.add(l);
  }

  @override
  void dispose() => _ctrl.close();
}

class ApiLocationService extends LocationService {
  ApiLocationService(this.baseUrl, this.trackerId);
  final String baseUrl, trackerId;
  @override
  Future<LocationData> getCurrentLocation() => throw UnimplementedError('GET $baseUrl/trackers/$trackerId/location');
  @override
  Stream<LocationData> watchLocation() => throw UnimplementedError('WebSocket / consulta periódica aquí');
}
