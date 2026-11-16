import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/pet_map.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';
import '../../walks/domain/walk.dart';

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
      child: CenteredListView(maxWidth: 880, children: [
        Text(l.t('Actividad de ${pet.name}', "${pet.name}'s activity"), style: context.text.headlineSmall),
        const SizedBox(height: 16),

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
                onPressed: c.stopWalk,
                child: Text(l.t('Terminar', 'Finish')),
              ),
            ]),
          ),
        const SizedBox(height: 12),

        SectionTitle(l.t('Últimos 7 días', 'Last 7 days')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('Total: ${Fmt.distance(weekTotal, c.metric)}', 'Total: ${Fmt.distance(weekTotal, c.metric)}'),
                style: context.text.titleMedium),
            Text(l.t('La línea marca su meta diaria.', 'The line marks the daily goal.'), style: context.text.bodySmall),
            const SizedBox(height: 14),
            WeekBars(
              values: [for (final d in week) d.distanceMeters],
              labels: [for (final d in week) dayNames[DateTime.parse(d.day).weekday - 1]],
              sample: [for (final d in week) d.sample],
              goal: pet.dailyGoalMeters,
              color: pet.color,
            ),
            if (hasSample)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.t('Los días claros son datos de ejemplo.', 'Light bars are sample data.'),
                    style: context.text.bodySmall),
              ),
          ]),
        ),

        SectionTitle(l.t('Paseos', 'Walks')),
        if (c.walks.isEmpty)
          AppCard(
            child: Row(children: [
              Icon(Icons.route_rounded, color: context.colors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    l.t('Aún no hay paseos. Toca "Iniciar paseo" cuando salgan juntos.',
                        'No walks yet. Tap "Start a walk" when you go out together.'),
                    style: TextStyle(color: context.colors.muted)),
              ),
            ]),
          ),
        for (final w in c.walks.take(20))
          AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PageFrame(child: WalkDetailScreen(walk: w)))),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: pet.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.route_rounded, color: pet.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Fmt.distance(w.distanceMeters, c.metric), style: context.text.titleMedium),
                  Text('${_dayLabel(w.start, l)}, ${Fmt.time(w.start).substring(0, 5)}   ${fmtDuration(w.duration)}',
                      style: context.text.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.muted),
            ]),
          ),
      ]),
    );
  }

  String _dayLabel(DateTime d, AppL10n l) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return l.t('Hoy', 'Today');
    if (diff == 1) return l.t('Ayer', 'Yesterday');
    return Fmt.date(d);
  }

  void _editGoal(BuildContext context, AppL10n l, AppController c) {
    var km = (c.selectedPet!.dailyGoalMeters / 1000).clamp(0.2, 15.0);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.t('Meta diaria', 'Daily goal')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${km.toStringAsFixed(1)} km', style: ctx.text.headlineMedium),
            Slider(value: km, min: 0.2, max: 15, divisions: 74, onChanged: (v) => setState(() => km = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                c.setDailyGoal(km * 1000);
                Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

class WalkDetailScreen extends StatelessWidget {
  const WalkDetailScreen({super.key, required this.walk});
  final Walk walk;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pts = [for (final p in walk.points) ll(p)];
    final center = pts.isEmpty
        ? LatLng(c.zone?.latitude ?? 0, c.zone?.longitude ?? 0)
        : LatLng(pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length,
            pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('Paseo del ${Fmt.date(walk.start)}', 'Walk on ${Fmt.date(walk.start)}')),
        actions: [
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
            onPressed: () async {
              await c.deleteWalk(walk.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 340,
            child: PetMap(
              center: center,
              zoom: zoomFor(walk.distanceMeters / 2),
              zones: c.zones,
              route: pts,
              pet: c.selectedPet,
              petPosition: pts.isEmpty ? null : pts.last,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: StatsRow(children: [
            MiniStat(value: Fmt.distance(walk.distanceMeters, c.metric), label: l.t('distancia', 'distance')),
            MiniStat(value: fmtDuration(walk.duration), label: l.t('duración', 'duration')),
            MiniStat(value: '${walk.avgSpeedKmh.toStringAsFixed(1)} km/h', label: l.t('promedio', 'average')),
          ]),
        ),
        Text('${l.t('Empezó', 'Started')}: ${Fmt.time(walk.start)}   ${l.t('Terminó', 'Ended')}: ${walk.end == null ? '—' : Fmt.time(walk.end!)}',
            style: context.text.bodySmall),
      ]),
    );
  }
}
