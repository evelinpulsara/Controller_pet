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
  String get details => isEs ? 'Datos' : 'Details';
  String get gpsOnline => isEs ? 'GPS activo' : 'GPS online';
  String get gpsOffline => isEs ? 'GPS inactivo' : 'GPS offline';
  String battery(int lvl) => isEs ? 'Batería $lvl%' : 'Battery $lvl%';
  String get safeStatus => isEs ? 'Seguro' : 'Safe';
  String get outsideZone => isEs ? 'Fuera de la zona' : 'Outside safe zone';
  String get unknown => isEs ? 'Desconocido' : 'Unknown';
  String get locationLabel => isEs ? 'Ubicación' : 'Location';
  String get lastUpdate => isEs ? 'Última actualización' : 'Last update';
  String get addPet => isEs ? 'Agregar mascota' : 'Add pet';
  String get history => isEs ? 'Historial' : 'History';

  // ── Add pet dialog ────────────────────────────────────────────────────────
  String get addPetTitle => isEs ? 'Agregar mascota' : 'Add pet';
  String get petName => isEs ? 'Nombre' : 'Name';
  String get petSpecies => isEs ? 'Especie' : 'Species';
  String get petBreed => isEs ? 'Raza' : 'Breed';
  String get petAge => isEs ? 'Edad (años)' : 'Age (years)';
  String get petWeight => isEs ? 'Peso (kg)' : 'Weight (kg)';

  // ── Pet profile ───────────────────────────────────────────────────────────
  String get name => isEs ? 'Nombre' : 'Name';
  String get species => isEs ? 'Especie' : 'Species';
  String get breed => isEs ? 'Raza' : 'Breed';
  String get age => isEs ? 'Edad' : 'Age';
  String ageYears(int y) => isEs ? '$y años' : '$y years';
  String get weight => isEs ? 'Peso' : 'Weight';
  String get emergencyContact => isEs ? 'Contacto de emergencia' : 'Emergency contact';
  String get trackerId => isEs ? 'ID del tracker' : 'Tracker ID';
  String get gpsStatus => isEs ? 'Estado del GPS' : 'GPS status';
  String get connected => isEs ? 'Conectado' : 'Connected';
  String get disconnected => isEs ? 'Desconectado' : 'Disconnected';

  // ── Tracking ──────────────────────────────────────────────────────────────
  String get liveTracking => isEs ? 'Seguimiento en vivo' : 'Live tracking';
  String get trackingPaused => isEs ? 'Seguimiento pausado' : 'Tracking paused';
  String get trackingInside => isEs ? 'Seguimiento: dentro de la zona' : 'Tracking: inside zone';
  String get trackingOutside => isEs ? 'Seguimiento: fuera de la zona' : 'Tracking: outside zone';
  String get coordinates => isEs ? 'Coordenadas' : 'Coordinates';
  String get lastUpdated => isEs ? 'Última actualización' : 'Last updated';
  String get distanceFromHome => isEs ? 'Distancia desde casa' : 'Distance from home';
  String get insideZoneMsg => isEs ? 'Dentro de la zona segura' : 'Inside safe zone';
  String outsideZoneByMsg(String dist) =>
      isEs ? 'Fuera de la zona por $dist' : 'Outside safe zone by $dist';

  // ── Geofencing ────────────────────────────────────────────────────────────
  String get safeZone => isEs ? 'Zona segura' : 'Safe zone';
  String get zoneName => isEs ? 'Nombre de la zona' : 'Zone name';
  String radiusLabel(String dist) => isEs ? 'Radio: $dist' : 'Radius: $dist';
  String get zoneEnabled => isEs ? 'Zona activada' : 'Zone enabled';
  String get saveZone => isEs ? 'Guardar zona' : 'Save zone';
  String get zoneSaved => isEs ? 'Zona segura guardada' : 'Safe zone saved';
  String get simulateLeave => isEs ? 'Simular que la mascota sale de la zona' : 'Simulate pet leaving the zone';
  String get simulateLeaveSubtitle =>
      isEs ? 'Desactivar para que vuelva a casa' : 'Turn off to let the pet wander back home';
  String get simulateDisconnect => isEs ? 'Simular desconexión del tracker' : 'Simulate tracker disconnect';

  // ── Asistente de emergencias (IA) ─────────────────────────────────────────
  String get emergencyAssistant => isEs ? 'Asistente de emergencias IA' : 'AI emergency assistant';
  String assistantWatching(String pet, int n) => isEs
      ? 'Estoy vigilando a $pet. Si sale de la zona segura, te aviso al instante y preparo un mensaje '
          'de WhatsApp para pedir ayuda a ${n == 1 ? 'tu contacto' : 'tus $n contactos'} de emergencia.'
      : "I'm watching $pet. If they leave the safe zone, I'll alert you right away and write a WhatsApp "
          'message asking your $n emergency contact${n == 1 ? '' : 's'} for help.';
  String manageContacts(int n) => isEs ? 'Contactos de emergencia ($n)' : 'Emergency contacts ($n)';
  String petLostTitle(String pet) => isEs ? '🚨 ¡$pet salió de la zona segura!' : '🚨 $pet left the safe zone!';
  String petFoundTitle(String pet) => isEs ? '$pet regresó a la zona segura' : '$pet is back in the safe zone';
  String petFoundBody(String pet) => isEs
      ? '¡Qué alivio! Puedes contarles a los contactos que avisaste que $pet ya apareció.'
      : 'What a relief! You can tell the contacts you alerted that $pet is back.';
  String get aiWriting => isEs ? 'La IA está escribiendo los avisos...' : 'The AI is writing the alerts...';
  String get messageForContacts => isEs ? 'Mensaje para tus contactos:' : 'Message for your contacts:';
  String get noContactsToNotify => isEs
      ? 'Aún no tienes contactos de emergencia. Agrega al menos uno para poder pedir ayuda.'
      : "You don't have emergency contacts yet. Add at least one so you can ask for help.";
  String get sendWhatsApp => isEs ? 'Avisar por WhatsApp' : 'Alert on WhatsApp';
  String get sendFoundWhatsApp => isEs ? 'Avisar que apareció' : 'Say they were found';
  String get sent => isEs ? 'Enviado' : 'Sent';
  String get whatsappError => isEs ? 'No se pudo abrir WhatsApp' : 'Could not open WhatsApp';
  String get close => isEs ? 'Cerrar' : 'Close';
  String get alertMyContacts => isEs ? 'Avisar a mis contactos' : 'Alert my contacts';

  // ── Contactos de emergencia ───────────────────────────────────────────────
  String get emergencyContacts => isEs ? 'Contactos de emergencia' : 'Emergency contacts';
  String contactsExplanation(String pet) => isEs
      ? 'Si $pet sale de la zona segura, la IA escribirá un mensaje para pedirles ayuda a estas personas por WhatsApp.'
      : 'If $pet leaves the safe zone, the AI will write a WhatsApp message asking these people for help.';
  String get noContacts => isEs
      ? 'Todavía no hay contactos.\nAgrega vecinos, familiares o amigos que puedan ayudarte.'
      : 'No contacts yet.\nAdd neighbors, family or friends who can help you.';
  String get addContact => isEs ? 'Agregar contacto' : 'Add contact';
  String get contactName => isEs ? 'Nombre' : 'Name';
  String get contactPhone => isEs ? 'Celular (WhatsApp)' : 'Mobile (WhatsApp)';
  String get contactPhoneHelp => isEs ? 'Con código de país, ej: +57 300 123 4567' : 'With country code, e.g. +57 300 123 4567';
  String get contactRelationship => isEs ? 'Parentesco (opcional): vecino, familiar...' : 'Relationship (optional): neighbor, family...';
  String get contactError => isEs
      ? 'Escribe el nombre y un celular válido con código de país.'
      : 'Enter a name and a valid mobile number with country code.';
  String get delete => isEs ? 'Eliminar' : 'Delete';

  // ── Alerts ────────────────────────────────────────────────────────────────
  String get noAlerts => isEs ? 'Sin alertas. Todo está bien 🐾' : 'No alerts yet. Everything looks fine 🐾';

  /// Texto de cada alerta según su tipo, en el idioma elegido.
  String alertMessage(AlertType type, Map<String, String> p) {
    final pet = p['pet'] ?? '', zone = p['zone'] ?? '';
    return switch (type) {
      AlertType.leftSafeZone =>
        isEs ? '$pet salió de la zona segura "$zone".' : '$pet left the safe zone "$zone".',
      AlertType.enteredSafeZone =>
        isEs ? '$pet regresó a la zona segura.' : '$pet is back in the safe zone.',
      AlertType.lowBattery => isEs
          ? 'La batería del collar de $pet está baja (${p['battery']}%).'
          : "$pet's collar battery is low (${p['battery']}%).",
      AlertType.gpsLost =>
        isEs ? 'Se perdió la señal del GPS o está muy débil.' : 'GPS signal lost or very weak.',
      AlertType.trackerDisconnected => isEs
          ? 'El collar ${p['tracker']} se desconectó.'
          : 'Collar ${p['tracker']} disconnected.',
      AlertType.anomaly => switch (p['kind']) {
          'stationary' => isEs
              ? '$pet lleva ${p['minutes']} min sin moverse, algo poco común. ¿Está bien?'
              : '$pet hasn\'t moved for ${p['minutes']} min, which is unusual. Are they OK?',
          'speed' => isEs
              ? '$pet se mueve muy rápido (${p['kmh']} km/h). ¿Va en un vehículo o huyó asustado?'
              : '$pet is moving very fast (${p['kmh']} km/h). In a vehicle or running scared?',
          'night' => isEs
              ? '$pet salió de su zona de noche, a una hora poco habitual.'
              : '$pet left their zone at night, an unusual time.',
          _ => isEs ? 'Comportamiento inusual de $pet.' : 'Unusual behavior from $pet.',
        },
      AlertType.healthReminder => () {
          final d = int.tryParse(p['days'] ?? '') ?? 0;
          final when = d < 0
              ? (isEs ? 'venció hace ${-d} día(s)' : 'was due ${-d} day(s) ago')
              : d == 0
                  ? (isEs ? 'es hoy' : 'is today')
                  : (isEs ? 'vence en $d día(s)' : 'is due in $d day(s)');
          return isEs ? '${p['title']} de $pet $when.' : "$pet's ${p['title']} $when.";
        }(),
    };
  }

  // ── History ───────────────────────────────────────────────────────────────
  String get locationHistory => isEs ? 'Historial de ubicación' : 'Location history';
  String get waitingLocation =>
      isEs ? 'Esperando la primera actualización de ubicación...' : 'Waiting for the first location update...';

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settings => isEs ? 'Ajustes' : 'Settings';
  String get safeZoneAlerts => isEs ? 'Alertas de zona segura' : 'Safe zone alerts';
  String get lowBatteryAlerts => isEs ? 'Alertas de batería baja' : 'Low battery alerts';
  String get trackingInterval => isEs ? 'Intervalo de seguimiento' : 'Tracking interval';
  String get units => isEs ? 'Unidades' : 'Units';
  String get metric => isEs ? 'Métrico' : 'Metric';
  String get imperial => isEs ? 'Imperial' : 'Imperial';
  String get account => isEs ? 'Cuenta' : 'Account';
  String get logOut => isEs ? 'Cerrar sesión' : 'Log out';
}
