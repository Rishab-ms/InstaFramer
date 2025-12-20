import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// App theme configuration using FlexColorScheme for Material 3 design.
/// Provides beautiful, consistent light and dark themes with a warm amber/sunset palette.
/// 
/// Color scheme inspired by natural sunset tones - warm oranges, golden ambers,
/// and soft peachy hues that create a welcoming, Instagram-ready aesthetic.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Warm sunset-inspired color palette
  // These colors are extracted from the aesthetic of golden hour photography
  static const Color _sunsetAmber = Color(0xFFF59E0B); // Primary - warm amber/orange
  static const Color _goldenHour = Color(0xFFD97706); // Deeper sunset orange
  static const Color _peachy = Color(0xFFFB923C); // Soft peach accent
  // static const Color _warmTaupe = Color(0xFF92400E); // Earthy brown - reserved for future use

  /// Light theme configuration with warm amber sunset tones
  /// Uses Google Sans font family for a modern, clean aesthetic
  static ThemeData light() {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: _sunsetAmber,
        primaryContainer: Color(0xFFFFEDD5), // Light peachy cream
        secondary: _goldenHour,
        secondaryContainer: Color(0xFFFED7AA), // Soft golden beige
        tertiary: _peachy,
        tertiaryContainer: Color(0xFFFFEDC3), // Warm cream
        appBarColor: _sunsetAmber,
        error: Color(0xFFDC2626), // Keep error red readable
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        
        // Button themes with slightly larger radius for modern feel
        elevatedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 12.0,
        
        // Card and container themes
        cardRadius: 16.0,
        chipRadius: 12.0,
        dialogRadius: 20.0,
        
        // Input decoration
        inputDecoratorRadius: 12.0,
        inputDecoratorUnfocusedBorderIsColored: false,
        
        // AppBar
        appBarScrolledUnderElevation: 4.0,
        
        // Navigation bar
        navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        navigationBarHeight: 70,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: 'GoogleSans',
    );
  }

  /// Dark theme configuration with warm amber tones for night use
  /// Maintains the warm aesthetic while being easy on the eyes in low light
  /// Uses Google Sans font family for a modern, clean aesthetic
  static ThemeData dark() {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: Color(0xFFFFBF66), // Lighter warm amber for dark mode
        primaryContainer: Color(0xFF92400E), // Deep warm brown
        secondary: Color(0xFFFFD699), // Soft golden glow
        secondaryContainer: Color(0xFF7C2D12), // Deep burnt orange
        tertiary: Color(0xFFFFCC99), // Warm peachy glow
        tertiaryContainer: Color(0xFF9A3412), // Rich terracotta
        appBarColor: Color(0xFFFFBF66),
        error: Color(0xFFFFB4AB), // Softer red for dark mode
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        
        // Button themes
        elevatedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 12.0,
        
        // Card and container themes
        cardRadius: 16.0,
        chipRadius: 12.0,
        dialogRadius: 20.0,
        
        // Input decoration
        inputDecoratorRadius: 12.0,
        inputDecoratorUnfocusedBorderIsColored: false,
        
        // AppBar
        appBarScrolledUnderElevation: 4.0,
        
        // Navigation bar
        navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        navigationBarHeight: 70,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      // Add light color references to fix FlexColorScheme warnings
      // These allow proper "fixed" color generation in dark mode
      primary: const Color(0xFFFFBF66),
      primaryLightRef: _sunsetAmber, // Reference to light mode primary
      secondary: const Color(0xFFFFD699),
      secondaryLightRef: _goldenHour, // Reference to light mode secondary
      tertiary: const Color(0xFFFFCC99),
      tertiaryLightRef: _peachy, // Reference to light mode tertiary
      fontFamily: 'GoogleSans',
    );
  }

  /// Common text styles used across the app
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Common sizes and spacing constants
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  /// Minimum touch target size for accessibility
  static const double minTouchTarget = 48.0;

  /// Border radius constants
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  /// Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  /// Elevation constants
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
}

