import 'package:flutter/material.dart';

/// ByaHero brand system: P2P-red + midnight, warm paper bg, malalaking
/// rounded na button — iisang bisang gagamitin ng LAHAT ng screens.
/// Kahit anong button ang nasa screen (Filled/Outlined/Text/Elevated),
/// pareho ang hugis, lapad, at kulay.
class AppTheme {
  // Brand palette
  static const brandRed = Color(0xFFD62828);
  static const brandRedDark = Color(0xFFA31E1E);
  static const midnight = Color(0xFF14181F);
  static const warmBg = Color(0xFFF6F1EA);
  static const cardBg = Colors.white;
  static const line = Color(0xFFE7DFD3);
  static const ink = Color(0xFF1B1F26);
  static const muted = Color(0xFF6B7280);
  static const gold = Color(0xFFF9C80E);
  static const success = Color(0xFF2BA84A);

  // Base geometry — iisa para pantay-pantay
  static const radius = 16.0;
  static const radiusLg = 24.0;
  static const gap = 14.0;

  static ColorScheme _scheme() {
    // fromSeed + copyWith: hindi na kailangang i-spec ang lahat ng field,
    // kaya safe ito sa anumang bersyon ng Flutter.
    return ColorScheme.fromSeed(
      seedColor: brandRed,
      brightness: Brightness.light,
    ).copyWith(
      primary: brandRed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE5E5),
      onPrimaryContainer: brandRedDark,
      secondary: midnight,
      onSecondary: Colors.white,
      tertiary: success,
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: warmBg,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
    );
  }

  static ThemeData light() {
    final scheme = _scheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: warmBg,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: midnight,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: .3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: cardBg,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
          side: BorderSide(color: line),
        ),
      ),
      // Lahat ng button: pareho ang hugis at lapad
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: brandRed.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandRed,
          side: const BorderSide(color: brandRed, width: 1.4),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandRed,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: brandRed,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: brandRed, width: 1.8),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: Color(0xFFB3261E), width: 1.8),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? brandRed : Colors.white),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : ink),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
          textStyle: WidgetStatePropertyAll(const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandRed,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        side: const BorderSide(color: line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 68,
        indicatorColor: brandRed.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
            color: sel ? brandRed : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
              color: sel ? brandRed : muted, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: midnight,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius)),
      ),
      dividerTheme: const DividerThemeData(
          color: line, thickness: 1, space: 1),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: brandRed),
      listTileTheme: const ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
