import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// The meaning a coloured element carries, so screens never pick raw colours.
enum Tone { neutral, brand, success, warning, danger, info }

class ToneColors {
  const ToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Colours Material's scheme has no slot for.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.page,
    required this.line,
    required this.muted,
    required this.tones,
    required this.heroStart,
    required this.heroEnd,
    required this.skeleton,
  });

  final Color page;
  final Color line;
  final Color muted;
  final Map<Tone, ToneColors> tones;
  final Color heroStart;
  final Color heroEnd;
  final Color skeleton;

  ToneColors tone(Tone tone) => tones[tone]!;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

abstract final class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  /// Plus Jakarta Sans has no Devanagari, so Nepali falls through to this.
  static const fontFallback = ['NotoSansDevanagari'];

  /// Spacing scale. Screens use these instead of arbitrary numbers.
  static const gapXs = 4.0;
  static const gapSm = 8.0;
  static const gapMd = 12.0;
  static const gapLg = 16.0;
  static const gapXl = 24.0;
  static const gapXxl = 32.0;

  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;

  /// The main call-to-action colour, taken from marigold garlands.
  static const marigold = Color(0xFFFFB81C);
  static const onMarigold = Color(0xFF3A2400);

  /// Laid over a photo so white text stays readable at 4.5:1 or better.
  static const heroTint = Color(0xD91257C4);

  static const _lightPalette = AppPalette(
    page: Color(0xFFF6F9FE),
    line: Color(0xFFDFE6F0),
    muted: Color(0xFF4F5D73),
    heroStart: Color(0xFF1B6FE0),
    heroEnd: Color(0xFF1257C4),
    skeleton: Color(0xFFE6ECF5),
    tones: {
      Tone.neutral: ToneColors(Color(0xFFEEF2F8), Color(0xFF3D4A5E)),
      Tone.brand: ToneColors(Color(0xFFDCEBFF), Color(0xFF0E4AA6)),
      Tone.success: ToneColors(Color(0xFFDDF5E7), Color(0xFF0B6B3A)),
      Tone.warning: ToneColors(Color(0xFFFFF0CC), Color(0xFF7A4A00)),
      Tone.danger: ToneColors(Color(0xFFFDE3E6), Color(0xFFA8122E)),
      Tone.info: ToneColors(Color(0xFFE6F3FB), Color(0xFF0B5A8A)),
    },
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1565D8),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCEBFF),
    onPrimaryContainer: Color(0xFF0E4AA6),
    secondary: Color(0xFFC8102E),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFF0CC),
    onSecondaryContainer: Color(0xFF5A3600),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF12203A),
    onSurfaceVariant: Color(0xFF4F5D73),
    outline: Color(0xFFC3CEDD),
    outlineVariant: Color(0xFFDFE6F0),
  );

  static ThemeData light() => _build(_lightScheme, _lightPalette);

  static TextTheme _text(Color color) {
    TextStyle style(double size, FontWeight weight, double height) => TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      // Tight spacing suits Latin letters, but crowds Devanagari.
      letterSpacing: size >= 20 && appLanguage == AppLanguage.english
          ? -0.3
          : 0,
    );
    return TextTheme(
      displaySmall: style(34, FontWeight.w800, 1.15),
      headlineLarge: style(30, FontWeight.w800, 1.2),
      headlineMedium: style(26, FontWeight.w800, 1.2),
      headlineSmall: style(22, FontWeight.w700, 1.25),
      titleLarge: style(19, FontWeight.w700, 1.3),
      titleMedium: style(16, FontWeight.w700, 1.35),
      titleSmall: style(14, FontWeight.w600, 1.35),
      bodyLarge: style(16, FontWeight.w400, 1.5),
      bodyMedium: style(14, FontWeight.w400, 1.5),
      bodySmall: style(12.5, FontWeight.w400, 1.45),
      labelLarge: style(15, FontWeight.w700, 1.2),
      labelMedium: style(12.5, FontWeight.w600, 1.3),
      labelSmall: style(11, FontWeight.w600, 1.3),
    );
  }

  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final text = _text(scheme.onSurface);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );
    const buttonSize = Size(double.infinity, 54);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      textTheme: text,
      scaffoldBackgroundColor: palette.page,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        foregroundColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: shape,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: gapLg,
          vertical: gapLg,
        ),
        border: border(palette.line),
        enabledBorder: border(palette.line),
        focusedBorder: border(scheme.primary, 1.6),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.6),
        hintStyle: text.bodyLarge!.copyWith(color: palette.muted),
        labelStyle: text.bodyMedium!.copyWith(color: palette.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : palette.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.line, space: 1),
      sliderTheme: SliderThemeData(
        inactiveTrackColor: palette.line,
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
