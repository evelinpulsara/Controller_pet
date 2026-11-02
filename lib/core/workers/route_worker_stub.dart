import 'package:flutter/foundation.dart';
import 'route_analysis.dart';

/// En celular no hay Web Workers: el equivalente es un Isolate (otro hilo).
Future<Map<String, dynamic>> runInBackground(String input) =>
    compute((String i) => analyzeRouteJson(i, thread: 'isolate'), input);

bool get workersSupported => !kIsWeb;
