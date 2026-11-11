import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/locate_me.dart';
import '../../../shared/widgets/widgets.dart';
import '../../assistant/presentation/emergency_card.dart';
import '../../authentication/presentation/setup_wizard.dart';
import '../../health/domain/health_record.dart';
import '../../health/presentation/health_screen.dart';
import '../../tracking/presentation/app_controller.dart';
import '../domain/pet.dart';

/// Pestaña de Inicio.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});
  /// Cambia de pestaña (1 = Mapa, 2 = Actividad...).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pet = c.selectedPet, t = c.tracker;
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? l.t('Buenos días', 'Good morning')
        : hour < 19
            ? l.t('Buenas tardes', 'Good afternoon')
            : l.t('Buenas noches', 'Good evening');
    final otherEmergencies = c.activeEmergencies.where((e) => e.petId != pet?.id).toList();

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text('$greet, ${c.user?.name ?? ''}', style: context.text.headlineSmall),
        const SizedBox(height: 14),
        _PetSwitcher(onAdd: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SetupWizard(addingAnother: true)))),
        const SizedBox(height: 16),

        // Solo en la cuenta demo: explica el GPS simulado y lo trae a donde estás.
        if (c.isDemo) const _DemoCard(),

        // Aviso si OTRA mascota está en emergencia
        for (final e in otherEmergencies)
          AppCard(
            color: AppTheme.danger.withValues(alpha: 0.10),
            onTap: () => c.selectPetById(e.petId),
            child: Row(children: [
              const Icon(Icons.warning_rounded, color: AppTheme.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.t('${e.report.petName} salió de su zona. Toca para verla.',
                    '${e.report.petName} left their zone. Tap to see.'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

        // Si hay emergencia, la tarjeta de la IA va arriba de todo.
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: c.emergency != null ? const EmergencyAssistantCard() : const SizedBox(width: double.infinity),
        ),

        if (pet != null && t != null) _PetHeroCard(pet: pet, tracker: t, onMap: () => onOpenTab(1)),

        if (pet != null) _TodayCard(onOpen: () => onOpenTab(2)),
        if (pet != null) const _WalkCard(),
        if (c.reminders.isNotEmpty) const _RemindersCard(),

        if (c.emergency == null) const EmergencyAssistantCard(),

        const SizedBox(height: 4),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Alto fijo: se ve bien en celular y en pantallas anchas.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 104),

          children: [
            QuickAction(
              icon: Icons.medical_services_rounded,
              label: l.t('Salud', 'Health'),
              badge: c.reminders.isEmpty ? null : '${c.reminders.length}',
              onTap: () => Navigator.pushNamed(context, AppRoutes.health),
            ),
            QuickAction(
                icon: Icons.shield_rounded,
                label: l.t('Zonas', 'Zones'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.zones)),
            QuickAction(
                icon: Icons.sensors_rounded,
                label: l.t('Mi collar', 'My collar'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.collar)),
            QuickAction(
                icon: Icons.contacts_rounded,
                label: l.t('Contactos', 'Contacts'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.contacts)),
            QuickAction(
                icon: Icons.timeline_rounded,
                label: l.history,
                onTap: () => Navigator.pushNamed(context, AppRoutes.history)),
            QuickAction(
                icon: Icons.badge_rounded,
                label: l.profile,
                onTap: () => Navigator.pushNamed(context, AppRoutes.petProfile)),
          ],
        ),
      ]),
    );
  }
}

/// Tarjeta de la cuenta demo.
class _DemoCard extends StatefulWidget {
  const _DemoCard();
  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final here = c.ownerTracking;
    return AppCard(
      color: AppTheme.warning.withValues(alpha: 0.12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.science_rounded, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(l.t('Cuenta demo: GPS simulado', 'Demo account: simulated GPS'), style: context.text.titleMedium)),
        ]),
        const SizedBox(height: 6),
        Text(
          here
              ? l.t('Los collares simulados se mueven cerca de ti, igual que lo haría un collar GPS real. Tu ubicación es el punto azul del mapa.',
                  'The simulated collars move near you, just like a real GPS collar would. You are the blue dot on the map.')
              : l.t('Aquí los collares son simulados. Activa tu ubicación y la demo aparecerá donde estás: verás a la mascota moverse cerca de ti como con un GPS real.',
                  'Collars here are simulated. Turn on your location and the demo will appear where you are: the pet will move near you like with a real GPS.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 10),
        if (_busy)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!here)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ownerBlue, minimumSize: const Size(0, 42)),
                onPressed: () => _run(() => enableOwnerLocation(context)),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(l.t('Usar mi ubicación', 'Use my location')),
              )
            else if (c.ownerPosition != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => _run(() => c.relocateDemoTo(c.ownerPosition!)),
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: Text(l.t('Mover la demo aquí', 'Move the demo here')),
              ),
          ]),
      ]),
    );
  }
}

/// Fila de mascotas: cada una en un círculo con su color; la seleccionada crece.
class _PetSwitcher extends StatelessWidget {
  const _PetSwitcher({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return SizedBox(
      height: 78,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final p in c.pets)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _SwitcherItem(
              label: p.name,
              selected: p.id == c.selectedPet?.id,
              color: p.color,
              alert: c.sessions[p.id]?.emergency?.isActive == true,
              onTap: () => c.selectPet(p),
              child: PetPhoto(pet: p, size: 48),
            ),
          ),
        _SwitcherItem(
          label: l.t('Agregar', 'Add'),
          selected: false,
          color: context.colors.muted,
          onTap: onAdd,
          dashed: true,
          child: Icon(Icons.add_rounded, color: context.colors.muted),
        ),
      ]),
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
    this.dashed = false,
    this.alert = false,
  });
  final String label;
  final bool selected, dashed, alert;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Column(children: [
            Badge(
              isLabelVisible: alert,
              backgroundColor: AppTheme.danger,
              smallSize: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                width: selected ? 54 : 48,
                height: selected ? 54 : 48,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dashed ? context.colors.surface : null,
                  border: Border.all(
                    color: alert ? AppTheme.danger : (selected ? color : (dashed ? context.colors.line : Colors.transparent)),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(child: Center(child: child)),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? context.colors.ink : context.colors.muted,
                )),
          ]),
        ),
      );
}

/// Tarjeta principal: foto con anillo que late, nombre y estado en vivo.
class _PetHeroCard extends StatelessWidget {
  const _PetHeroCard({required this.pet, required this.tracker, required this.onMap});
  final Pet pet;
  final TrackerDevice tracker;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final s = c.session!;
    final online = tracker.isConnected;
    final outside = online && !c.insideZone;
    final lowBattery = tracker.batteryLevel < 20;
    final secondsAgo = DateTime.now().difference(tracker.lastUpdate).inSeconds.clamp(0, 9999);
    final dist = c.distanceFromCenter;
    final zoneNow = s.currentZone;
    final walking = c.activeWalk != null;
    final noSignal = !s.hasSignal;

    return AppCard(
      color: pet.color.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 18),
      onTap: () => Navigator.pushNamed(context, AppRoutes.petProfile),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PetAvatar(pet: pet, size: 84, live: online, alert: outside),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pet.name, style: context.text.displaySmall),
              const SizedBox(height: 2),
              Text(l.petSubtitle(pet.breed, pet.species, pet.age),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
              if (dist != null && online) ...[
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    walking ? l.t('De paseo contigo', 'On a walk with you') : l.awayFromHome(Fmt.distance(dist, c.metric)),
                    key: ValueKey('$outside$walking'),
                    style: context.text.titleMedium?.copyWith(color: outside && !walking ? AppTheme.danger : pet.color),
                  ),
                ),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (noSignal)
          StatusChip(
            label: l.t('Esperando la señal del collar', 'Waiting for the collar signal'),
            icon: Icons.sensors_off_rounded,
            color: context.colors.muted,
          )
        else
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusChip(
            label: !online
                ? l.unknown
                : walking
                    ? l.t('Paseando', 'Walking')
                    : outside
                        ? l.outsideZone
                        : l.inZoneShort(zoneNow?.name ?? ''),
            icon: walking ? Icons.directions_walk_rounded : (outside ? Icons.warning_rounded : Icons.home_rounded),
            color: !online ? context.colors.muted : (outside && !walking ? AppTheme.danger : pet.color),
          ),
          StatusChip(
            label: online ? l.gpsOnline : l.gpsOffline,
            icon: online ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            color: online ? context.colors.ink : AppTheme.danger,
          ),
          StatusChip(
            label: l.battery(tracker.batteryLevel),
            icon: lowBattery ? Icons.battery_alert_rounded : Icons.battery_5_bar_rounded,
            color: lowBattery ? AppTheme.warning : context.colors.ink,
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              noSignal
                  ? l.t('Collar ${pet.trackerId}: aún no envía su ubicación', 'Collar ${pet.trackerId}: no location yet')
                  : l.updatedAgo(secondsAgo),
              style: context.text.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: onMap,
            icon: const Icon(Icons.map_rounded, size: 18),
            label: Text(l.t('Ver en el mapa', 'See on map')),
          ),
        ]),
      ]),
    );
  }
}

/// Actividad de hoy: anillo de la meta + resumen de la IA.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final s = c.session!;
    final pet = s.pet;
    final today = c.today;
    final p = pet.dailyGoalMeters <= 0 ? 0.0 : today.distanceMeters / pet.dailyGoalMeters;
    final summaryFresh = s.daySummary != null && s.daySummaryDay == today.day;
    return AppCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProgressRing(
            progress: p,
            color: pet.color,
            size: 96,
            stroke: 10,
            child: Text('${(p * 100).round()}%', style: context.text.titleLarge),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('Hoy', 'Today'), style: context.text.titleMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 18, runSpacing: 8, children: [
                MiniStat(value: Fmt.distance(today.distanceMeters, c.metric), label: l.t('recorridos', 'walked')),
                MiniStat(value: '${today.activeMinutes} min', label: l.t('activo', 'active')),
                MiniStat(value: '${c.walksToday.length}', label: l.t('paseos', 'walks')),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: pet.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: pet.color),
              const SizedBox(width: 6),
              Text(l.t('Resumen del día', 'Daily summary'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: s.summaryLoading
                  ? Row(key: const ValueKey('loading'), children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(l.t('La IA está escribiendo...', 'The AI is writing...')),
                    ])
                  : Text(
                      summaryFresh
                          ? s.daySummary!
                          : l.t('Pídele a la IA que te cuente cómo va el día de ${pet.name}.',
                              "Ask the AI how ${pet.name}'s day is going."),
                      key: ValueKey(s.daySummary),
                      style: summaryFresh ? null : TextStyle(color: context.colors.muted),
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: s.summaryLoading ? null : c.requestDaySummary,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(summaryFresh ? l.t('Actualizar', 'Refresh') : l.t('Ver resumen', 'Get summary')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Paseo: botón para empezar o el paseo en curso con su tiempo y distancia.
class _WalkCard extends StatelessWidget {
  const _WalkCard();
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final w = c.activeWalk;
    final pet = c.selectedPet!;
    if (w == null) {
      return AppCard(
        onTap: c.startWalk,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: pet.color, shape: BoxShape.circle),
            child: const Icon(Icons.directions_walk_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('Iniciar paseo', 'Start a walk'), style: context.text.titleMedium),
              Text(l.t('Grabamos la ruta, el tiempo y la distancia.', 'We record the route, time and distance.'),
                  style: context.text.bodySmall),
            ]),
          ),
          Icon(Icons.play_arrow_rounded, color: pet.color, size: 32),
        ]),
      );
    }
    return AppCard(
      color: pet.color,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Row(children: [
          const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('Paseo en curso', 'Walk in progress'),
                  style: context.text.titleMedium?.copyWith(color: Colors.white)),
              Text('${fmtDuration(w.duration)}   ${Fmt.distance(w.distanceMeters, c.metric)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: pet.color, minimumSize: const Size(0, 44)),
            onPressed: () async {
              final done = await c.stopWalk();
              if (done != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l.t('Paseo guardado: ${Fmt.distance(done.distanceMeters, c.metric)} en ${fmtDuration(done.duration)}',
                        'Walk saved: ${Fmt.distance(done.distanceMeters, c.metric)} in ${fmtDuration(done.duration)}'))));
              }
            },
            child: Text(l.t('Terminar', 'Finish')),
          ),
        ]),
      ),
    );
  }
}

/// Recordatorios de salud que vencen pronto.
class _RemindersCard extends StatelessWidget {
  const _RemindersCard();
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return AppCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.health),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_rounded, color: AppTheme.warning),
          const SizedBox(width: 8),
          Text(l.t('Recordatorios', 'Reminders'), style: context.text.titleMedium),
        ]),
        const SizedBox(height: 8),
        for (final r in c.reminders.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(healthIcon(r.type), size: 18, color: context.colors.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(dueText(r, l), style: TextStyle(color: (r.daysUntilDue() ?? 0) < 0 ? AppTheme.danger : AppTheme.warning, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

/// Texto de "vence en X días".
String dueText(HealthRecord r, AppL10n l) {
  final d = r.daysUntilDue();
  if (d == null) return '';
  if (d < 0) return l.t('Venció hace ${-d} d', 'Overdue ${-d} d');
  if (d == 0) return l.t('Hoy', 'Today');
  if (d == 1) return l.t('Mañana', 'Tomorrow');
  return l.t('En $d días', 'In $d days');
}

/// Foto grande con botón de cámara para elegir una imagen.
class PhotoButton extends StatelessWidget {
  const PhotoButton({super.key, required this.pet, required this.label, required this.onPicked, this.size = 110});
  final Pet pet;
  final String label;
  final ValueChanged<Uint8List> onPicked;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final bytes = await pickPetPhoto();
            if (bytes != null) onPicked(bytes);
          },
          child: Stack(clipBehavior: Clip.none, children: [
            PetAvatar(pet: pet, size: size),
            Positioned(
              right: size * 0.18,
              bottom: size * 0.18,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: pet.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 3),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      );
}

class PetProfileScreen extends StatelessWidget {
  const PetProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final p = c.selectedPet, t = c.tracker;
    if (p == null || t == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Center(
          child: PhotoButton(
            pet: p,
            size: 150,
            label: l.changePhoto,
            onPicked: (b) => c.updatePet(p.copyWith(photo: b)),
          ),
        ),
        Center(child: Text(p.name, style: context.text.displaySmall)),
        Center(
          child: Text(l.petSubtitle(p.breed, p.species, p.age),
              style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.petColor, style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(l.petColorHint, style: context.text.bodySmall),
            const SizedBox(height: 14),
            PetColorPicker(selected: p.color, es: l.isEs, onChanged: (col) => c.updatePet(p.copyWith(color: col))),
          ]),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(children: [
            InfoRow(icon: Icons.pets_rounded, label: l.species, value: p.species),
            InfoRow(icon: Icons.category_outlined, label: l.breed, value: p.breed.isEmpty ? '—' : p.breed),
            InfoRow(icon: Icons.cake_outlined, label: l.age, value: l.ageYears(p.age)),
            InfoRow(icon: Icons.monitor_weight_outlined, label: l.weight, value: '${p.weight} kg'),
            InfoRow(
                icon: Icons.flag_outlined,
                label: l.t('Meta diaria', 'Daily goal'),
                value: Fmt.distance(p.dailyGoalMeters, c.metric)),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.pushNamed(context, AppRoutes.collar),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(children: [
            InfoRow(icon: Icons.sensors_rounded, label: l.t('Collar', 'Collar'), value: p.trackerId),
            InfoRow(
                icon: t.isConnected ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                label: l.gpsStatus,
                value: t.isConnected ? l.connected : l.disconnected),
          ]),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(l.t('Eliminar a ${p.name}', 'Delete ${p.name}')),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.t('¿Eliminar a ${p.name}?', 'Delete ${p.name}?')),
                content: Text(l.t('Se borrará su perfil de este dispositivo.', 'Their profile will be removed from this device.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.delete),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            await c.deletePet(p.id);
            if (!context.mounted) return;
            if (c.pets.isEmpty) {
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.setup, (_) => false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ]),
    );
  }
}
 