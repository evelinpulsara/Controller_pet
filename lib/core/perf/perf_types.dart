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
  final String type;
  final double inputDelay, processing, presentation;
  final DateTime at;
  double get total => inputDelay + processing + presentation;
}

class LoadTimings {
  const LoadTimings({this.ttfb, this.fcp, this.domContentLoaded, this.load});
  final double? ttfb, fcp, domContentLoaded, load;
}

class ServiceWorkerInfo {
  const ServiceWorkerInfo({required this.supported, this.active = false, this.cachedTiles = 0});
  final bool supported, active;
  final int cachedTiles;
}
