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
