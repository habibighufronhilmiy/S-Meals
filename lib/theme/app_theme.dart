import 'package:flutter/material.dart';

/// Design system "Nutritious Vitality" (tema Sona Sehat).
/// Diambil dari palet Stitch: emerald primer, amber sekunder, permukaan
/// putih bersih, radius 8-12, font Plus Jakarta Sans.
class SonaColors {
  static const primary = Color(0xFF006C49);
  static const primaryContainer = Color(0xFF10B981);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF00422B);
  static const secondary = Color(0xFF855300);
  static const secondaryContainer = Color(0xFFFEA619);
  static const onSecondaryContainer = Color(0xFF684000);
  static const tertiary = Color(0xFF006C4E);
  static const surface = Color(0xFFF8F9FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceContainerHigh = Color(0xFFDEE9FC);
  static const surfaceVariant = Color(0xFFD9E3F6);
  static const onSurface = Color(0xFF121C2A);
  static const onSurfaceVariant = Color(0xFF3C4A42);
  static const outline = Color(0xFF6C7A71);
  static const outlineVariant = Color(0xFFBBCABF);
  static const error = Color(0xFFBA1A1A);

  static const emeraldTint = Color(0xFFD6F5E6);
  static const amberTint = Color(0xFFFFF1D6);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFFFB95F);
  static const amberDeep = Color(0xFF855300);
  static const coral = Color(0xFFF0776B);
  static const pink = Color(0xFFE86A9B);
  static const tertiaryContainerLite = Color(0xFF97F5CC);
  static const onTertiaryContainer = Color(0xFF00422E);

  static const skyTint = Color(0xFFD6EBFF);
  static const skyDeep = Color(0xFF2C6FA8);
}

/// Warna khusus mode gelap (permukaan gelap, emerald tetap jadi aksen).
class SonaColorsDark {
  static const surface = Color(0xFF0F1512);
  static const surfaceContainerLowest = Color(0xFF151B18);
  static const surfaceContainerLow = Color(0xFF1A231F);
  static const surfaceContainer = Color(0xFF1F2824);
  static const surfaceContainerHigh = Color(0xFF252E29);
  static const surfaceVariant = Color(0xFF2F3A34);
  static const onSurface = Color(0xFFEDEDEB);
  static const onSurfaceVariant = Color(0xFFB9B9B6);
  static const outline = Color(0xFF6B706C);
  static const outlineVariant = Color(0xFF3A413C);
  static const primary = Color(0xFF22C55E);
  static const onPrimary = Color(0xFF022C22);
  static const primaryContainer = Color(0xFF14532D);
  static const onPrimaryContainer = Color(0xFFB9F3CC);
}

class SonaRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const full = 999.0;
}

class SonaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const margin = 16.0;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SonaColors.surface,
      colorScheme: const ColorScheme.light(
        primary: SonaColors.primary,
        onPrimary: SonaColors.onPrimary,
        primaryContainer: SonaColors.primaryContainer,
        onPrimaryContainer: SonaColors.onPrimaryContainer,
        secondary: SonaColors.secondary,
        secondaryContainer: SonaColors.secondaryContainer,
        onSecondaryContainer: SonaColors.onSecondaryContainer,
        tertiary: SonaColors.tertiary,
        surface: SonaColors.surface,
        onSurface: SonaColors.onSurface,
        onSurfaceVariant: SonaColors.onSurfaceVariant,
        outline: SonaColors.outline,
        outlineVariant: SonaColors.outlineVariant,
        error: SonaColors.error,
      ),
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 36,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: SonaColors.onSurface,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: SonaColors.onSurface,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: SonaColors.onSurface,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: SonaColors.onSurface,
      ),
      titleSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SonaColors.onSurface,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        height: 1.45,
        color: SonaColors.onSurface,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        height: 1.4,
        color: SonaColors.onSurfaceVariant,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: SonaColors.onSurfaceVariant,
      ),
    );

    return base.copyWith(
      textTheme: text,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SonaColors.primary,
          foregroundColor: SonaColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SonaRadius.full),
          ),
          textStyle:
              const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SonaColorsDark.surface,
      colorScheme: const ColorScheme.dark(
        primary: SonaColorsDark.primary,
        onPrimary: SonaColorsDark.onPrimary,
        primaryContainer: SonaColorsDark.primaryContainer,
        onPrimaryContainer: SonaColorsDark.onPrimaryContainer,
        secondary: Color(0xFF9CA3AF),
        secondaryContainer: Color(0xFF1F2937),
        onSecondaryContainer: Color(0xFFE5E7EB),
        tertiary: Color(0xFF6B7280),
        surface: SonaColorsDark.surface,
        onSurface: SonaColorsDark.onSurface,
        onSurfaceVariant: SonaColorsDark.onSurfaceVariant,
        surfaceContainerLowest: SonaColorsDark.surfaceContainerLowest,
        surfaceContainerLow: SonaColorsDark.surfaceContainerLow,
        surfaceContainer: SonaColorsDark.surfaceContainer,
        surfaceContainerHigh: SonaColorsDark.surfaceContainerHigh,
        outline: SonaColorsDark.outline,
        outlineVariant: SonaColorsDark.outlineVariant,
        error: Color(0xFFDC2626),
      ),
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 36,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: SonaColorsDark.onSurface,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: SonaColorsDark.onSurface,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: SonaColorsDark.onSurface,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: SonaColorsDark.onSurface,
      ),
      titleSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SonaColorsDark.onSurface,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        height: 1.7,
        color: SonaColorsDark.onSurface,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 13,
        height: 1.8,
        color: SonaColorsDark.onSurface,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: SonaColorsDark.onSurface,
      ),
    );

    return base.copyWith(
      textTheme: text,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: const Color(0xFF022C22),
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SonaRadius.full),
          ),
          textStyle:
              const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: const Color(0xFF022C22),
          textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SonaColorsDark.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonaRadius.md),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: SonaColorsDark.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
    );
  }
}
