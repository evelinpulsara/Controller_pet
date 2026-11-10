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

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _loading = false, _hidePassword = true;

  Future<void> _submit({bool demo = false}) async {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    if (demo) {
      _email.text = AppController.demoEmail;
      _password.text = AppController.demoPassword;
    }
    setState(() => _loading = true);
    final r = await c.login(_email.text.trim(), _password.text, register: _register && !demo);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (r.status) {
      case LoginStatus.ok:
        Navigator.pushReplacementNamed(context, AppRoutes.nextFor(c));
      case LoginStatus.confirmEmail:
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.mark_email_unread_rounded, color: context.accent, size: 40),
            title: Text(l.t('Confirma tu correo', 'Confirm your email')),
            content: Text(l.t(
                'Te enviamos un correo a ${_email.text.trim()}. Abre el enlace para activar tu cuenta y luego inicia sesión aquí.',
                'We sent an email to ${_email.text.trim()}. Open the link to activate your account, then log in here.')),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _register = false);
                },
                child: Text(l.t('Entendido', 'Got it')),
              ),
            ],
          ),
        );
      case LoginStatus.invalid:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_register
                ? l.loginError
                : l.t('Correo o contraseña incorrectos.', 'Wrong email or password.'))));
      case LoginStatus.error:
        final m = r.message ?? '';
        final friendly = m.toLowerCase().contains('already registered')
            ? l.t('Ese correo ya tiene una cuenta. Inicia sesión.', 'That email already has an account. Log in.')
            : m.toLowerCase().contains('rate limit')
                ? l.t('Demasiados intentos. Espera unos minutos e inténtalo de nuevo.', 'Too many attempts. Wait a few minutes and try again.')
                : m.toLowerCase().contains('socket') || m.toLowerCase().contains('network') || m.toLowerCase().contains('failed host')
                    ? l.t('Sin conexión a internet. Revisa tu conexión.', 'No internet connection. Check your connection.')
                    : (m.isEmpty ? l.loginError : m);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.pets_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(_register ? l.createAccount : l.welcomeBack,
                        key: ValueKey(_register), style: context.text.headlineMedium),
                  ),
                  const SizedBox(height: 6),
                  Text(l.loginTagline, style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration:
                        InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword ? l.t('Mostrar contraseña', 'Show password') : l.t('Ocultar contraseña', 'Hide password'),
                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_register ? l.register : l.logIn),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(_register ? l.iHaveAccount : l.createAccountLink),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Divider(color: context.colors.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(l.t('o', 'or'), style: context.text.bodySmall),
                    ),
                    Expanded(child: Divider(color: context.colors.line)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _submit(demo: true),
                      icon: const Icon(Icons.science_outlined),
                      label: Text(l.t('Probar con la cuenta demo', 'Try the demo account')),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      l.t('Trae mascotas de ejemplo y un collar GPS simulado que se mueve cerca de ti.',
                          'Comes with sample pets and a simulated GPS collar moving near you.'),
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
 