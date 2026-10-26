import 'package:flutter/material.dart';
import '../../../core/util/ids.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../pets/presentation/pets_screens.dart' show dueText;
import '../../tracking/presentation/app_controller.dart';
import '../domain/health_record.dart';

IconData healthIcon(HealthType t) => switch (t) {
      HealthType.vaccine => Icons.vaccines_rounded,
      HealthType.deworming => Icons.bug_report_rounded,
      HealthType.vet => Icons.local_hospital_rounded,
      HealthType.medication => Icons.medication_rounded,
    };

String healthTypeName(HealthType t, AppL10n l) => switch (t) {
      HealthType.vaccine => l.t('Vacuna', 'Vaccine'),
      HealthType.deworming => l.t('Desparasitación', 'Deworming'),
      HealthType.vet => l.t('Cita veterinaria', 'Vet visit'),
      HealthType.medication => l.t('Medicamento', 'Medication'),
    };

/// Carnet de salud: vacunas, desparasitación, citas y medicamentos, con recordatorios.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pet = c.selectedPet;
    final records = c.health;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('Salud de ${pet?.name ?? ''}', "${pet?.name ?? ''}'s health"))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showHealthForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.t('Agregar', 'Add')),
      ),
      body: records.isEmpty
          ? EmptyState(
              icon: Icons.medical_services_outlined,
              text: l.t('Anota sus vacunas, desparasitaciones y citas. Te recordaremos cuando se acerque la próxima.',
                  "Log vaccines, deworming and vet visits. We'll remind you when the next one is near."),
              action: FilledButton.icon(
                onPressed: () => showHealthForm(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l.t('Agregar el primero', 'Add the first one')),
              ),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
              if (c.reminders.isNotEmpty) ...[
                SectionTitle(l.t('Próximos', 'Coming up')),
                for (final r in c.reminders) _RecordTile(record: r, highlight: true),
              ],
              // El resto, agrupado por tipo (sin repetir los "Próximos").
              for (final type in HealthType.values)
                if (records.any((r) => r.type == type && !r.needsAttention)) ...[
                  SectionTitle(healthTypeName(type, l)),
                  for (final r in records.where((r) => r.type == type && !r.needsAttention)) _RecordTile(record: r),
                ],
            ]),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, this.highlight = false});
  final HealthRecord record;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final r = record;
    final overdue = (r.daysUntilDue() ?? 1) < 0;
    final dueColor = overdue ? AppTheme.danger : AppTheme.warning;
    return AppCard(
      color: highlight ? dueColor.withValues(alpha: 0.10) : null,
      onTap: () => showHealthForm(context, record: r),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: (highlight ? dueColor : context.accent).withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(healthIcon(r.type), color: highlight ? dueColor : context.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: context.text.titleMedium),
            Text(
              [
                Fmt.date(r.date),
                if (r.nextDue != null) l.t('próxima: ${Fmt.date(r.nextDue!)}', 'next: ${Fmt.date(r.nextDue!)}'),
              ].join('   '),
              style: context.text.bodySmall,
