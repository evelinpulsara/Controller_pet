import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pet_palette.dart';
import '../../features/pets/domain/pet.dart';

export 'progress_ring.dart';

/// Tarjeta base: sin sombra, borde suave.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.color, this.padding, this.margin});
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? const EdgeInsets.only(bottom: 12),
        child: Material(
          color: color ?? context.colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: color == null ? BorderSide(color: context.colors.line) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding ?? const EdgeInsets.all(18), child: child),
          ),
        ),
      );
}

/// Título de una sección con acción opcional a la derecha ("Ver todo").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: context.text.titleLarge)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

/// Pastilla de estado (icono + texto) con transición al cambiar.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(label,
                  key: ValueKey(label), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
      );
}

/// Foto de la mascota con un anillo de su color.
/// Si [live] es true, el anillo "late" (GPS activo). Si [alert], late en rojo.
class PetAvatar extends StatefulWidget {
  const PetAvatar({super.key, required this.pet, this.size = 56, this.live = false, this.alert = false, this.hero = true});
  final Pet pet;
  final double size;
  final bool live, alert, hero;

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PetAvatar old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    final shouldPulse = widget.live && !reduceMotion(context);
    if (shouldPulse && !_pulse.isAnimating) _pulse.repeat();
    if (!shouldPulse && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final ringColor = widget.alert ? AppTheme.danger : widget.pet.color;
    final ring = s * 0.06;
    Widget face = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ring),
        color: context.colors.surface,
      ),
      padding: EdgeInsets.all(ring * 0.7),
      child: ClipOval(child: PetPhoto(pet: widget.pet, size: s)),
    );
    if (widget.hero) face = Hero(tag: 'pet-avatar-${widget.pet.id}', child: face);

    return SizedBox(
      width: s * 1.5,
      height: s * 1.5,
      child: Stack(alignment: Alignment.center, children: [
        if (widget.live)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: s * (1 + 0.5 * t),
                height: s * (1 + 0.5 * t),
                decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor.withValues(alpha: 0.28 * (1 - t))),
              );
            },
          ),
        face,
      ]),
    );
  }
}

/// Solo la foto (o la inicial si no tiene foto).
class PetPhoto extends StatelessWidget {
  const PetPhoto({super.key, required this.pet, required this.size});
  final Pet pet;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (pet.photo != null) {
      return Image.memory(pet.photo!, fit: BoxFit.cover, width: size, height: size, gaplessPlayback: true);
    }
    return Container(
      color: pet.color.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        pet.name.isEmpty ? '?' : pet.name.characters.first.toUpperCase(),
        style: context.text.headlineMedium?.copyWith(color: pet.color, fontSize: size * 0.4),
      ),
    );
  }
}

/// Fila de círculos de color para elegir el color de la mascota.
class PetColorPicker extends StatelessWidget {
  const PetColorPicker({super.key, required this.selected, required this.onChanged, required this.es});
  final Color selected;
  final ValueChanged<Color> onChanged;
  final bool es;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in PetPalette.all)
          Tooltip(
            message: PetPalette.name(c, es),
            child: Semantics(
              button: true,
              selected: c.toARGB32() == selected.toARGB32(),
              label: PetPalette.name(c, es),
              child: GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: context.colors.surface, width: c.toARGB32() == selected.toARGB32() ? 4 : 0),
                    boxShadow: [if (c.toARGB32() == selected.toARGB32()) BoxShadow(color: c, spreadRadius: 2)],
                  ),
                  child: c.toARGB32() == selected.toARGB32()
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            ),
          ),
      ]);
}

/// Abre la galería (o el explorador de archivos en web) para elegir una foto.
Future<Uint8List?> pickPetPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
  return file?.readAsBytes();
}

/// Pantalla vacía con un ícono grande y un texto que invita a actuar.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: context.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: context.accent),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(text,
                  textAlign: TextAlign.center, style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

/// Fila de dato: etiqueta a la izquierda, valor a la derecha.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon});
  final String label, value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 20, color: context.colors.muted), const SizedBox(width: 12)],
          Expanded(child: Text(label, style: TextStyle(color: context.colors.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/// Botón cuadrado de acceso rápido (ícono + texto), usado en Inicio.
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap, this.badge});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: context.colors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Badge(
                isLabelVisible: badge != null,
                label: Text(badge ?? ''),
                backgroundColor: AppTheme.danger,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: context.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: context.accent, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      );
}

/// Número grande con etiqueta pequeña (ej: "2.4 km" / "hoy").
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.value, required this.label, this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
      ]);
}

/// Fila de números que se reparten el ancho por igual.
class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final c in children) Expanded(child: Center(child: c)),
      ]);
}

/// Formatea una duración como "1 h 05 min" o "12 min".
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}
