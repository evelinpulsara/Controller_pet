import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../contacts/presentation/whatsapp.dart';
import '../../tracking/presentation/app_controller.dart';

/// Tarjeta del asistente de emergencias (IA) en la pantalla de Inicio.
class EmergencyAssistantCard extends StatelessWidget {
  const EmergencyAssistantCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final e = c.emergency;
    final pet = c.selectedPet?.name ?? '';

    // ── Sin emergencia: el asistente está vigilando ──────────────────────
    if (e == null) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(context, l.emergencyAssistant, Icons.auto_awesome_rounded, context.accent),
          const SizedBox(height: 8),
          Text(l.assistantWatching(pet, c.contacts.length),
              style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.contacts),
              icon: const Icon(Icons.contacts_rounded),
              label: Text(l.manageContacts(c.contacts.length)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () => _confirmLost(context, l, c),
              icon: const Icon(Icons.campaign_rounded),
              label: Text(l.t('$pet se perdió', '$pet is lost')),
            ),
          ]),
        ]),
      );
    }

    final found = !e.isActive;
    final color = found ? AppTheme.ok : AppTheme.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(
            context,
            found
                ? l.petFoundTitle(e.report.petName)
                : (e.manual ? l.t('🚨 Buscando a ${e.report.petName}', '🚨 Looking for ${e.report.petName}') : l.petLostTitle(e.report.petName)),
            found ? Icons.check_circle_rounded : Icons.warning_rounded,
            color,
          ),
          if (!found) ...[const SizedBox(height: 4), _LostTimer(since: e.startedAt, es: l.isEs)],
          const SizedBox(height: 8),

          // Aviso de la IA para el dueño
          if (e.isWriting)
            Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.aiWriting)),
            ])
          else if (!found)
            Text(e.messages!.ownerAlert)
          else
            Text(l.petFoundBody(e.report.petName)),

          // Acciones de búsqueda
          if (!found) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.poster),
                icon: const Icon(Icons.image_rounded),
                label: Text(l.t('Cartel "Se busca"', '"Missing" poster')),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: c.markFound,
                icon: const Icon(Icons.favorite_rounded),
                label: Text(l.t('¡Ya apareció!', 'Found!')),
              ),
            ]),
          ],

          // Mensaje preparado para los contactos
          if (!e.isWriting && !found) ...[
            const SizedBox(height: 14),
            Text(l.messageForContacts, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
              child: Text(c.contactMessageNow()),
            ),
          ],

          // Botones de WhatsApp por contacto
          if (!e.isWriting) ...[
            const SizedBox(height: 12),
            if (c.contacts.isEmpty)
              Text(l.noContactsToNotify)
            else
              for (final ct in c.contacts)
                if (!found || e.notifiedContactIds.contains(ct.id))
                  _ContactRow(
                    name: ct.fullName,
                    done: found ? e.thankedContactIds.contains(ct.id) : e.notifiedContactIds.contains(ct.id),
                    label: found ? l.sendFoundWhatsApp : l.sendWhatsApp,
                    doneLabel: l.sent,
                    onSend: () async {
                      final msg = found ? c.foundMessage() : c.contactMessageNow();
                      final ok = await openWhatsApp(ct.whatsappNumber, msg);
                      if (ok) {
                        found ? c.markThanked(ct.id) : c.markNotified(ct.id);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.whatsappError)));
                      }
                    },
                  ),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.contacts),
                icon: const Icon(Icons.person_add_rounded),
                label: Text(l.addContact),
              ),
              if (found) TextButton(onPressed: c.dismissEmergency, child: Text(l.close)),
            ]),
          ],
        ]),
      ),
    );
  }

  void _confirmLost(BuildContext context, AppL10n l, AppController c) {
    final pet = c.selectedPet?.name ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.campaign_rounded, color: AppTheme.danger, size: 36),
        title: Text(l.t('¿$pet se perdió?', 'Is $pet lost?')),
        content: Text(l.t(
            'Activaremos el modo búsqueda: la IA prepara el aviso para tus contactos y un cartel de "Se busca" para compartir.',
            'We will start search mode: the AI prepares the message for your contacts and a "Missing" poster to share.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              c.startLostMode();
            },
            child: Text(l.t('Sí, empezar a buscar', 'Yes, start searching')),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text, IconData icon, Color color) => Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.text.titleMedium)),
      ]);
}

/// "Perdido hace 12 min" (se actualiza solo).
class _LostTimer extends StatefulWidget {
  const _LostTimer({required this.since, required this.es});
  final DateTime since;
  final bool es;
  @override
  State<_LostTimer> createState() => _LostTimerState();
}

class _LostTimerState extends State<_LostTimer> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    final txt = d.inMinutes < 1
        ? (widget.es ? 'Hace menos de 1 min' : 'Less than 1 min ago')
        : (widget.es ? 'Hace ${fmtDuration(d)}' : '${fmtDuration(d)} ago');
    return Text(txt, style: context.text.bodySmall?.copyWith(color: AppTheme.danger, fontWeight: FontWeight.w700));
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(
      {required this.name, required this.done, required this.label, required this.doneLabel, required this.onSend});
  final String name, label, doneLabel;
  final bool done;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 380;
        final who = Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.accent.withValues(alpha: 0.15),
            child: Text(name.characters.first.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, color: context.accent)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]);
        final send = Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: done ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.check_circle_rounded, color: AppTheme.ok, semanticLabel: doneLabel),
            ),
          ),
          Flexible(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.whatsapp,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onSend,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
        ]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  who,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: send),
                ])
              : Row(children: [Expanded(child: who), send]),
        );
      });
}
