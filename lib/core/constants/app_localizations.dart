import '../../features/alerts/domain/pet_alert.dart';

/// All UI strings in English and Spanish.
/// Usage: final l = AppL10n.of(context);  then  l.settings, l.logOut, etc.
class AppL10n {
  const AppL10n._(this.locale);

  final String locale; // 'en' | 'es'

  static AppL10n of(dynamic context) {
    // Resolved via AppScope; see app_controller.dart
    throw UnimplementedError('Use AppL10n.fromLocale instead.');
  }

  static AppL10n fromLocale(String locale) => AppL10n._(locale);

  bool get isEs => locale == 'es';

  /// Texto en el idioma actual: `l.t('Hola', 'Hello')`.
  String t(String es, String en) => isEs ? es : en;

  // ── General ──────────────────────────────────────────────────────────────
  String get appName => 'PetTracker';
  String get save => isEs ? 'Guardar' : 'Save';
  String get cancel => isEs ? 'Cancelar' : 'Cancel';
  String get language => isEs ? 'Idioma' : 'Language';
  String get spanish => isEs ? 'Español' : 'Spanish';
  String get english => isEs ? 'Inglés' : 'English';

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get welcomeBack => isEs ? 'Bienvenido de nuevo' : 'Welcome back';
  String get createAccount => isEs ? 'Crear cuenta' : 'Create account';
  String get email => isEs ? 'Correo electrónico' : 'Email';
  String get password => isEs ? 'Contraseña' : 'Password';
  String get logIn => isEs ? 'Iniciar sesión' : 'Log in';
  String get register => isEs ? 'Registrarse' : 'Register';
  String get iHaveAccount => isEs ? 'Ya tengo una cuenta' : 'I already have an account';
  String get createAccountLink => isEs ? 'Crear una cuenta' : 'Create an account';
  String get loginError => isEs
      ? 'Ingresa un correo válido y una contraseña de al menos 4 caracteres'
      : 'Enter a valid email and a password of 4+ characters';

  // ── Bottom nav ────────────────────────────────────────────────────────────
  String get navHome => isEs ? 'Inicio' : 'Home';
  String get navLive => isEs ? 'En vivo' : 'Live';
  String get navZones => isEs ? 'Zonas' : 'Zones';
  String get navMap => isEs ? 'Mapa' : 'Map';
  String get navActivity => isEs ? 'Actividad' : 'Activity';
  String welcomeHome(String pet) => isEs ? '¡$pet está de vuelta en casa! 🎉' : '$pet is back home! 🎉';
  String get navAlerts => isEs ? 'Alertas' : 'Alerts';
  String get navSettings => isEs ? 'Ajustes' : 'Settings';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  String hello(String name) => isEs ? 'Hola, $name' : 'Hi, $name';
  String inZoneShort(String zone) => isEs ? 'En $zone' : 'At $zone';
  String updatedAgo(int s) => s < 3
      ? (isEs ? 'Actualizado ahora' : 'Updated just now')
      : (isEs ? 'Actualizado hace $s s' : 'Updated ${s}s ago');
  String petSubtitle(String breed, String species, int age) {
    final what = breed.trim().isEmpty ? species : breed;
    return isEs ? '$what de $age ${age == 1 ? 'año' : 'años'}' : '$age-year-old $what';
  }
  String awayFromHome(String dist) => isEs ? '$dist de casa' : '$dist from home';
  String get changePhoto => isEs ? 'Cambiar foto' : 'Change photo';
  String get addPhoto => isEs ? 'Agregar foto' : 'Add photo';
  String get petColor => isEs ? 'Su color' : 'Their color';
  String get petColorHint => isEs
      ? 'La app se pinta de este color cuando miras a esta mascota.'
      : 'The app takes this color while you look at this pet.';
  String get testMode => isEs ? 'Modo prueba' : 'Test mode';
  String get testModeHint => isEs
      ? 'Simula situaciones para ver cómo responde la app.'
      : 'Simulate situations to see how the app responds.';
  String get dog => isEs ? 'Perro' : 'Dog';
  String get cat => isEs ? 'Gato' : 'Cat';
  String get otherSpecies => isEs ? 'Otro' : 'Other';
  String get loginTagline => isEs ? 'Sabe dónde está tu mascota, siempre.' : 'Always know where your pet is.';
  String whereIs(String pet) => isEs ? '¿Dónde está $pet?' : 'Where is $pet?';
  String get recentPath => isEs ? 'Puntos: su recorrido reciente' : 'Dots: their recent path';
  String get profile => isEs ? 'Perfil' : 'Profile';
