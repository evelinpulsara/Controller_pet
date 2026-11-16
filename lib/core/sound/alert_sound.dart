import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class AlertSound {
  Future<void> alarm();
  Future<void> chime();
}

class AudioAlertSound implements AlertSound {
  final AudioPlayer _alarm = AudioPlayer(playerId: 'alarm');
  final AudioPlayer _chime = AudioPlayer(playerId: 'chime');
  DateTime? _lastAlarm;

  @override
  Future<void> alarm() async {
    final now = DateTime.now();
    if (_lastAlarm != null && now.difference(_lastAlarm!) < const Duration(seconds: 4)) return;
    _lastAlarm = now;
    try {
      await _alarm.stop();
      await _alarm.play(AssetSource('sounds/alarm.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[Sonido] No se pudo reproducir la alarma: $e');
    }
  }

  @override
  Future<void> chime() async {
    try {
      await _chime.play(AssetSource('sounds/chime.wav'), volume: 0.8);
    } catch (e) {
      debugPrint('[Sonido] No se pudo reproducir el timbre: $e');
    }
  }
}

class SilentAlertSound implements AlertSound {
  int alarms = 0, chimes = 0;
  @override
  Future<void> alarm() async => alarms++;
  @override
  Future<void> chime() async => chimes++;
}
