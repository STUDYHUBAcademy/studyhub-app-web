import 'package:flutter/material.dart';

/// StudyHub brand palette — from the official brand kit's dark-mode spec
/// (Studyhub-Brand-Guidelines.pdf / Studyhub-Colors.txt): Ink/Flame/Paper
/// as the core identity, Mint/Cobalt/Sun as the three product tracks
/// (Courses/Private Lessons/Products), mapped onto this app's dark theme.
class AppColors {
  AppColors._();

  static const background = Color(0xFF110D2B); // dark mode background
  static const surface = Color(0xFF1C1740); // dark mode card
  static const surfaceVariant = Color(0xFF373357); // surface, lightened
  static const border = Color(0xFF373357);

  static const accent = Color(0xFFFF6B3D); // dark mode Flame
  static const accentSoft = Color(0xFF4E293F);

  static const textPrimary = Color(0xFFF7F1E8); // dark mode text
  static const textMuted = Color(0xFFB3ADC9); // dark mode secondary text

  static const success = Color(0xFF00B884); // Mint — Courses track
  static const warning = Color(0xFFFFC233); // Sun — Products track
  static const error = Color(0xFFC21F3A); // Danger
  static const info = Color(0xFF3349F5); // Cobalt — Private Lessons track
}
