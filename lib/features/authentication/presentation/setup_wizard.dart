import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/util/ids.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/pet_palette.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/locate_me.dart';
import '../../../shared/widgets/pet_map.dart';
import '../../../shared/widgets/widgets.dart';
import '../../contacts/domain/emergency_contact.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../geofencing/domain/safe_zone.dart';
import '../../pets/domain/pet.dart';
import '../../tracking/presentation/app_controller.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key, this.addingAnother = false});
  final bool addingAnother;
  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  final _page = PageController();
  int _step = 0;
  static const _steps = 4;

  final _name = TextEditingController(), _breed = TextEditingController();
  final _age = TextEditingController(text: '1'), _weight = TextEditingController();
  String? _species;
  Color _color = PetPalette.defaultColor;
  Uint8List? _photo;
  LatLng _home = const LatLng(AppConstants.homeLatitude, AppConstants.homeLongitude);
  double _radius = 100;
  final _zoneName = TextEditingController();
  final _map = MapController();
  LatLng? _owner;
  double? _ownerAcc;
  final List<EmergencyContact> _contacts = [];
  final _collar = TextEditingController();
  late final String _petId = newId();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    _species ??= l.dog;
    if (_zoneName.text.isEmpty) _zoneName.text = l.t('Casa', 'Home');
    if (widget.addingAnother) {
      _color = PetPalette.all[c.pets.length % PetPalette.all.length];
      final z = c.zone;
      if (z != null) _home = LatLng(z.latitude, z.longitude);
    }
  }

  bool get _canContinue => _step != 0 || _name.text.trim().isNotEmpty;

  void _next() {
    if (!_canContinue) return;
    if (_step == _steps - 1) {
      _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step++);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() => _step--);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final c = AppScope.of(context);
    final code = _collar.text.trim().isEmpty
        ? 'TRK-${DateTime.now().millisecondsSinceEpoch % 100000}'
        : _collar.text.trim().toUpperCase();
    final pet = Pet(
      id: _petId,
      name: _name.text.trim(),
      species: _species ?? '',
      breed: _breed.text.trim(),
      age: int.tryParse(_age.text) ?? 1,
      weight: double.tryParse(_weight.text.replaceAll(',', '.')) ?? 5,
      trackerId: code,
      colorValue: _color.toARGB32(),
      photo: _photo,
      dailyGoalMeters: Pet.suggestedGoal(_species ?? ''),
    );
    await c.addPet(pet,
        homeZone: SafeZone(
          id: newId(), petId: _petId, name: _zoneName.text.trim().isEmpty ? 'Casa' : _zoneName.text.trim(),
          latitude: _home.latitude, longitude: _home.longitude, radius: _radius, isEnabled: true,
        ));
    for (final ct in _contacts) {
      await c.addContact(ct);
    }
    if (!mounted) return;
    if (widget.addingAnother) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _breed.dispose();
    _age.dispose();
    _weight.dispose();
    _zoneName.dispose();
    _map.dispose();
    _collar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final titles = [
      l.t('Tu mascota', 'Your pet'),
      l.t('Su zona segura', 'Their safe zone'),
      l.t('Contactos de emergencia', 'Emergency contacts'),
      l.t('Su collar GPS', 'Their GPS collar'),
    ];
    return Theme(
      data: Theme.of(context).brightness == Brightness.dark ? AppTheme.dark(_color) : AppTheme.light(_color),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l.t('Atrás', 'Back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _step == 0 && !widget.addingAnother ? null : _back,
            ),
            title: Text(l.t('Paso ${_step + 1} de $_steps', 'Step ${_step + 1} of $_steps')),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (_step + 1) / _steps),
                  duration: const Duration(milliseconds: 350),
                  builder: (_, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: v, minHeight: 6, backgroundColor: context.colors.line, color: _color),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                    alignment: Alignment.centerLeft, child: Text(titles[_step], style: context.text.headlineMedium)),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_petStep(l), _zoneStep(l, c.metric), _contactsStep(l), _collarStep(l)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canContinue ? _next : null,
                    child: Text(_step == _steps - 1
                        ? l.t('Listo, empezar a cuidar a ${_name.text.trim()}', 'Done, start caring for ${_name.text.trim()}')
                        : (_step == 2 && _contacts.isEmpty)
                            ? l.t('Agregar después', 'Add later')
                            : l.t('Siguiente', 'Next')),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _petStep(AppL10n l) {
    final draft = Pet(
        id: 'draft', name: _name.text, species: _species ?? '', breed: '', age: 1, weight: 1, trackerId: '',
        colorValue: _color.toARGB32(), photo: _photo);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(
        child: Semantics(
          button: true,
          label: l.addPhoto,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final b = await pickPetPhoto();
              if (b != null) setState(() => _photo = b);
            },
            child: Stack(clipBehavior: Clip.none, children: [
              PetAvatar(pet: draft, size: 120, hero: false),
              Positioned(
                right: 22,
                bottom: 22,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: _color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ),
      Center(child: Text(_photo == null ? l.addPhoto : l.changePhoto, style: context.text.bodySmall)),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l.t('¿Cómo se llama?', "What's their name?")),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 8, children: [
        for (final s in [l.dog, l.cat, l.otherSpecies])
          ChoiceChip(label: Text(s), selected: _species == s, onSelected: (_) => setState(() => _species = s)),
      ]),
      const SizedBox(height: 14),
      TextField(controller: _breed, decoration: InputDecoration(labelText: l.petBreed)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _age, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.petAge))),
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.petWeight))),
      ]),
      const SizedBox(height: 18),
      Text(l.petColor, style: context.text.titleMedium),
      const SizedBox(height: 10),
      PetColorPicker(selected: _color, es: l.isEs, onChanged: (v) => setState(() => _color = v)),
    ]);
  }

  Widget _zoneStep(AppL10n l, bool metric) => ListView(padding: const EdgeInsets.all(20), children: [
        UseMyLocationCard(
          autoStart: !widget.addingAnother,
          onLocated: (p, acc) {
            setState(() {
              _home = p;
              _owner = p;
              _ownerAcc = acc;
            });
            _map.move(p, zoomFor(_radius * 2.5));
          },
        ),
        const SizedBox(height: 12),
        Text(
            l.t('El círculo es la zona segura de ${_name.text.trim()}. Si sale de ahí, te avisaremos. Toca el mapa para moverlo.',
                "The circle is ${_name.text.trim()}'s safe zone. If they leave it, we will alert you. Tap the map to move it."),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 300,
            child: PetMap(
              controller: _map,
              center: _home,
              zoom: zoomFor(_radius * 2.5),
              owner: _owner,
              ownerAccuracy: _ownerAcc,
              zones: [
                SafeZone(
                    id: 'draft', name: _zoneName.text, latitude: _home.latitude, longitude: _home.longitude,
                    radius: _radius, isEnabled: true)
              ],
              onTap: (p) => setState(() => _home = p),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(l.radiusLabel(Fmt.distance(_radius, metric)), style: context.text.titleMedium),
        Slider(value: _radius, min: 30, max: 1000, onChanged: (v) => setState(() => _radius = v)),
        TextField(controller: _zoneName, decoration: InputDecoration(labelText: l.zoneName)),
      ]);

  Widget _contactsStep(AppL10n l) => ListView(padding: const EdgeInsets.all(20), children: [
        Text(
            l.t('Si ${_name.text.trim()} se pierde, la IA les escribirá a estas personas por WhatsApp para pedir ayuda.',
                'If ${_name.text.trim()} gets lost, the AI will message these people on WhatsApp asking for help.'),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 16),
        for (final ct in _contacts)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: _color.withValues(alpha: 0.15),
                child: Text(ct.fullName.characters.first.toUpperCase(),
                    style: TextStyle(color: _color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('${ct.fullName}\n${ct.phone}')),
              IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _contacts.remove(ct)),
              ),
            ]),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_add_rounded),
          label: Text(l.addContact),
          onPressed: () async {
            final ct = await showContactForm(context, petId: _petId);
            if (ct != null) setState(() => _contacts.add(ct));
          },
        ),
      ]);

  Widget _collarStep(AppL10n l) => ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(Icons.sensors_rounded, size: 56, color: _color),
          ),
        ),
        const SizedBox(height: 20),
        Text(
            l.t('Escribe el código que viene en el collar (por ejemplo TRK-1001). Si todavía no lo tienes, '
                'déjalo vacío: usaremos un collar de prueba y podrás cambiarlo después en "Mi collar".',
                "Type the code printed on the collar (e.g. TRK-1001). If you don't have it yet, leave it empty: "
                    'we will use a test collar and you can change it later in "My collar".'),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _collar,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
              labelText: l.t('Código del collar (opcional)', 'Collar code (optional)'),
              prefixIcon: const Icon(Icons.qr_code_rounded)),
        ),
      ]);
}
