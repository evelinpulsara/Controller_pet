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
      child: CenteredListView(maxWidth: 760, children: [
        Text(l.settings, style: context.text.headlineSmall),
        const SizedBox(height: 14),

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

        AppCard(
          onTap: () => Navigator.pushNamed(context, AppRoutes.tech),
          child: Row(children: [
            Icon(Icons.speed_rounded, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('Panel técnico', 'Tech panel'), style: context.text.titleMedium),
                Text(l.t('INP, Web Workers, tiempo real, Service Worker...', 'INP, Web Workers, real time, Service Worker...'),
                    style: context.text.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.muted),
          ]),
        ),

        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.shield_outlined),
              title: Text(l.safeZoneAlerts),
              value: c.notifyZone,
              onChanged: (v) => c.setPrefs(zoneAlerts: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.battery_alert_outlined),
              title: Text(l.lowBatteryAlerts),
              value: c.notifyBattery,
              onChanged: (v) => c.setPrefs(batteryAlerts: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.volume_up_outlined),
              title: Text(l.t('Sonido de alarma', 'Alarm sound')),
              subtitle: Text(l.t('Suena fuerte si sale de la zona, no se mueve, va muy rápido o se desconecta el collar.',
                  'Plays loudly if they leave the zone, stop moving, go very fast or the collar disconnects.')),
              value: c.soundEnabled,
              onChanged: c.setSoundEnabled,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: c.testAlarm,
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: Text(l.t('Probar alarma', 'Test alarm')),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: c.testChime,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text(l.t('Probar aviso suave', 'Test soft chime')),
                ),
              ]),
            ),
          ]),
        ),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('Apariencia', 'Appearance'), style: context.text.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(l.t('Claro', 'Light'))),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(l.t('Oscuro', 'Dark'))),
                  ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(l.t('Auto', 'Auto'))),
                ],
                selected: {c.themeMode},
                onSelectionChanged: (s) => c.setThemeMode(s.first),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.trackingInterval, style: context.text.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [for (final s in [2, 3, 5, 10]) ButtonSegment(value: s, label: Text('$s s'))],
                selected: {c.intervalSeconds},
                onSelectionChanged: (s) => c.setPrefs(seconds: s.first),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.units, style: context.text.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(l.metric)),
                  ButtonSegment(value: false, label: Text(l.imperial)),
                ],
                selected: {c.metric},
                onSelectionChanged: (s) => c.setPrefs(isMetric: s.first),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.language, style: context.text.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'es', label: Text('Español')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {c.locale},
                onSelectionChanged: (s) => c.setLocale(s.first),
              ),
            ),
          ]),
        ),

        if (c.isDemo)
        AppCard(
          color: context.colors.line.withValues(alpha: 0.5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.science_outlined, color: context.colors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(l.t('Modo prueba ($pet)', 'Test mode ($pet)'), style: context.text.titleMedium)),
            ]),
            const SizedBox(height: 4),
            Text(l.testModeHint, style: context.text.bodySmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.simulateLeave),
              subtitle: Text(l.simulateLeaveSubtitle),
              value: c.simulateLeaving,
              onChanged: c.setSimulateLeaving,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.t('Simular que no se mueve', "Simulate they don't move")),
              subtitle: Text(l.t('A los 3 min la IA lo detecta como algo inusual.', 'After 3 min it is flagged as unusual.')),
              value: c.simulateFrozen,
              onChanged: c.setSimulateFrozen,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.t('Simular que va muy rápido', 'Simulate moving very fast')),
              subtitle: Text(l.t('Como si fuera en un carro.', 'As if in a car.')),
              value: c.simulateSpeeding,
              onChanged: c.setSimulateSpeeding,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.simulateDisconnect),
              value: !(c.tracker?.isConnected ?? true),
              onChanged: (_) => c.toggleDisconnect(),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded),
              label: Text(l.t('Llenar la semana con datos de ejemplo', 'Fill the week with sample data')),
              onPressed: () async {
                await c.fillSampleWeek();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l.t('Listo: mira la pestaña Actividad.', 'Done: check the Activity tab.'))));
                }
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l.t('Reiniciar la cuenta demo', 'Reset the demo account')),
              onPressed: () async {
                await c.resetDemo();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l.t('La demo quedó como nueva.', 'The demo is fresh again.'))));
                }
              },
            ),
          ]),
        ),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await c.logout();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
            },
            label: Text(l.logOut),
          ),
        ),
      ]),
    );
  }
}

Future<void> editOwnerPhone(BuildContext context) {
  final c = AppScope.of(context);
  final l = AppL10n.fromLocale(c.locale);
  final phone = TextEditingController(text: c.ownerPhone.isEmpty ? '+57 ' : c.ownerPhone);
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.t('Tu celular', 'Your phone')),
      content: TextField(
        controller: phone,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(labelText: l.contactPhone, helperText: l.contactPhoneHelp),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            c.setOwnerPhone(phone.text);
            Navigator.pop(ctx);
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
}
