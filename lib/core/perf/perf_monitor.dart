import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'perf_platform_stub.dart' if (dart.library.js_interop) 'perf_platform_web.dart' as platform;
import 'perf_types.dart';

export 'perf_types.dart';

/// Mide en vivo qué tan rápido responde la app (INP) y cómo van los frames.
///
/// - INP (Interaction to Next Paint) = Input Delay + Processing + Presentation Delay.
///   Bueno <= 200 ms, Necesita mejora 200-500 ms, Pobre > 500 ms.
/// - Frames de Flutter: tiempo en el hilo de UI (build/layout, como el Main Thread)
///   y en el hilo de Raster (pintado, como el proceso de GPU).
class PerfMonitor extends ChangeNotifier {
  PerfMonitor._();
  static final PerfMonitor instance = PerfMonitor._();

  bool _started = false;
  final Map<int, InteractionSample> _interactions = {}; // por interactionId (se queda la más lenta)
  final List<double> _uiMs = [], _rasterMs = [];
  int longTasks = 0;
  double longestTaskMs = 0;

  void start() {
    if (_started) return;
    _started = true;
    platform.startBrowserObservers(
      onInteraction: (s) {
        final prev = _interactions[s.id];
        if (prev == null || s.total > prev.total) _interactions[s.id] = s;
        while (_interactions.length > 200) {
          _interactions.remove(_interactions.keys.first);
        }
        _notifySoon();
      },
      onLongTask: (ms) {
        longTasks++;
        longestTaskMs = max(longestTaskMs, ms);
        _notifySoon();
      },
    );
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _uiMs.add(t.buildDuration.inMicroseconds / 1000);
      _rasterMs.add(t.rasterDuration.inMicroseconds / 1000);
    }
    while (_uiMs.length > 240) {
      _uiMs.removeAt(0);
    }
    while (_rasterMs.length > 240) {
      _rasterMs.removeAt(0);
    }
    _notifySoon();
  }

  // Agrupa las notificaciones (las interacciones llegan en ráfagas).
  Timer? _debounce;
  void _notifySoon() {
    _debounce ??= Timer(const Duration(milliseconds: 300), () {
      _debounce = null;
      notifyListeners();
    });
  }

  List<InteractionSample> get interactions =>
