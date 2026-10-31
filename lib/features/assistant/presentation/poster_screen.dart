import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../profile/presentation/settings_screen.dart' show editOwnerPhone;
import '../../tracking/presentation/app_controller.dart';

/// Cartel de "Se busca" hecho con la foto y un texto escrito por la IA.
/// Se puede compartir como imagen (redes, WhatsApp) o descargar.
class PosterScreen extends StatefulWidget {
  const PosterScreen({super.key});
  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final _key = GlobalKey();
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    final e = c.emergency;
    if (e != null && e.poster == null && !e.posterLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => c.requestPoster());
    }
  }

  Future<void> _share(AppL10n l, String text) async {
    setState(() => _sharing = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'se-busca.png')],
        fileNameOverrides: ['se-busca.png'],
        text: text,
        title: l.t('Se busca', 'Missing'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('No se pudo compartir la imagen', 'Could not share the image'))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    final e = c.emergency, pet = c.selectedPet;
    if (e == null || pet == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.image_outlined, text: l.t('No hay una búsqueda activa.', 'No active search.')));
    }
    final poster = e.poster;
    final phone = c.ownerPhone.isNotEmpty ? c.ownerPhone : (c.contacts.isNotEmpty ? c.contacts.first.phone : '');
    final shareText = poster == null
        ? ''
        : '${poster.headline}\n\n${poster.description}\n\n📍 ${e.report.mapsLink}${phone.isEmpty ? '' : '\n📞 $phone'}';

    return Scaffold(
      appBar: AppBar(title: Text(l.t('Cartel "Se busca"', '"Missing" poster'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: RepaintBoundary(
              key: _key,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: poster == null
                    ? AspectRatio(
                        key: const ValueKey('loading'),
                        aspectRatio: 0.75,
                        child: Container(
                          decoration: BoxDecoration(color: pet.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Text(l.t('La IA está escribiendo el cartel...', 'The AI is writing the poster...')),
                          ]),
                        ),
                      )
                    : _Poster(
                        key: const ValueKey('poster'),
                        es: l.isEs,
                        petColor: pet.color,
                        photo: PetPhoto(pet: pet, size: 400),
                        name: pet.name,
                        headline: poster.headline,
                        description: poster.description,
