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
        onboarding: (_) => const PageFrame(maxWidth: 560, child: OnboardingScreen()),
        login: (_) => const LoginScreen(),
        setup: (_) => const PageFrame(child: SetupWizard()),
        home: (_) => const HomeShell(),
        petProfile: (_) => const PageFrame(child: PetProfileScreen()),
        history: (_) => const PageFrame(child: HistoryScreen()),
        contacts: (_) => const PageFrame(child: ContactsScreen()),
        zones: (_) => const PageFrame(maxWidth: 960, child: GeofencingScreen()),
        collar: (_) => const PageFrame(child: CollarScreen()),
        health: (_) => const PageFrame(child: HealthScreen()),
        poster: (_) => const PageFrame(child: PosterScreen()),
        tech: (_) => const PageFrame(maxWidth: 960, child: TechPanelScreen()),
      };

  static String nextFor(AppController c) {
    if (!c.onboarded) return onboarding;
    if (c.user == null) return login;
    if (c.needsSetup) return setup;
    return home;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _i = widget.initialIndex;
  final Set<String> _shownEmergencies = {};
  int _seenCelebration = -1;
  bool _confetti = false;

  void _go(int i) => setState(() => _i = i);

  void _showEmergencyDialog(String petId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppScope.of(ctx);
        final l = AppL10n.fromLocale(c.locale);
        final s = c.sessions[petId];
        final e = s?.emergency;
        if (s == null || e == null) return const SizedBox();
        return AlertDialog(
          icon: PetAvatar(pet: s.pet, size: 72, live: true, alert: true, hero: false),
          title: Text(l.petLostTitle(s.pet.name), textAlign: TextAlign.center),
          content: e.isWriting
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l.aiWriting)),
                ])
              : Text(e.messages!.ownerAlert),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () {
                Navigator.pop(ctx);
                c.selectPetById(petId);
                _go(0);
              },
              child: Text(l.alertMyContacts),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);

    for (final e in c.activeEmergencies) {
      if (_shownEmergencies.add(e.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showEmergencyDialog(e.petId));
      }
    }
    if (_seenCelebration == -1) _seenCelebration = c.celebrateTick;
    if (c.celebrateTick != _seenCelebration) {
      _seenCelebration = c.celebrateTick;
      _confetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.welcomeHome(c.celebratePetName))));
      });
    }

    final unread = c.alerts.length;
    final screens = [
      DashboardScreen(onOpenTab: _go),
      const TrackingScreen(),
      const ActivityScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];
    Widget alertIcon(bool selected) => Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppTheme.danger,
        label: Text('$unread'),
        child: Icon(selected ? Icons.notifications_rounded : Icons.notifications_outlined));
    final items = <(Widget, Widget, String)>[
      (const Icon(Icons.pets_outlined), const Icon(Icons.pets_rounded), l.navHome),
      (const Icon(Icons.map_outlined), const Icon(Icons.map_rounded), l.navMap),
      (const Icon(Icons.insights_outlined), const Icon(Icons.insights_rounded), l.navActivity),
      (alertIcon(false), alertIcon(true), l.navAlerts),
      (const Icon(Icons.settings_outlined), const Icon(Icons.settings_rounded), l.navSettings),
    ];
    final body = AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(anim), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_i), child: SizedBox.expand(child: screens[_i])),
    );
    final wide = context.isWide;
    final extended = context.screenWidth >= Breakpoints.extraWide;
    return Stack(children: [
      Scaffold(
        body: wide
            ? Row(children: [
                NavigationRail(
                  selectedIndex: _i,
                  onDestinationSelected: _go,
                  extended: extended,
                  minExtendedWidth: 220,
                  backgroundColor: context.colors.surface,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  selectedLabelTextStyle:
                      context.text.titleSmall?.copyWith(color: context.accent, fontWeight: FontWeight.w700),
                  unselectedLabelTextStyle: context.text.titleSmall?.copyWith(color: context.colors.muted),
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                    child: _RailLogo(extended: extended),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in items)
                      NavigationRailDestination(icon: icon, selectedIcon: selected, label: Text(label)),
                  ],
                ),
                VerticalDivider(width: 1, thickness: 1, color: context.colors.line),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _i,
                onDestinationSelected: _go,
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationDestination(icon: icon, selectedIcon: selected, label: label),
                ],
              ),
      ),
      if (_confetti) Positioned.fill(child: Confetti(onDone: () => setState(() => _confetti = false))),
    ]);
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo({required this.extended});
  final bool extended;
  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
      child: const Icon(Icons.pets_rounded, color: Colors.white, size: 24),
    );
    if (!extended) return logo;
    return SizedBox(
      width: 196,
      child: Row(children: [
        logo,
        const SizedBox(width: 12),
        Text('PetTracker', style: context.text.titleLarge),
      ]),
    );
  }
}
