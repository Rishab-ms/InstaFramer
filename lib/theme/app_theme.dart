import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// App theme configuration using FlexColorScheme for Material 3 design.
/// Provides beautiful, consistent light and dark themes.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Light theme configuration
  static ThemeData light() {
    return FlexThemeData.light(
      scheme: FlexScheme.materialBaseline,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
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
      
      // Custom colors for better contrast
      primary: const Color(0xFF6750A4),
      secondary: const Color(0xFF625B71),
      tertiary: const Color(0xFF7D5260),
    );
  }

  /// Dark theme configuration
  static ThemeData dark() {
    return FlexThemeData.dark(
      scheme: FlexScheme.materialBaseline,
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
      
      // Custom colors for better contrast in dark mode
      primary: const Color(0xFFD0BCFF),
      secondary: const Color(0xFFCCC2DC),
      tertiary: const Color(0xFFEFB8C8),
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

