import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/presentation/app_controller.dart';
import '../domain/pet_alert.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final alerts = c.alerts;
    return SafeArea(
      child: alerts.isEmpty
          ? EmptyState(icon: Icons.notifications_none_rounded, text: l.noAlerts)
          : CenteredListView(maxWidth: 760, children: [
              Row(children: [
                Expanded(child: Text(l.navAlerts, style: context.text.headlineSmall)),
                TextButton(onPressed: c.clearAlerts, child: Text(l.t('Borrar todo', 'Clear all'))),
              ]),
              const SizedBox(height: 10),
              for (final a in alerts.take(100))
                TweenAnimationBuilder<double>(
                  key: ValueKey(a.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) =>
                      Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -10 * (1 - t)), child: child)),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: _color(context, a.type).withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(_icon(a.type), color: _color(context, a.type), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (a.type == AlertType.anomaly)
                            Text(l.t('Comportamiento inusual', 'Unusual behavior'),
                                style: context.text.bodySmall?.copyWith(color: AppTheme.warning, fontWeight: FontWeight.w800)),
                          Text(l.alertMessage(a.type, a.params), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${Fmt.date(a.timestamp)}  ${Fmt.time(a.timestamp)}', style: context.text.bodySmall),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
    );
  }

  IconData _icon(AlertType t) => switch (t) {
        AlertType.leftSafeZone => Icons.wrong_location_rounded,
        AlertType.enteredSafeZone => Icons.home_rounded,
        AlertType.lowBattery => Icons.battery_alert_rounded,
        AlertType.gpsLost => Icons.gps_off_rounded,
        AlertType.trackerDisconnected => Icons.link_off_rounded,
        AlertType.anomaly => Icons.psychology_alt_rounded,
        AlertType.healthReminder => Icons.event_rounded,
      };

  Color _color(BuildContext context, AlertType t) => switch (t) {
        AlertType.leftSafeZone || AlertType.trackerDisconnected => AppTheme.danger,
        AlertType.enteredSafeZone => context.accent,
        _ => AppTheme.warning,
      };
}
