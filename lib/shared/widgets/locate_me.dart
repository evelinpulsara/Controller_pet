import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_localizations.dart';
import '../../core/location/owner_location.dart';
import '../../core/theme/app_theme.dart';
import '../../features/tracking/presentation/app_controller.dart';

Future<OwnerFix?> locateOwner(BuildContext context) async {
  final c = AppScope.of(context);
  final l = AppL10n.fromLocale(c.locale);
  final fix = await OwnerLocation.current();
  if (fix.ok || !context.mounted) return fix.ok ? fix : null;
  final msg = switch (fix.status) {
    LocationStatus.serviceOff => l.t('La ubicación del dispositivo está apagada. Actívala e inténtalo de nuevo.',
        "Location is turned off on this device. Turn it on and try again."),
    LocationStatus.denied => l.t('No diste permiso de ubicación. Puedes marcar tu casa tocando el mapa.',
        "Location permission was not granted. You can mark your home by tapping the map."),
    LocationStatus.deniedForever => l.t(
        'El permiso de ubicación está bloqueado. Actívalo en la configuración del navegador o del celular (ícono del candado junto a la dirección).',
        'Location permission is blocked. Enable it in your browser or phone settings (lock icon next to the address).'),
    _ => l.t('No pudimos obtener tu ubicación. Inténtalo de nuevo o toca el mapa.',
        "We couldn't get your location. Try again or tap the map."),
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 6),
    action: fix.status == LocationStatus.deniedForever
        ? SnackBarAction(label: l.t('Ajustes', 'Settings'), onPressed: OwnerLocation.openSettings)
        : null,
  ));
  return null;
}

class UseMyLocationCard extends StatefulWidget {
  const UseMyLocationCard({super.key, required this.onLocated, this.autoStart = false});
  final void Function(LatLng position, double? accuracy) onLocated;
  final bool autoStart;
  @override
  State<UseMyLocationCard> createState() => _UseMyLocationCardState();
}

class _UseMyLocationCardState extends State<UseMyLocationCard> {
  bool _loading = false;
  double? _accuracy;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  Future<void> _locate() async {
    if (_loading) return;
    setState(() => _loading = true);
    final fix = await locateOwner(context);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (fix != null) {
        _done = true;
        _accuracy = fix.accuracyMeters;
      }
    });
    if (fix != null) widget.onLocated(fix.position!, fix.accuracyMeters);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(_done ? Icons.where_to_vote_rounded : Icons.my_location_rounded, color: context.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _done ? l.t('Ubicación encontrada', 'Location found') : l.t('Usa tu ubicación real', 'Use your real location'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _done
                  ? l.t('Precisión aprox. ±${(_accuracy ?? 0).round()} m. Si no quedó exacto, toca el mapa para ajustarlo.',
                      'Accuracy approx. ±${(_accuracy ?? 0).round()} m. If it is off, tap the map to adjust it.')
                  : l.t('Te pediremos permiso para saber dónde estás y marcar ahí tu casa.',
                      "We'll ask permission to know where you are and mark your home there."),
              style: context.text.bodySmall,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: _locate,
                child: Text(_done ? l.t('Otra vez', 'Again') : l.t('Usar', 'Use')),
              ),
      ]),
    );
  }
}

class OwnerDot extends StatelessWidget {
  const OwnerDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: ownerBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: ownerBlue.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 6)],
        ),
      );
}

const ownerBlue = Color(0xFF2F80ED);

Future<bool> enableOwnerLocation(BuildContext context) async {
  final c = AppScope.of(context);
  final fix = await locateOwner(context);
  if (fix == null) return false;
  c.startOwnerTracking(fix);
  return true;
}
