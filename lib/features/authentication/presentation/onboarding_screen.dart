import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../tracking/presentation/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  Future<void> _finish() async {
    final c = AppScope.of(context);
    await c.completeOnboarding();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.nextFor(c));
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final pages = [
      (
        Icons.my_location_rounded,
        l.t('Sabe dónde está, siempre', 'Always know where they are'),
        l.t('Conecta el collar GPS y mira a tu mascota en el mapa en tiempo real.',
            'Connect the GPS collar and see your pet on the map in real time.'),
      ),
      (
        Icons.shield_rounded,
        l.t('Zonas seguras', 'Safe zones'),
        l.t('Marca su casa, el parque o donde la cuidan. Si sale de ahí, te avisamos al instante.',
            "Mark home, the park or the sitter's place. If they leave, we alert you right away."),
      ),
      (
        Icons.auto_awesome_rounded,
        l.t('Una IA que te ayuda', 'An AI that helps you'),
        l.t('Si se pierde, la IA escribe el aviso para tus contactos y un cartel de "Se busca".',
            'If they get lost, the AI writes the message for your contacts and a "Missing" poster.'),
      ),
    ];
    final last = _i == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: Text(l.t('Saltar', 'Skip'))),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final (icon, title, body) = pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(i),
                      tween: Tween(begin: 0.6, end: 1),
                      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (_, s, child) => Transform.scale(scale: s, child: child),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(color: context.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(icon, size: 72, color: context.accent),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(title, textAlign: TextAlign.center, style: context.text.headlineMedium),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(body,
                          textAlign: TextAlign.center,
                          style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
                    ),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _i ? context.accent : context.colors.line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
                child: Text(last ? l.t('Empezar', 'Get started') : l.t('Siguiente', 'Next')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
