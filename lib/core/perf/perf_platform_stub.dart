import 'perf_types.dart';

void startBrowserObservers({
  required void Function(InteractionSample s) onInteraction,
  required void Function(double durationMs) onLongTask,
}) {}

bool get browserCrossOriginIsolated => false;
bool get browserSharedArrayBufferAvailable => false;
LoadTimings? browserLoadTimings() => null;
Future<ServiceWorkerInfo> browserServiceWorkerInfo() async => const ServiceWorkerInfo(supported: false);

void busyWait(int ms) {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < ms) {}
}
