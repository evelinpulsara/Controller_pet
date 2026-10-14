import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../tracking/presentation/app_controller.dart';
import '../data/auth_service.dart';

/// Pantalla de bienvenida: la huella aparece, un anillo se expande
/// (como la señal del GPS) y luego entra el nombre.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _a.forward();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      final next = AppRoutes.nextFor(AppScope.of(context));
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: next),
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (ctx, _, _) => AppRoutes.routes[next]!(ctx),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    if (reduceMotion(context)) _a.value = 1;
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final pop = Curves.elasticOut.transform((_a.value / 0.6).clamp(0, 1));
            final ring = Curves.easeOut.transform(((_a.value - 0.2) / 0.6).clamp(0, 1));
            final title = Curves.easeOutCubic.transform(((_a.value - 0.45) / 0.55).clamp(0, 1));
            return Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 96 + 100 * ring,
                    height: 96 + 100 * ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.5 * (1 - ring)), width: 3),
                    ),
                  ),
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.pets_rounded, size: 48, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              Opacity(
                opacity: title,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - title)),
                  child: Text('PetTracker', style: context.text.displaySmall),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

