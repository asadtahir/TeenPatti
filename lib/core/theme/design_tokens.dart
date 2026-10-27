import 'package:flutter/material.dart';

/// Central design system. All styling values live here.
abstract final class AppColors {
  static const felt = Color(0xFF0B5D3B);
  static const feltDark = Color(0xFF063B26);
  static const feltLight = Color(0xFF14804F);
  static const night = Color(0xFF0A0F14);
  static const surface = Color(0xFF131B22);
  static const surfaceHigh = Color(0xFF1C2630);
  static const gold = Color(0xFFE8B84A);
  static const goldDark = Color(0xFFB88A24);
  static const crimson = Color(0xFFD7263D);
  static const textPrimary = Color(0xFFF4F1E8);
  static const textMuted = Color(0xFF9AA7B2);
  static const success = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFB020);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 22.0;
  static const pill = 999.0;
  static const card = 10.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6)),
  ];
  static const glow = [
    BoxShadow(color: Color(0x88E8B84A), blurRadius: 22, spreadRadius: 1),
  ];
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const cardDeal = Duration(milliseconds: 450);
  static const cardFlip = Duration(milliseconds: 500);
  static const dealStagger = Duration(milliseconds: 120);
  static const pageTransition = Duration(milliseconds: 280);
}

abstract final class AppCardSize {
  /// Standard playing card aspect ratio (width / height).
  static const aspect = 0.714;
  static const baseWidth = 64.0;
  static const baseHeight = baseWidth / aspect;
}

abstract final class AppText {
  static const display = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      color: AppColors.textPrimary);
  static const title = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 16, color: AppColors.textPrimary);
  static const caption = TextStyle(fontSize: 13, color: AppColors.textMuted);
  static const button =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5);
}
