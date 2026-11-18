import 'package:material_ui/material_ui.dart';

/// Handoff's design tokens.
///
/// One accent (electric violet), one near-black canvas, and a small set of
/// elevated surfaces. Everything in the app draws from these so the whole UI
/// reads as one product instead of a pile of default Material widgets.
class AppColors {
  const AppColors._();

  // Dark (default)
  static const canvas = Color(0xFF101113);
  static const surface = Color(0xFF191A1D);
  static const surfaceHigh = Color(0xFF202226);
  static const surfaceHigher = Color(0xFF292B2F);
  static const border = Color(0xFF35373B);
  static const borderSoft = Color(0xFF292B2E);

  static const textPrimary = Color(0xFFEBECF0);
  static const textSecondary = Color(0xFFA4A5AE);
  static const textTertiary = Color(0xFF777982);

  // Light
  static const lightCanvas = Color(0xFFF7F8F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF0F2F0);
  static const lightBorder = Color(0xFFE0E4E0);
  static const lightTextPrimary = Color(0xFF14161B);
  static const lightTextSecondary = Color(0xFF5B6270);

  // Accent, shared by both
  static const accent = Color(0xFF4D9C59);
  static const accentBright = Color(0xFF76C982);
  static const accentDeep = Color(0xFF347C40);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);

  static const accentGradient = LinearGradient(
    colors: [accent, accentBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadius {
  const AppRadius._();
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double capsule = 28;
  static const double pill = 999;
}

/// Spacing scale, used for every gap so the rhythm is consistent.
class AppSpacing {
  const AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Elevation is expressed as a soft shadow rather than a Material elevation,
/// so surfaces read as one calm stack instead of a pile of grey cards.
class AppShadows {
  const AppShadows._();
  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> lifted = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.16),
      blurRadius: 26,
      offset: const Offset(0, 10),
    ),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF203626),
      onPrimaryContainer: Color(0xFFDDF4E1),
      secondary: AppColors.accentBright,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.danger,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSoft,
    );
    return _base(scheme, AppColors.canvas, AppColors.textPrimary);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.accentDeep,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE3F2E5),
      onPrimaryContainer: Color(0xFF17351D),
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceHigh,
      onSurfaceVariant: AppColors.lightTextSecondary,
      error: Color(0xFFDC2626),
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
    );
    return _base(scheme, AppColors.lightCanvas, AppColors.lightTextPrimary);
  }

  static ThemeData _base(ColorScheme scheme, Color canvas, Color text) {
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark ? AppColors.border : AppColors.lightBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: _textTheme(text),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceHigh,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.surfaceHigher
            : const Color(0xFF1F2430),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }

  static TextTheme _textTheme(Color text) {
    final secondary = TextStyle(color: text.withValues(alpha: 0.62));
    return TextTheme(
      headlineMedium: TextStyle(
        color: text,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: text, fontSize: 15.5, height: 1.45),
      bodyMedium: TextStyle(color: text, fontSize: 14.5, height: 1.45),
      bodySmall: secondary.copyWith(fontSize: 12.5, height: 1.35),
      labelLarge: TextStyle(
        color: text,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: text.withValues(alpha: 0.55),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}
