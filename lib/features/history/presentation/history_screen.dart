import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';

/// Historial como línea de tiempo: un punto por ubicación, rojo si estaba fuera.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final h = c.history;
    final accent = context.accent;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.locationHistory)),
      body: h.isEmpty
          ? EmptyState(icon: Icons.timeline_rounded, text: l.waitingLocation)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: h.length,
              itemBuilder: (_, i) {
                final e = h[i], loc = e.location, ok = c.session?.isInsideZones(loc) ?? e.inside;
                final color = ok ? accent : AppTheme.danger;
                return IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      width: 24,
                      child: Column(children: [
                        Expanded(child: Container(width: 2, color: i == 0 ? Colors.transparent : context.colors.line)),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        Expanded(
                            child: Container(
                                width: 2, color: i == h.length - 1 ? Colors.transparent : context.colors.line)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ok ? l.insideZoneMsg : l.outsideZone,
                              style: TextStyle(fontWeight: FontWeight.w700, color: ok ? context.colors.ink : AppTheme.danger)),
                          Text(
                              '${Fmt.time(loc.timestamp)}   ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                              style: text.bodySmall),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
