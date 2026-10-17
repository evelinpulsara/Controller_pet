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
