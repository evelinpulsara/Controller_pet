import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/locate_me.dart';
import '../../../shared/widgets/pet_map.dart';
import '../../../shared/widgets/widgets.dart';
import 'app_controller.dart';

/// Pestaña Mapa: mapa real con la mascota, sus zonas, su recorrido y tu ubicación.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _ready = false;
  bool _locating = false;

  Future<void> _toggleOwner(AppController c) async {
    if (c.ownerTracking) {
      c.stopOwnerTracking();
      return;
    }
    setState(() => _locating = true);
    final ok = await enableOwnerLocation(context);
    if (!mounted) return;
    setState(() => _locating = false);
    // Si la mascota todavía no tiene señal, el mapa te muestra a ti.
    if (ok && c.current == null && c.ownerPosition != null && _ready) _map.move(c.ownerPosition!, 16.5);
  }

  void _moveTo(LatLng p) {
    if (!_ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _map.move(p, _map.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final s = c.session;
    final t = c.tracker, pet = c.selectedPet;
    if (s == null || t == null || pet == null) return const Center(child: CircularProgressIndicator());

    final loc = c.current;
    final owner = c.ownerPosition;
    final home = c.zone;
    final petPos = loc == null ? null : ll(loc);
    // Centro: la mascota; si no tiene señal, tú; si no, su casa.
    final center = petPos ??
        owner ??
        (home != null ? LatLng(home.latitude, home.longitude) : const LatLng(AppConstants.homeLatitude, AppConstants.homeLongitude));
    final outside = petPos != null && t.isConnected && !c.insideZone && c.activeWalk == null;
    // Recorrido reciente (sin puntos lejanos, por si la demo se mudó de lugar).
    final trail = [
      for (final h in c.history.take(40))
        if (petPos == null || GeoUtils.distanceMeters(h.location.latitude, h.location.longitude, petPos.latitude, petPos.longitude) < 1500)
          ll(h.location)
    ];
    final route = [for (final p in c.activeWalk?.points ?? const []) ll(p)];
    final distToOwner = (petPos != null && owner != null)
        ? GeoUtils.distanceMeters(owner.latitude, owner.longitude, petPos.latitude, petPos.longitude)
        : null;

    // Sigue a la mascota mientras se mueve.
    if (_follow && petPos != null) _moveTo(petPos);

    return Stack(children: [
      Positioned.fill(
        child: Listener(
          onPointerDown: (_) => setState(() => _follow = false), // si mueves el mapa, deja de seguir
          child: PetMap(
            controller: _map,
            center: center,
            zoom: 16.5,
            zones: c.zones,
            trail: petPos == null ? const [] : trail,
            route: route,
            pet: petPos == null ? null : pet,
            petPosition: petPos,
            alert: outside,
            live: t.isConnected,
            owner: owner,
            ownerAccuracy: c.ownerAccuracy,
          ),
        ),
      ),
      // Marca que el mapa ya está listo para moverse.
      Builder(builder: (_) {
        if (!_ready) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _ready = true) : null);
