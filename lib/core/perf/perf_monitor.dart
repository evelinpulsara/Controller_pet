import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'perf_platform_stub.dart' if (dart.library.js_interop) 'perf_platform_web.dart' as platform;
import 'perf_types.dart';

export 'perf_types.dart';

class PerfMonitor extends ChangeNotifier {
  PerfMonitor._();
  static final PerfMonitor instance = PerfMonitor._();

  bool _started = false;
  final Map<int, InteractionSample> _interactions = {};
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

  Timer? _debounce;
  void _notifySoon() {
    _debounce ??= Timer(const Duration(milliseconds: 300), () {
      _debounce = null;
      notifyListeners();
    });
  }

  List<InteractionSample> get interactions =>
      _interactions.values.toList()..sort((a, b) => b.at.compareTo(a.at));

  InteractionSample? get inpSample {
    if (_interactions.isEmpty) return null;
    final sorted = _interactions.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    final skip = sorted.length >= 50 ? sorted.length ~/ 50 : 0;
    return sorted[min(skip, sorted.length - 1)];
  }

  double? get inp => inpSample?.total;

  static String rating(double? ms) => ms == null
      ? '—'
      : ms <= 200
          ? 'good'
          : ms <= 500
              ? 'needs'
              : 'poor';

  double get uiAvg => _uiMs.isEmpty ? 0 : _uiMs.reduce((a, b) => a + b) / _uiMs.length;
  double get uiMax => _uiMs.isEmpty ? 0 : _uiMs.reduce(max);
  double get rasterAvg => _rasterMs.isEmpty ? 0 : _rasterMs.reduce((a, b) => a + b) / _rasterMs.length;
  double get rasterMax => _rasterMs.isEmpty ? 0 : _rasterMs.reduce(max);
  int get framesMeasured => _uiMs.length;

  bool get isWeb => kIsWeb;
  bool get crossOriginIsolated => platform.browserCrossOriginIsolated;
  bool get sharedArrayBufferAvailable => platform.browserSharedArrayBufferAvailable;
  LoadTimings? get loadTimings => platform.browserLoadTimings();
  Future<ServiceWorkerInfo> serviceWorkerInfo() => platform.browserServiceWorkerInfo();

  void blockMainThread(int ms) => platform.busyWait(ms);

  void reset() {
    _interactions.clear();
    _uiMs.clear();
    _rasterMs.clear();
    longTasks = 0;
    longestTaskMs = 0;
    notifyListeners();
  }
}

Future<List<String>> eventLoopDemo(bool es) async {
  final log = <String>[];
  log.add(es ? 'Código síncrono #1 (Call Stack)' : 'Synchronous code #1 (Call Stack)');
  Timer.run(() => log.add(es ? 'Task / Macrotask (Timer, como setTimeout)' : 'Task / Macrotask (Timer, like setTimeout)'));
  Future(() => log.add(es ? 'Task / Macrotask (Future)' : 'Task / Macrotask (Future)'));
  scheduleMicrotask(() => log.add(es ? 'Microtask (scheduleMicrotask, como Promise.then)' : 'Microtask (like Promise.then)'));
  Future.microtask(() => log.add(es ? 'Microtask (Future.microtask)' : 'Microtask (Future.microtask)'));
  log.add(es ? 'Código síncrono #2 (Call Stack)' : 'Synchronous code #2 (Call Stack)');
  await Future.delayed(const Duration(milliseconds: 30));
  return log;
}
