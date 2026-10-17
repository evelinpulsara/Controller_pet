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
