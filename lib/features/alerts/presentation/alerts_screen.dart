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
          : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
              Row(children: [
                Expanded(child: Text(l.navAlerts, style: context.text.headlineSmall)),
                TextButton(onPressed: c.clearAlerts, child: Text(l.t('Borrar todo', 'Clear all'))),
              ]),
              const SizedBox(height: 10),
              for (final a in alerts.take(100))
                // Cada alerta nueva entra deslizándose desde arriba.
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
