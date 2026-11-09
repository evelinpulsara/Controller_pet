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
      field: Color.lerp(field, other.field, t)!,
      mapTint: Color.lerp(mapTint, other.mapTint, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  Color get accent => Theme.of(this).colorScheme.primary;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Diseño de la app: base minimalista (blanco con un toque salvia, o verde
/// muy oscuro en modo oscuro) y un acento que cambia según la mascota.
class AppTheme {
  // Estados (iguales en claro y oscuro)
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFE69A12);
  static const ok = Color(0xFF2FB592);
  static const whatsapp = Color(0xFF25D366);

  static TextTheme _text(Color ink, Color muted) {
    final base = Typography.material2021().black;
    TextStyle? n(TextStyle? s) => GoogleFonts.nunito(textStyle: s, color: ink);
    final body = TextTheme(
      displayLarge: n(base.displayLarge), displayMedium: n(base.displayMedium),
      displaySmall: n(base.displaySmall), headlineLarge: n(base.headlineLarge),
      headlineMedium: n(base.headlineMedium), headlineSmall: n(base.headlineSmall),
      titleLarge: n(base.titleLarge), titleMedium: n(base.titleMedium), titleSmall: n(base.titleSmall),
      bodyLarge: n(base.bodyLarge), bodyMedium: n(base.bodyMedium), bodySmall: n(base.bodySmall),
      labelLarge: n(base.labelLarge), labelMedium: n(base.labelMedium), labelSmall: n(base.labelSmall),
    );
    TextStyle? display(TextStyle? s, double size, FontWeight w) =>
        GoogleFonts.fredoka(textStyle: s, fontSize: size, fontWeight: w, color: ink, height: 1.15);
    return body.copyWith(
      displayMedium: display(body.displayMedium, 44, FontWeight.w600),
      displaySmall: display(body.displaySmall, 34, FontWeight.w600),
      headlineMedium: display(body.headlineMedium, 28, FontWeight.w600),
      headlineSmall: display(body.headlineSmall, 24, FontWeight.w600),
      titleLarge: display(body.titleLarge, 20, FontWeight.w500),
      titleMedium: display(body.titleMedium, 17, FontWeight.w500),
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
      bodySmall: body.bodySmall?.copyWith(fontSize: 13, color: muted),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  static ThemeData light([Color accent = PetPalette.defaultColor]) => _build(accent, AppColors.light, Brightness.light);
  static ThemeData dark([Color accent = PetPalette.defaultColor]) => _build(accent, AppColors.dark, Brightness.dark);

  static ThemeData _build(Color accent, AppColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      error: danger,
      surface: c.surface,
      onSurface: c.ink,
      outlineVariant: c.line,
    );
    final text = _text(c.ink, c.muted);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: text,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        foregroundColor: c.ink,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: c.line)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52), shape: rounded, textStyle: text.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded,
          foregroundColor: c.ink,
          side: BorderSide(color: c.line, width: 1.5),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: rounded, textStyle: text.labelLarge)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accent, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? accent : c.muted)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : c.line),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.15),
        thumbColor: accent,
        trackHeight: 6,
        tickMarkShape: SliderTickMarkShape.noTickMark,
        valueIndicatorColor: c.ink,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: accent.withValues(alpha: 0.18),
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: accent.withValues(alpha: 0.18),
          selectedForegroundColor: c.ink,
          foregroundColor: c.muted,
          side: BorderSide(color: c.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b == Brightness.light ? c.ink : c.surface,
        contentTextStyle: text.bodyMedium?.copyWith(color: b == Brightness.light ? Colors.white : c.ink),
        shape: rounded,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1),
      listTileTheme: ListTileThemeData(iconColor: c.muted),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    );
  }
}

/// true si la persona pidió reducir las animaciones en su sistema.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
 