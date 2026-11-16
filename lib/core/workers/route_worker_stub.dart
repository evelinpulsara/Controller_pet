import 'package:flutter/foundation.dart';
import 'route_analysis.dart';

Future<Map<String, dynamic>> runInBackground(String input) =>
    compute((String i) => analyzeRouteJson(i, thread: 'isolate'), input);

bool get workersSupported => !kIsWeb;
