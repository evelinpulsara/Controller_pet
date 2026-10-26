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
            ),
            if (r.notes.isNotEmpty) Text(r.notes, style: context.text.bodySmall),
          ]),
        ),
        if (r.needsAttention)
          Text(dueText(r, l), style: TextStyle(color: dueColor, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Formulario para agregar o editar un registro de salud.
Future<void> showHealthForm(BuildContext context, {HealthRecord? record}) {
  final c = AppScope.of(context);
  final l = AppL10n.fromLocale(c.locale);
  final title = TextEditingController(text: record?.title ?? '');
  final notes = TextEditingController(text: record?.notes ?? '');
  var type = record?.type ?? HealthType.vaccine;
  var date = record?.date ?? DateTime.now();
  DateTime? next = record?.nextDue;

  Future<DateTime?> pick(BuildContext ctx, DateTime initial) => showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: Locale(c.locale),
      );

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record == null ? l.t('Nuevo registro', 'New record') : l.t('Editar registro', 'Edit record'),
                style: ctx.text.headlineSmall),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in HealthType.values)
                ChoiceChip(
                  avatar: Icon(healthIcon(t), size: 18),
                  label: Text(healthTypeName(t, l)),
                  selected: type == t,
                  onSelected: (_) => setState(() => type = t),
                ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.t('Nombre', 'Name'),
                hintText: switch (type) {
                  HealthType.vaccine => l.t('Ej: Rabia', 'E.g. Rabies'),
                  HealthType.deworming => l.t('Ej: Desparasitante interno', 'E.g. Internal dewormer'),
                  HealthType.vet => l.t('Ej: Control anual', 'E.g. Yearly check-up'),
                  HealthType.medication => l.t('Ej: Antibiótico', 'E.g. Antibiotic'),
                },
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(Fmt.date(date)),
                  onPressed: () async {
                    final d = await pick(ctx, date);
                    if (d != null) setState(() => date = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text(next == null ? l.t('Próxima fecha', 'Next date') : Fmt.date(next!)),
                  onPressed: () async {
                    final d = await pick(ctx, next ?? date.add(const Duration(days: 365)));
                    if (d != null) setState(() => next = d);
                  },
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(l.t('Te recordaremos 7 días antes de la próxima fecha.', "We'll remind you 7 days before the next date."),
                  style: ctx.text.bodySmall),
            ),
            const SizedBox(height: 12),
            TextField(controller: notes, decoration: InputDecoration(labelText: l.t('Notas (opcional)', 'Notes (optional)'))),
            const SizedBox(height: 20),
            Row(children: [
              if (record != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                  onPressed: () {
                    c.deleteHealthRecord(record.id);
                    Navigator.pop(ctx);
                  },
                  child: Text(l.delete),
                ),
              const Spacer(),
              FilledButton(
                onPressed: title.text.trim().isEmpty
                    ? null
                    : () {
                        c.saveHealthRecord(HealthRecord(
                          id: record?.id ?? newId(),
                          petId: c.selectedPet!.id,
                          type: type,
                          title: title.text.trim(),
                          date: date,
                          nextDue: next,
                          notes: notes.text.trim(),
                        ));
                        Navigator.pop(ctx);
                      },
                child: Text(l.save),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
