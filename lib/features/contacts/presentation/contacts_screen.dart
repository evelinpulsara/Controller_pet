import 'package:flutter/material.dart';
import '../../../core/util/ids.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';
import '../domain/emergency_contact.dart';

/// Lista de contactos de emergencia de la mascota seleccionada.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pet = c.selectedPet;
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyContacts)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (pet == null) return;
          final ct = await showContactForm(context, petId: pet.id);
          if (ct != null) await c.addContact(ct);
        },
        icon: const Icon(Icons.person_add_rounded),
        label: Text(l.addContact),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
        Text(l.contactsExplanation(pet?.name ?? ''),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 16),
        if (c.contacts.isEmpty) EmptyState(icon: Icons.group_add_rounded, text: l.noContacts),
        for (final ct in c.contacts)
          AppCard(
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.accent.withValues(alpha: 0.15),
                child: Text(ct.fullName.characters.first.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ct.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(<String?>[ct.relationship, ct.phone].where((s) => s != null && s.isNotEmpty).join(', '),
                      style: context.text.bodySmall),
                ]),
              ),
              IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => c.deleteContact(ct.id),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Formulario para un contacto de emergencia. Devuelve el contacto o null si se cancela.
Future<EmergencyContact?> showContactForm(BuildContext context, {required String petId}) {
  final c = AppScope.of(context);
  final l = AppL10n.fromLocale(c.locale);
  final name = TextEditingController(), phone = TextEditingController(text: '+57 '), relation = TextEditingController();
  String? error;
  return showDialog<EmergencyContact>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.addContact),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.contactName)),
            const SizedBox(height: 8),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l.contactPhone, helperText: l.contactPhoneHelp)),
            const SizedBox(height: 8),
            TextField(controller: relation, decoration: InputDecoration(labelText: l.contactRelationship)),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final digits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (name.text.trim().isEmpty || digits.length < 10) {
                setState(() => error = l.contactError);
                return;
              }
              Navigator.pop(
                ctx,
                EmergencyContact(
                  id: newId(),
                  petId: petId,
                  fullName: name.text.trim(),
                  phone: phone.text.trim(),
                  relationship: relation.text.trim().isEmpty ? null : relation.text.trim(),
                ),
              );
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
}
