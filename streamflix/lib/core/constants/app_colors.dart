import 'package:flutter/material.dart';

/// Netflix-inspired color palette
class AppColors {
  AppColors._(); // Private constructor - this class is not meant to be instantiated

  // Primary colors
  static const Color netflixRed = Color(0xFFE50914);
  static const Color netflixRedDark = Color(0xFFB20710);
  
  // Background colors
  static const Color background = Color(0xFF000000); // True cinematic black
  static const Color backgroundLight = Color(0xFF0D0D0D); // Ultra dark charcoal for overlays
  static const Color backgroundCard = Color(0xFF161616); // High-contrast container grey
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE0E0E0); // Slightly brighter/cleaner secondary
  static const Color textTertiary = Color(0xFF909090); // Tertiary grey
  
  // Accent colors
  static const Color success = Color(0xFF46D369);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFE50914);
  
  // Overlay colors
  static const Color overlay = Color(0x99000000); // 60% black
  static const Color overlayLight = Color(0x4D000000); // 30% black
  
  // Gradient colors
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000), // Transparent
      Color(0x80000000), // 50% black
      Color(0xFF000000), // Pure black solid background
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xCC000000), // 80% black
    ],
    stops: [0.5, 1.0],
  );
}
