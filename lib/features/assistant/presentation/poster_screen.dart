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
                        lastSeen: '${e.report.zoneName}, ${Fmt.time(e.report.time).substring(0, 5)}',
                        phone: phone,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (phone.isEmpty)
          AppCard(
            color: AppTheme.warning.withValues(alpha: 0.12),
            onTap: () => editOwnerPhone(context),
            child: Text(l.t('Toca aquí para agregar tu celular y que aparezca en el cartel.',
                'Tap here to add your phone number so it shows on the poster.')),
          ),
        FilledButton.icon(
          onPressed: poster == null || _sharing ? null : () => _share(l, shareText),
          icon: _sharing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share_rounded),
          label: Text(l.t('Compartir cartel', 'Share poster')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: e.posterLoading ? null : c.requestPoster,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(l.t('Escribir otro texto con IA', 'Write another text with AI')),
        ),
      ]),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    super.key,
    required this.es,
    required this.petColor,
    required this.photo,
    required this.name,
    required this.headline,
    required this.description,
    required this.lastSeen,
    required this.phone,
  });
  final bool es;
  final Color petColor;
  final Widget photo;
  final String name, headline, description, lastSeen, phone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // El cartel siempre es claro (para imprimir o compartir).
    const ink = Color(0xFF1F2B29);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppTheme.danger,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(es ? 'SE BUSCA' : 'MISSING',
              textAlign: TextAlign.center,
              style: t.displaySmall?.copyWith(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.w700)),
        ),
        AspectRatio(aspectRatio: 1.15, child: photo),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: t.displayMedium?.copyWith(color: petColor, height: 1)),
            const SizedBox(height: 6),
            Text(headline, style: t.titleLarge?.copyWith(color: ink)),
            const SizedBox(height: 8),
            Text(description, style: t.bodyMedium?.copyWith(color: ink)),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.place_rounded, color: petColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${es ? 'Visto por última vez' : 'Last seen'}: $lastSeen',
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: petColor, borderRadius: BorderRadius.circular(14)),
                child: Text('📞 $phone',
                    textAlign: TextAlign.center,
                    style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
