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
            InfoRow(
              icon: Icons.schedule_rounded,
              label: l.t('Última conexión', 'Last seen'),
              value: secondsAgo < 5 ? l.t('Ahora', 'Now') : l.t('Hace ${fmtDuration(Duration(seconds: secondsAgo))}', '${fmtDuration(Duration(seconds: secondsAgo))} ago'),
            ),
            InfoRow(
              icon: Icons.update_rounded,
              label: l.t('Envía ubicación cada', 'Sends location every'),
              value: '${c.intervalSeconds * (t.powerSave ? 3 : 1)} s',
            ),
            if (simulated)
              InfoRow(icon: Icons.science_outlined, label: l.t('Tipo', 'Type'), value: l.t('Collar de prueba', 'Test collar')),
          ]),
        ),
        AppCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.eco_rounded, color: pet.color),
            title: Text(l.t('Modo ahorro', 'Power saving')),
            subtitle: Text(l.t('Envía la ubicación con menos frecuencia para que la batería dure el doble.',
                'Sends location less often so the battery lasts twice as long.')),
            value: t.powerSave,
            onChanged: c.setPowerSave,
          ),
        ),
        if (c.usesCloud)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.key_rounded, color: pet.color),
                const SizedBox(width: 8),
                Expanded(child: Text(l.t('Clave del collar GPS', 'GPS collar key'), style: context.text.titleMedium)),
              ]),
              const SizedBox(height: 4),
              Text(
                l.t('El collar (por ejemplo un Arduino) envía su ubicación usando su código ${t.id} y esta clave secreta. '
                    'Escríbela también en el programa del collar.',
                    'The collar (e.g. an Arduino) sends its location using its code ${t.id} and this secret key. '
                        "Also put it in the collar's program."),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.key_rounded),
                label: Text(l.t('Poner clave del collar', 'Set collar key')),
                onPressed: () => _setKey(context, l, c),
              ),
            ]),
          ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('Vincular otro collar', 'Link another collar'), style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(l.t('Escribe el código que viene impreso en el collar.', 'Type the code printed on the collar.'),
                style: context.text.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded),
              label: Text(l.t('Vincular collar', 'Link collar')),
              onPressed: () => _link(context, l, c),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(
          l.t('Coordenadas actuales: ${c.current == null ? '—' : '${c.current!.latitude.toStringAsFixed(5)}, ${c.current!.longitude.toStringAsFixed(5)}'}',
              'Current coordinates: ${c.current == null ? '—' : '${c.current!.latitude.toStringAsFixed(5)}, ${c.current!.longitude.toStringAsFixed(5)}'}'),
          style: context.text.bodySmall,
        ),
        Text('${l.t('Distancia a casa', 'Distance to home')}: ${Fmt.distance(c.distanceFromCenter ?? 0, c.metric)}',
            style: context.text.bodySmall),
      ]),
    );
  }

  void _setKey(BuildContext context, AppL10n l, AppController c) {
    final key = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.t('Clave del collar', 'Collar key')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: key,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.t('Clave secreta (mínimo 12 caracteres)', 'Secret key (at least 12 characters)'),
                prefixIcon: const Icon(Icons.key_rounded),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(
              onPressed: () async {
                if (key.text.length < 12) {
                  setState(() => error = l.t('Debe tener al menos 12 caracteres.', 'Must be at least 12 characters.'));
                  return;
                }
                try {
                  await c.setCollarKey(key.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.t('Clave guardada. El collar ya puede enviar su ubicación.', 'Key saved. The collar can now send its location.'))));
                  }
                } catch (e) {
                  setState(() => error = l.t('No se pudo guardar. Revisa tu conexión.', "Couldn't save. Check your connection."));
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  void _link(BuildContext context, AppL10n l, AppController c) {
    final code = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('Vincular collar', 'Link collar')),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'TRK-0000', prefixIcon: Icon(Icons.qr_code_rounded)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () async {
              if (code.text.trim().length < 4) return;
              Navigator.pop(ctx);
              await c.linkCollar(code.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.t('Collar vinculado', 'Collar linked'))));
              }
            },
            child: Text(l.t('Vincular', 'Link')),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.level, required this.color});
  final int level;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 6,
            height: 6.0 + i * 4,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: i <= level ? color : context.colors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ]);
}
