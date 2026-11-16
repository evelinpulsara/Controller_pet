import 'package:flutter/material.dart';
import '../../../core/util/ids.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/locate_me.dart';
import '../../../shared/widgets/pet_map.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';
import '../domain/safe_zone.dart';

/// Lista de zonas seguras de la mascota (casa, parque, casa de la abuela...).
class GeofencingScreen extends StatelessWidget {
  const GeofencingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pet = c.selectedPet;
    final zones = c.zones;
    final center = zones.isEmpty
        ? (c.current == null ? null : LatLng(c.current!.latitude, c.current!.longitude))
        : LatLng(zones.first.latitude, zones.first.longitude);
    final inZone = c.session?.currentZone;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('Zonas seguras de ${pet?.name ?? ''}', "${pet?.name ?? ''}'s safe zones"))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PageFrame(maxWidth: 960, child: ZoneEditor()))),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(l.t('Nueva zona', 'New zone')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
        if (center != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 220,
              child: PetMap(
                center: center,
                zoom: 15,
                zones: zones,
                pet: pet,
                petPosition: c.current == null ? null : ll(c.current!),
                interactive: false,
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          l.t('Si ${pet?.name ?? ''} sale de TODAS sus zonas activas, te avisamos. Durante un paseo no se envían alertas.',
              'If ${pet?.name ?? ''} leaves ALL active zones, we alert you. No alerts are sent during a walk.'),
          style: context.text.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 14),
        if (zones.isNotEmpty)
          AppCard(
            color: context.accent.withValues(alpha: 0.10),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PageFrame(maxWidth: 960, child: ZoneEditor(zone: zones.first)))),
            child: Row(children: [
              Icon(Icons.my_location_rounded, color: context.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.t('Ajustar "${zones.first.name}" con mi ubicación real', 'Set "${zones.first.name}" with my real location'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.muted),
            ]),
          ),
        if (zones.isEmpty)
          EmptyState(icon: Icons.shield_outlined, text: l.t('Aún no hay zonas. Crea la primera.', 'No zones yet. Create the first one.')),
        for (final z in zones)
          AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PageFrame(maxWidth: 960, child: ZoneEditor(zone: z)))),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: z.isEnabled ? 0.16 : 0.06), shape: BoxShape.circle),
                child: Icon(z == zones.first ? Icons.home_rounded : Icons.place_rounded,
                    color: z.isEnabled ? context.accent : context.colors.muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(z.name, style: context.text.titleMedium),
                  Text(
                    [
                      l.radiusLabel(Fmt.distance(z.radius, c.metric)),
                      if (!z.isEnabled) l.t('Desactivada', 'Off'),
                    ].join('  '),
                    style: context.text.bodySmall,
                  ),
                ]),
              ),
              if (inZone?.id == z.id)
                StatusChip(label: l.t('Está aquí', 'Here now'), icon: Icons.pets_rounded, color: context.accent),
              Icon(Icons.chevron_right_rounded, color: context.colors.muted),
            ]),
          ),
      ]),
    );
  }
}

/// Crear o editar una zona: toca el mapa para mover el centro.
class ZoneEditor extends StatefulWidget {
  const ZoneEditor({super.key, this.zone});
  final SafeZone? zone;
  @override
  State<ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<ZoneEditor> {
  late final _name = TextEditingController(text: widget.zone?.name ?? '');
  late double _radius = widget.zone?.radius ?? 120;
  late bool _enabled = widget.zone?.isEnabled ?? true;
  LatLng? _center;
  final _map = MapController();
  LatLng? _owner;
  double? _ownerAcc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_center != null) return;
    final c = AppScope.of(context);
    final z = widget.zone;
    if (z != null) {
      _center = LatLng(z.latitude, z.longitude);
    } else if (c.current != null) {
      _center = ll(c.current!);
    } else if (c.zone != null) {
      _center = LatLng(c.zone!.latitude, c.zone!.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final center = _center!;
    final isNew = widget.zone == null;
    final draft = SafeZone(
        id: widget.zone?.id ?? 'draft', name: _name.text, latitude: center.latitude, longitude: center.longitude,
        radius: _radius, isEnabled: _enabled);
    final others = c.zones.where((z) => z.id != widget.zone?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l.t('Nueva zona', 'New zone') : l.t('Editar zona', 'Edit zone')),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              onPressed: () async {
                await c.deleteZone(widget.zone!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        UseMyLocationCard(
          onLocated: (p, acc) {
            setState(() {
              _center = p;
              _owner = p;
              _ownerAcc = acc;
            });
            _map.move(p, zoomFor(_radius * 2.5));
          },
        ),
        const SizedBox(height: 12),
        Text(l.t('O toca el mapa para poner el centro de la zona.', 'Or tap the map to set the center of the zone.'),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 320,
            child: PetMap(
              controller: _map,
              center: center,
              zoom: zoomFor(_radius * 2.5),
              owner: _owner,
              ownerAccuracy: _ownerAcc,
              zones: [draft, ...others],
              highlightZoneId: draft.id,
              pet: c.selectedPet,
              petPosition: c.current == null ? null : ll(c.current!),
              onTap: (p) => setState(() => _center = p),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: l.zoneName, hintText: l.t('Ej: Parque, Casa de la abuela', 'E.g. Park, Grandma\'s house')),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(l.radiusLabel(Fmt.distance(_radius, c.metric)), style: context.text.titleMedium),
        Slider(value: _radius, min: 30, max: 1000, onChanged: (v) => setState(() => _radius = v)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.zoneEnabled),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: Text(l.saveZone),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () async {
                  await c.saveZone(SafeZone(
                    id: widget.zone?.id ?? newId(),
                    name: _name.text.trim(),
                    latitude: center.latitude,
                    longitude: center.longitude,
                    radius: _radius,
                    isEnabled: _enabled,
                  ));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.zoneSaved)));
                  Navigator.pop(context);
                },
        ),
      ]),
    );
  }
}
