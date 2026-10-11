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
