import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final accent = context.accent;
    final pet = c.selectedPet?.name ?? '';
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text(l.settings, style: context.text.headlineSmall),
        const SizedBox(height: 14),

        // Cuenta
        AppCard(
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text((c.user?.name ?? '?').characters.first.toUpperCase(),
                    style: context.text.titleLarge?.copyWith(color: accent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(c.user?.name ?? '', style: context.text.titleMedium)),
                    if (c.isDemo) ...[
                      const SizedBox(width: 8),
                      StatusChip(label: l.t('Cuenta demo', 'Demo account'), icon: Icons.science_outlined, color: AppTheme.warning),
                    ],
                  ]),
                  Text(c.user?.email ?? '', style: context.text.bodySmall),
                  if (c.usesCloud)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const Icon(Icons.cloud_done_rounded, size: 16, color: AppTheme.ok),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(l.t('Tus datos se guardan en la nube', 'Your data is saved in the cloud'),
                              style: context.text.bodySmall?.copyWith(color: AppTheme.ok, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_rounded),
              title: Text(l.t('Tu celular', 'Your phone')),
              subtitle: Text(c.ownerPhone.isEmpty
                  ? l.t('Aparece en el cartel de "Se busca"', 'Shown on the "Missing" poster')
                  : c.ownerPhone),
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: () => editOwnerPhone(context),
            ),
          ]),
        ),

        AppCard(
          onTap: () => Navigator.pushNamed(context, AppRoutes.contacts),
          child: Row(children: [
            Icon(Icons.contacts_rounded, color: accent),
            const SizedBox(width: 14),
            Expanded(child: Text(l.manageContacts(c.contacts.length), style: context.text.titleMedium)),
            Icon(Icons.chevron_right_rounded, color: context.colors.muted),
          ]),
        ),

        // Panel técnico (temas de Programación Orientada a la Web)
        AppCard(
          onTap: () => Navigator.pushNamed(context, AppRoutes.tech),
          child: Row(children: [
            Icon(Icons.speed_rounded, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('Panel técnico', 'Tech panel'), style: context.text.titleMedium),
                Text(l.t('INP, Web Workers, tiempo real, Service Worker...', 'INP, Web Workers, real time, Service Worker...'),
