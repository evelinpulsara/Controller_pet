import 'dart:convert';
import 'route_analysis.dart';
import 'route_worker_stub.dart' if (dart.library.js_interop) 'route_worker_web.dart' as impl;

export 'route_analysis.dart';

/// Analiza un recorrido. [inWorker] = true lo hace en un Web Worker (web)
/// o en un Isolate (celular); false lo hace en el hilo principal.
Future<RouteAnalysis> analyzeRoute({
  required List<List<double>> points, // [lat, lng, tiempoMs]
  required List<List<Object>> zones, // [lat, lng, radio, nombre]
  int synthetic = 0,
  required bool inWorker,
}) async {
  final input = jsonEncode({'points': points, 'zones': zones, 'synthetic': synthetic});
  final json = inWorker ? await impl.runInBackground(input) : analyzeRouteJson(input);
  return RouteAnalysis.fromJson(json);
}
