import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../features/geofencing/domain/safe_zone.dart';
import '../../features/pets/domain/pet.dart';
import '../../features/tracking/domain/location_data.dart';
import 'locate_me.dart';
import 'widgets.dart';

LatLng ll(LocationData l) => LatLng(l.latitude, l.longitude);

/// Mapa real (OpenStreetMap) con las zonas seguras, el recorrido y la mascota.
class PetMap extends StatelessWidget {
  const PetMap({
    super.key,
    required this.center,
    this.controller,
    this.zones = const [],
    this.trail = const [],
    this.route = const [],
    this.pet,
    this.petPosition,
    this.alert = false,
    this.live = false,
    this.zoom = 16.5,
    this.onTap,
    this.interactive = true,
    this.highlightZoneId,
    this.owner,
    this.ownerAccuracy,
  });

  /// Ubicación del dueño (punto azul), si la compartió.
  final LatLng? owner;
  final double? ownerAccuracy;

  final LatLng center;
  final MapController? controller;
  final List<SafeZone> zones;
  /// Puntos del recorrido reciente (se dibujan como una línea suave).
  final List<LatLng> trail;
  /// Ruta de un paseo (línea más marcada).
  final List<LatLng> route;
  final Pet? pet;
  final LatLng? petPosition;
  final bool alert, live, interactive;
  final double zoom;
  final void Function(LatLng point)? onTap;
  final String? highlightZoneId;

  @override
  Widget build(BuildContext context) {
    final accent = pet?.color ?? context.accent;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: context.colors.field,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.pettracker',
          tileBuilder: dark ? _darkTiles : null,
        ),
        // Zonas y precisión de tu ubicación: se dibujan con un pintor propio
        // (el CircleLayer de flutter_map se quedaba en un ciclo infinito en el navegador).
        _ZoneCircles(circles: [
          if (owner != null && _ok(ownerAccuracy) && ownerAccuracy! <= 5000)
            _Circle(owner!, ownerAccuracy!, ownerBlue.withValues(alpha: 0.10), ownerBlue.withValues(alpha: 0.3), 1),
          for (final z in zones.where((z) => _ok(z.radius) && z.latitude.isFinite && z.longitude.isFinite))
            _Circle(
              LatLng(z.latitude, z.longitude),
              z.radius,
              accent.withValues(alpha: !z.isEnabled ? 0.05 : (z.id == highlightZoneId ? 0.28 : 0.16)),
              accent.withValues(alpha: z.isEnabled ? 0.9 : 0.35),
              z.id == highlightZoneId ? 3.5 : 2.5,
            ),
        ]),
        if (trail.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: trail,
              strokeWidth: 4,
              color: (alert ? AppTheme.danger : accent).withValues(alpha: 0.45),
              pattern: StrokePattern.dotted(spacingFactor: 2),
            ),
          ]),
        if (route.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: route, strokeWidth: 6, color: accent, borderStrokeWidth: 2, borderColor: Colors.white),
          ]),
        MarkerLayer(markers: [
          for (final z in zones)
            Marker(
              point: LatLng(z.latitude, z.longitude),
              width: 34,
              height: 34,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2.5),
                ),
                child: Icon(z == zones.first ? Icons.home_rounded : Icons.place_rounded, size: 18, color: accent),
              ),
            ),
          if (owner != null) Marker(point: owner!, width: 22, height: 22, child: const OwnerDot()),
          if (pet != null && petPosition != null)
            Marker(
              point: petPosition!,
              width: 66,
              height: 66,
              child: PetAvatar(pet: pet!, size: 44, live: live, alert: alert, hero: false),
            ),
        ]),
        // Crédito obligatorio de OpenStreetMap (pequeño, abajo a la derecha).
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: context.colors.muted)),
            ),
          ),
        ),
      ],
    );
  }

  /// Oscurece las calles del mapa en modo oscuro.
  static Widget _darkTiles(BuildContext context, Widget tile, TileImage _) => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -0.75, 0, 0, 0, 220, //
          0, -0.75, 0, 0, 225,
          0, 0, -0.75, 0, 220,
          0, 0, 0, 1, 0,
        ]),
        child: tile,
      );
}

class _Circle {
  const _Circle(this.center, this.radiusMeters, this.fill, this.border, this.borderWidth);
  final LatLng center;
  final double radiusMeters, borderWidth;
  final Color fill, border;
}

/// Capa de círculos en metros, sin repetirlos en "copias" del mundo.
class _ZoneCircles extends StatelessWidget {
  const _ZoneCircles({required this.circles});
  final List<_Circle> circles;
  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _CirclesPainter(camera, circles)),
    );
  }
}

class _CirclesPainter extends CustomPainter {
  _CirclesPainter(this.camera, this.circles);
  final MapCamera camera;
  final List<_Circle> circles;
  static const _distance = Distance();

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in circles) {
      final center = camera.latLngToScreenOffset(c.center);
      final edge = camera.latLngToScreenOffset(_distance.offset(c.center, c.radiusMeters, 180));
      final r = (edge - center).distance;
      if (!r.isFinite || !center.dx.isFinite || !center.dy.isFinite || r <= 0) continue;
      canvas.drawCircle(center, r, Paint()..color = c.fill);
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = c.border
            ..style = PaintingStyle.stroke
            ..strokeWidth = c.borderWidth);
    }
  }

  @override
  bool shouldRepaint(covariant _CirclesPainter old) => true;
}

/// Radio válido: un número real y mayor que 0.
bool _ok(double? v) => v != null && v.isFinite && v > 0;

/// Calcula la distancia del mapa mostrando zonas y mascota.
double zoomFor(double meters) {
  if (meters < 150) return 17.5;
  if (meters < 300) return 16.5;
  if (meters < 700) return 15.5;
  if (meters < 1500) return 14.5;
  if (meters < 3000) return 13.5;
  return 12.5;
}
