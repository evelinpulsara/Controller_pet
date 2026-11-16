import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'perf_types.dart';

double _num(JSObject o, String key) => (o.getProperty<JSNumber?>(key.toJS))?.toDartDouble ?? 0;

void startBrowserObservers({
  required void Function(InteractionSample s) onInteraction,
  required void Function(double durationMs) onLongTask,
}) {
  try {
    final events = web.PerformanceObserver(((web.PerformanceObserverEntryList list, web.PerformanceObserver _) {
      for (final e in list.getEntries().toDart) {
        final o = e as JSObject;
        final id = (o.getProperty<JSNumber?>('interactionId'.toJS))?.toDartInt ?? 0;
        if (id == 0) continue;
        final start = _num(o, 'startTime');
        final pStart = _num(o, 'processingStart');
        final pEnd = _num(o, 'processingEnd');
        final duration = _num(o, 'duration');
        onInteraction(InteractionSample(
          id: id,
          type: e.name,
          inputDelay: (pStart - start).clamp(0, 1e6).toDouble(),
          processing: (pEnd - pStart).clamp(0, 1e6).toDouble(),
          presentation: (start + duration - pEnd).clamp(0, 1e6).toDouble(),
          at: DateTime.now(),
        ));
      }
    }).toJS);
    events.observe(web.PerformanceObserverInit(type: 'event', buffered: true, durationThreshold: 16));
  } catch (_) {}
  try {
    final longTasks = web.PerformanceObserver(((web.PerformanceObserverEntryList list, web.PerformanceObserver _) {
      for (final e in list.getEntries().toDart) {
        onLongTask(e.duration);
      }
    }).toJS);
    longTasks.observe(web.PerformanceObserverInit(type: 'longtask', buffered: true));
  } catch (_) {
  }
}

bool get browserCrossOriginIsolated => web.window.crossOriginIsolated;

bool get browserSharedArrayBufferAvailable => globalContext.has('SharedArrayBuffer');

LoadTimings? browserLoadTimings() {
  try {
    final perf = web.window.performance;
    final nav = perf.getEntriesByType('navigation').toDart;
    double? ttfb, dcl, load;
    if (nav.isNotEmpty) {
      final o = nav.first as JSObject;
      ttfb = _num(o, 'responseStart');
      dcl = _num(o, 'domContentLoadedEventEnd');
      load = _num(o, 'loadEventEnd');
    }
    final fcpEntries = perf.getEntriesByName('first-contentful-paint').toDart;
    return LoadTimings(
      ttfb: ttfb,
      fcp: fcpEntries.isEmpty ? null : fcpEntries.first.startTime,
      domContentLoaded: dcl,
      load: load,
    );
  } catch (_) {
    return null;
  }
}

Future<ServiceWorkerInfo> browserServiceWorkerInfo() async {
  try {
    final nav = web.window.navigator as JSObject;
    if (!nav.has('serviceWorker')) return const ServiceWorkerInfo(supported: false);
    final active = web.window.navigator.serviceWorker.controller != null;
    var tiles = 0;
    try {
      final cache = await web.window.caches.open('pettracker-tiles-v1').toDart;
      tiles = (await cache.keys().toDart).length;
    } catch (_) {}
    return ServiceWorkerInfo(supported: true, active: active, cachedTiles: tiles);
  } catch (_) {
    return const ServiceWorkerInfo(supported: false);
  }
}

void busyWait(int ms) {
  final end = web.window.performance.now() + ms;
  while (web.window.performance.now() < end) {}
}
