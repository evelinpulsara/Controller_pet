import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/pet_map.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';
import '../../walks/domain/walk.dart';

/// Pestaña Actividad: meta diaria, semana y paseos.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pet = c.selectedPet;
    if (pet == null) return const SizedBox();
    final today = c.today;
    final week = c.lastSevenDays;
    final p = pet.dailyGoalMeters <= 0 ? 0.0 : today.distanceMeters / pet.dailyGoalMeters;
    final dayNames = l.isEs ? ['L', 'M', 'X', 'J', 'V', 'S', 'D'] : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekTotal = week.fold<double>(0, (t, d) => t + d.distanceMeters);
    final hasSample = week.any((d) => d.sample);
    final walk = c.activeWalk;

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text(l.t('Actividad de ${pet.name}', "${pet.name}'s activity"), style: context.text.headlineSmall),
        const SizedBox(height: 16),

        // Meta del día
        AppCard(
          child: Column(children: [
            ProgressRing(
              progress: p,
              color: pet.color,
              size: 170,
              stroke: 14,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(Fmt.distance(today.distanceMeters, c.metric), style: context.text.headlineMedium),
                Text(l.t('de ${Fmt.distance(pet.dailyGoalMeters, c.metric)}', 'of ${Fmt.distance(pet.dailyGoalMeters, c.metric)}'),
                    style: context.text.bodySmall),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              p >= 1
                  ? l.t('¡Meta cumplida! 🎉', 'Goal reached! 🎉')
                  : l.t('Le faltan ${Fmt.distance(pet.dailyGoalMeters - today.distanceMeters, c.metric)} para su meta',
                      '${Fmt.distance(pet.dailyGoalMeters - today.distanceMeters, c.metric)} to go'),
              style: context.text.titleMedium?.copyWith(color: p >= 1 ? pet.color : null),
            ),
            const SizedBox(height: 14),
            StatsRow(children: [
              MiniStat(value: '${today.activeMinutes} min', label: l.t('activo hoy', 'active today')),
              MiniStat(value: '${c.walksToday.length}', label: l.t('paseos hoy', 'walks today')),
              MiniStat(value: '${c.session?.minutesOutsideToday ?? 0} min', label: l.t('fuera de zona', 'outside zone')),
            ]),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(l.t('Cambiar meta', 'Change goal')),
              onPressed: () => _editGoal(context, l, c),
            ),
          ]),
        ),

        // Paseo
        if (walk == null)
          FilledButton.icon(
            onPressed: c.startWalk,
            icon: const Icon(Icons.directions_walk_rounded),
            label: Text(l.t('Iniciar paseo', 'Start a walk')),
          )
        else
          AppCard(
            color: pet.color,
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${fmtDuration(walk.duration)}   ${Fmt.distance(walk.distanceMeters, c.metric)}',
                    style: context.text.titleMedium?.copyWith(color: Colors.white)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: pet.color, minimumSize: const Size(0, 44)),
