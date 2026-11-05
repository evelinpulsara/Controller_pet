import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/validation/collar_data.dart';
import '../domain/location_data.dart';

/// Cómo llegan las ubicaciones del collar a la app.
enum CollarTransport {
  /// Conectando...
  connecting,
  /// WebSocket (Supabase Realtime): la base avisa en cuanto llega una ubicación.
  websocket,
  /// Short polling: la app pregunta cada pocos segundos (respaldo).
  polling,
}

/// Collar REAL leído desde Supabase.
/// El collar (por ejemplo un Arduino) envía su ubicación a la función
/// `pettracker.report_location`. La app se entera así:
///  1. WebSocket con Supabase Realtime (conexión persistente, bidireccional):
///     la base empuja cada fila nueva de location_history al instante.
///  2. Si el WebSocket no está disponible, Short Polling (pregunta cada 5 s).
/// Aunque el WebSocket funcione, se hace una consulta de respaldo cada 30 s
/// por si se perdió algún mensaje.
class SupabaseCollarService extends LocationService {
  SupabaseCollarService(this._db, this.petId);
  final SupabaseClient _db;
  final String petId;

  final transport = ValueNotifier(CollarTransport.connecting);
  final _ctrl = StreamController<LocationData>.broadcast();
  Duration _pollEvery = const Duration(seconds: 5);
  Timer? _timer;
  RealtimeChannel? _channel;
  DateTime? _last;
  bool _busy = false, _started = false;

  void _emit(LocationData l) {
    if (_ctrl.isClosed) return;
    if (_last != null && !l.timestamp.isAfter(_last!)) return; // ya la teníamos
    _last = l.timestamp;
    _ctrl.add(l);
  }

  /// Última ubicación guardada (o error si el collar nunca ha enviado nada).
  @override
  Future<LocationData> getCurrentLocation() async {
    final r = await _db
        .from('location_history')
        .select()
        .eq('pet_id', petId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final l = r == null ? null : parseCollarLocation(r);
    if (l == null) throw StateError('El collar aún no envía su ubicación');
    _last ??= l.timestamp;
    return l;
  }

  @override
  Stream<LocationData> watchLocation() {
    if (!_started) {
      _started = true;
      _subscribe();
      _restartTimer();
    }
    return _ctrl.stream;
  }

  void _subscribe() {
    try {
      _channel = _db
          .channel('pettracker-collar-$petId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'pettracker',
            table: 'location_history',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'pet_id', value: petId),
            callback: (payload) {
              final l = parseCollarLocation(payload.newRecord);
              if (l != null) _emit(l);
            },
          )
          .subscribe((status, [error]) {
        transport.value =
            status == RealtimeSubscribeStatus.subscribed ? CollarTransport.websocket : CollarTransport.polling;
        _restartTimer();
      });
    } catch (_) {
      transport.value = CollarTransport.polling;
    }
  }

  @override
  void setInterval(Duration d) {
    _pollEvery = d < const Duration(seconds: 3) ? const Duration(seconds: 3) : d;
    if (_started) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    // Con WebSocket solo hace falta una revisión de respaldo de vez en cuando.
    final every = transport.value == CollarTransport.websocket ? const Duration(seconds: 30) : _pollEvery;
    _timer = Timer.periodic(every, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_busy || _ctrl.isClosed) return;
    _busy = true;
    try {
      var q = _db.from('location_history').select().eq('pet_id', petId);
      if (_last != null) q = q.gt('recorded_at', _last!.toUtc().toIso8601String());
      final rows = await q.order('recorded_at').limit(50);
      for (final r in rows) {
        final l = parseCollarLocation(r);
        if (l != null) _emit(l);
      }
    } catch (_) {
      // Sin internet: se vuelve a intentar en la próxima vuelta.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    final ch = _channel;
    if (ch != null) _db.removeChannel(ch);
    _ctrl.close();
    transport.dispose();
  }
}
