import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pet_palette.dart';

/// Colores base que cambian entre modo claro y oscuro.
/// Uso: `context.colors.ink`, `context.colors.surface`...
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.field,
    required this.mapTint,
  });
  final Color background, surface, ink, muted, line, field, mapTint;

  static const light = AppColors(
    background: Color(0xFFF4F6F3),
    surface: Colors.white,
    ink: Color(0xFF1F2B29),
    muted: Color(0xFF6A7774),
    line: Color(0xFFE2E7E2),
    field: Color(0xFFE9EEE8),
    mapTint: Color(0x00000000),
  );

  static const dark = AppColors(
    background: Color(0xFF121816),
    surface: Color(0xFF1B2321),
    ink: Color(0xFFE7EEEB),
    muted: Color(0xFF93A19D),
    line: Color(0xFF2A3431),
    field: Color(0xFF242E2B),
    mapTint: Color(0x66000000),
  );

  @override
  AppColors copyWith({Color? background, Color? surface, Color? ink, Color? muted, Color? line, Color? field, Color? mapTint}) =>
      AppColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        field: field ?? this.field,
        mapTint: mapTint ?? this.mapTint,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
