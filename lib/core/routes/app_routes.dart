import 'package:flutter/material.dart';
import '../../core/constants/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/assistant/presentation/poster_screen.dart';
import '../../features/authentication/presentation/auth_screens.dart';
import '../../features/authentication/presentation/onboarding_screen.dart';
import '../../features/authentication/presentation/setup_wizard.dart';
import '../../features/collar/presentation/collar_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/geofencing/presentation/geofencing_screen.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/perf/presentation/tech_panel_screen.dart';
import '../../features/pets/presentation/pets_screens.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/tracking/presentation/app_controller.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../shared/widgets/celebration.dart';
import '../../shared/widgets/widgets.dart';

class AppRoutes {
  static const splash = '/',
      onboarding = '/welcome',
      login = '/login',
      setup = '/setup',
      home = '/home',
      petProfile = '/pet',
      history = '/history',
      contacts = '/contacts',
      zones = '/zones',
      collar = '/collar',
      health = '/health',
      poster = '/poster',
      tech = '/tech';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        onboarding: (_) => const OnboardingScreen(),
        login: (_) => const LoginScreen(),
        setup: (_) => const SetupWizard(),
        home: (_) => const HomeShell(),
        petProfile: (_) => const PetProfileScreen(),
        history: (_) => const HistoryScreen(),
        contacts: (_) => const ContactsScreen(),
        zones: (_) => const GeofencingScreen(),
        collar: (_) => const CollarScreen(),
        health: (_) => const HealthScreen(),
        poster: (_) => const PosterScreen(),
        tech: (_) => const TechPanelScreen(),
      };

  /// A dónde ir después de la bienvenida o del inicio de sesión.
  static String nextFor(AppController c) {
    if (!c.onboarded) return onboarding;
    if (c.user == null) return login;
    if (c.needsSetup) return setup;
    return home;
  }
