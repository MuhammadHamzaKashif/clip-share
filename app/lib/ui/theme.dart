import 'package:flutter/material.dart';

const Color kAccent = Color(0xFF5B5FA6);
const Color kLightBackground = Color(0xFFFAFAF8);
const Color kDarkBackground = Color(0xFF121212);

final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: brightness,
  );
  final isLight = brightness == Brightness.light;
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: isLight ? kLightBackground : kDarkBackground,
    cardColor: isLight ? Colors.white : const Color(0xFF1A1A1A),
    dividerColor: scheme.outlineVariant,
  );
}
