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

/// Configuración guiada de la primera mascota:
/// mascota -> zona segura -> contactos -> collar.
/// También se usa para agregar más mascotas (con [addingAnother]).
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

  // Paso 1: mascota
  final _name = TextEditingController(), _breed = TextEditingController();
  final _age = TextEditingController(text: '1'), _weight = TextEditingController();
  String? _species;
  Color _color = PetPalette.defaultColor;
  Uint8List? _photo;
  // Paso 2: zona
  LatLng _home = const LatLng(AppConstants.homeLatitude, AppConstants.homeLongitude);
  double _radius = 100;
  final _zoneName = TextEditingController();
  final _map = MapController();
  LatLng? _owner;
  double? _ownerAcc;
  // Paso 3: contactos
  final List<EmergencyContact> _contacts = [];
  // Paso 4: collar
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
