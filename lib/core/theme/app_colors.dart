import 'package:flutter/material.dart';

/// StudyHub brand palette — light/paper mode from the official brand kit
/// (Studyhub-Brand-Guidelines.pdf / Studyhub-Colors.txt). Restrained on
/// purpose: Flame is the one identity color everything else defers to,
/// Ink carries the text, and the status colors (success/warning/error/
/// info) use the brand's own muted "text on light background" variants
/// of its three track colors rather than their full vivid swatches, so
/// the UI doesn't read as a rainbow of competing accents.
class AppColors {
  AppColors._();

  static const background = Color(0xFFFFF8F0); // Paper
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF6EDE1); // Sunken
  static const border = Color(0xFFE7DDCF); // Line

  static const accent = Color(0xFFFF5A26); // Flame
  static const accentSoft = Color(0xFFFFDFD0);

  static const textPrimary = Color(0xFF1A1340); // Ink
  static const textMuted = Color(0xFF5E5878); // Muted

  static const success = Color(0xFF00734F); // Mint, text-on-light variant
  static const warning = Color(0xFF8A5A00); // Sun, text-on-light variant
  static const error = Color(0xFFC21F3A); // Danger
  static const info = Color(0xFF2A3BD6); // Cobalt, text-on-light variant
}
