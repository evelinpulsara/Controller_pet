import 'dart:convert';
import 'route_analysis.dart';
import 'route_worker_stub.dart' if (dart.library.js_interop) 'route_worker_web.dart' as impl;

export 'route_analysis.dart';

Future<RouteAnalysis> analyzeRoute({
  required List<List<double>> points,
  required List<List<Object>> zones,
  int synthetic = 0,
  required bool inWorker,
}) async {
  final input = jsonEncode({'points': points, 'zones': zones, 'synthetic': synthetic});
  final json = inWorker ? await impl.runInBackground(input) : analyzeRouteJson(input);
  return RouteAnalysis.fromJson(json);
}
