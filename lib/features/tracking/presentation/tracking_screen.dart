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

    // En computador el panel va abajo a la izquierda y los botones abajo a la derecha.
    final wide = context.isWide;

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
        return const SizedBox.shrink();
      }),
      // Título flotante
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
           alignment: Alignment.topLeft,
           child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 560 : double.infinity),
            child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Expanded(child: Text(l.whereIs(pet.name), style: context.text.titleLarge, overflow: TextOverflow.ellipsis)),
                  if (c.isDemo)
                    StatusChip(label: l.t('GPS simulado', 'Simulated GPS'), icon: Icons.science_outlined, color: AppTheme.warning),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              icon: Icons.shield_rounded,
              tooltip: l.t('Zonas seguras', 'Safe zones'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.zones),
            ),
          ]),
           ),
          ),
        ),
      ),
      // Botón "mi ubicación" (punto azul)
      Positioned(
        right: 16,
        bottom: wide ? (petPos == null ? 24 : 84) : (petPos == null ? 230 : 280),
        child: _locating
            ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 3)))
            : _RoundButton(
                icon: Icons.person_pin_circle_rounded,
                tooltip: c.ownerTracking ? l.t('Ocultar mi ubicación', 'Hide my location') : l.t('Mostrar mi ubicación', 'Show my location'),
                active: c.ownerTracking,
                activeColor: ownerBlue,
                onTap: () => _toggleOwner(c),
              ),
      ),
      // Botón "centrar en la mascota"
      if (petPos != null)
        Positioned(
          right: 16,
          bottom: wide ? 24 : 220,
          child: _RoundButton(
            icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
            tooltip: l.t('Centrar en ${pet.name}', 'Center on ${pet.name}'),
            active: _follow,
            onTap: () {
              setState(() => _follow = true);
              _map.move(petPos, 17);
            },
          ),
        ),
      // Panel inferior
      Positioned(
        left: 12,
        right: wide ? null : 12,
        width: wide ? 440 : null,
        bottom: 12,
        child: Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: petPos == null
                ? _WaitingPanel(petName: pet.name, ownerOn: c.ownerTracking, onOwner: () => _toggleOwner(c))
                : _StatusPanel(distToOwner: distToOwner),
          ),
        ),
      ),
    ]);
  }
}

/// Panel cuando el collar todavía no envía su ubicación (usuarios reales).
class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.petName, required this.ownerOn, required this.onOwner});
  final String petName;
  final bool ownerOn;
  final VoidCallback onOwner;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(Icons.sensors_off_rounded, color: context.colors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(l.t('Esperando la señal del collar', 'Waiting for the collar signal'), style: context.text.titleMedium)),
      ]),
      const SizedBox(height: 6),
      Text(
        l.t('Cuando el GPS de $petName envíe su primera ubicación, aparecerá aquí en el mapa.',
            "When $petName's GPS sends its first location, it will show up here on the map."),
        style: context.text.bodySmall,
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!ownerOn)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ownerBlue, minimumSize: const Size(0, 42)),
            onPressed: onOwner,
            icon: const Icon(Icons.person_pin_circle_rounded, size: 18),
            label: Text(l.t('Mostrar mi ubicación', 'Show my location')),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.collar),
          icon: const Icon(Icons.sensors_rounded, size: 18),
          label: Text(l.t('Mi collar', 'My collar')),
        ),
      ]),
    ]);
  }
}

/// Panel con el estado de la mascota.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.distToOwner});
  final double? distToOwner;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final s = c.session!, t = c.tracker!, loc = c.current!, pet = c.selectedPet!;
    final outside = t.isConnected && !c.insideZone && c.activeWalk == null;
    final d = c.distanceFromCenter ?? 0;
    final zoneNow = s.currentZone;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
            child: Text(
              l.awayFromHome(Fmt.distance(d, c.metric)),
              key: ValueKey(Fmt.distance(d, c.metric)),
              style: context.text.headlineSmall?.copyWith(color: outside ? AppTheme.danger : null),
            ),
          ),
        ),
        if (c.activeWalk != null)
          StatusChip(label: l.t('Paseando', 'Walking'), icon: Icons.directions_walk_rounded, color: pet.color),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusChip(
          label: !t.isConnected
              ? l.trackingPaused
              : zoneNow != null
                  ? l.inZoneShort(zoneNow.name)
                  : l.outsideZoneByMsg(Fmt.distance(s.metersOutside, c.metric)),
          icon: !t.isConnected
              ? Icons.pause_circle_outline_rounded
              : zoneNow != null
                  ? Icons.verified_rounded
                  : Icons.warning_rounded,
          color: !t.isConnected ? context.colors.muted : (zoneNow != null ? pet.color : AppTheme.danger),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 16, runSpacing: 4, children: [
        if (distToOwner != null)
          _Meta(
            icon: Icons.person_pin_circle_rounded,
            color: ownerBlue,
            text: l.t('A ${Fmt.distance(distToOwner!, c.metric)} de ti', '${Fmt.distance(distToOwner!, c.metric)} from you'),
          ),
        _Meta(icon: Icons.schedule_rounded, text: Fmt.time(t.lastUpdate)),
        _Meta(icon: Icons.my_location_rounded, text: '±${loc.accuracy.round()} m'),
        _Meta(icon: Icons.battery_5_bar_rounded, text: '${t.batteryLevel}%'),
      ]),
    ]);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color ?? context.colors.muted),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: color, fontWeight: color == null ? null : FontWeight.w700)),
      ]);
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.active = false, this.activeColor});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: active ? (activeColor ?? context.accent) : context.colors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 48, height: 48, child: Icon(icon, color: active ? Colors.white : context.colors.ink)),
          ),
        ),
      );
}
