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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ZoneEditor())),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneEditor(zone: zones.first))),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneEditor(zone: z))),
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
