import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<Map<String, dynamic>> runInBackground(String input) {
  final done = Completer<Map<String, dynamic>>();
  final worker = web.Worker('workers/route_analysis_worker.js'.toJS);
  worker.onmessage = ((web.MessageEvent e) {
    worker.terminate();
    done.complete(jsonDecode((e.data as JSString).toDart) as Map<String, dynamic>);
  }).toJS;
  worker.onerror = ((web.Event e) {
    worker.terminate();
    if (!done.isCompleted) done.completeError(StateError('El Web Worker falló'));
  }).toJS;
  worker.postMessage(input.toJS);
  return done.future;
}

bool get workersSupported => true;
