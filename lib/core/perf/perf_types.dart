/// Una interacción medida por el navegador (Event Timing API).
/// INP = Input Delay + Processing Duration + Presentation Delay.
class InteractionSample {
  const InteractionSample({
    required this.id,
    required this.type,
    required this.inputDelay,
    required this.processing,
    required this.presentation,
    required this.at,
  });
  final int id;
  final String type; // pointerdown, click, keydown...
  final double inputDelay, processing, presentation; // ms
  final DateTime at;
  double get total => inputDelay + processing + presentation;
}

/// Tiempos de carga de la página (Navigation Timing + Paint Timing).
class LoadTimings {
  const LoadTimings({this.ttfb, this.fcp, this.domContentLoaded, this.load});
  final double? ttfb, fcp, domContentLoaded, load; // ms
}

class ServiceWorkerInfo {
  const ServiceWorkerInfo({required this.supported, this.active = false, this.cachedTiles = 0});
  final bool supported, active;
  final int cachedTiles;
}
