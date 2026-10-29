import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';

/// "Mi collar": batería, señal, última conexión, modo ahorro y vincular otro collar.
/// Esta pantalla queda lista para cuando conectes el GPS real.
class CollarScreen extends StatelessWidget {
  const CollarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final t = c.tracker, pet = c.selectedPet, s = c.session;
    if (t == null || pet == null || s == null) return const Scaffold();
    final battColor = t.batteryLevel < 20 ? AppTheme.danger : (t.batteryLevel < 40 ? AppTheme.warning : pet.color);
    final hours = t.estimatedHoursLeft;
    final secondsAgo = DateTime.now().difference(t.lastUpdate).inSeconds;
    final simulated = s.mock != null;
    final noSignal = !s.hasSignal;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('Collar de ${pet.name}', "${pet.name}'s collar"))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        if (noSignal)
          AppCard(
            color: context.colors.line.withValues(alpha: 0.5),
            child: Column(children: [
              Icon(Icons.sensors_off_rounded, size: 48, color: context.colors.muted),
              const SizedBox(height: 10),
              Text(l.t('Esperando la señal del collar', 'Waiting for the collar signal'), style: context.text.titleMedium),
              const SizedBox(height: 6),
              Text(
                l.t('El collar ${t.id} todavía no ha enviado su ubicación. Enciéndelo y asegúrate de que tenga batería y señal; '
                    'en cuanto envíe datos, aquí verás su batería, señal y última conexión.',
                    'Collar ${t.id} has not sent its location yet. Turn it on and make sure it has battery and signal; '
                    "as soon as it sends data you'll see battery, signal and last connection here."),
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ]),
          )
        else ...[
        // Batería grande
        Center(
          child: ProgressRing(
            progress: t.batteryLevel / 100,
            color: battColor,
            size: 180,
            stroke: 14,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${t.batteryLevel}%', style: context.text.displaySmall),
              Text(
                hours >= 1
                    ? l.t('≈ ${hours.round()} h restantes', '≈ ${hours.round()} h left')
                    : l.t('Menos de 1 h', 'Less than 1 h'),
                style: context.text.bodySmall,
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: StatusChip(
            label: t.isConnected ? l.connected : l.disconnected,
            icon: t.isConnected ? Icons.link_rounded : Icons.link_off_rounded,
            color: t.isConnected ? pet.color : AppTheme.danger,
          ),
        ),
        const SizedBox(height: 20),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(children: [
            InfoRow(icon: Icons.qr_code_rounded, label: l.t('Código', 'Code'), value: t.id),
            if (!noSignal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 20, color: context.colors.muted),
                const SizedBox(width: 12),
                Text(l.t('Señal GPS', 'GPS signal'), style: TextStyle(color: context.colors.muted)),
                const Spacer(),
                _SignalBars(level: t.isConnected ? t.signal : 0, color: pet.color),
              ]),
            ),
            if (!noSignal)
