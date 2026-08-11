import 'package:flutter/material.dart';

const kFontSans = 'Geist';
const kFontMono = 'GeistMono';

const kRadiusSurface = 12.0;
const kRadiusControl = 999.0;

class ClipColors {
  ClipColors._();

  static const lightBackground = Color(0xFFFAFAF9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE4E4E7);
  static const lightText = Color(0xFF18181B);
  static const lightMuted = Color(0xFF71717A);
  static const lightAccent = Color(0xFF0D9488);
  static const lightAccentHover = Color(0xFF0F766E);
  static const lightOk = Color(0xFF16A34A);
  static const lightShadow = Color(0x14181B1B);

  static const darkBackground = Color(0xFF0C0C0E);
  static const darkSurface = Color(0xFF141417);
  static const darkBorder = Color(0xFF27272A);
  static const darkText = Color(0xFFF4F4F5);
  static const darkMuted = Color(0xFFA1A1AA);
  static const darkAccent = Color(0xFF2DD4BF);
  static const darkAccentHover = Color(0xFF14B8A6);
  static const darkOk = Color(0xFF4ADE80);
  static const darkShadow = Color(0x66000000);
}

class ClipThemeColors extends ThemeExtension<ClipThemeColors> {
  const ClipThemeColors({
    required this.border,
    required this.muted,
    required this.accent,
    required this.accentHover,
    required this.ok,
    required this.dotShadow,
  });

  final Color border;
  final Color muted;
  final Color accent;
  final Color accentHover;
  final Color ok;
  final Color dotShadow;

  @override
  ClipThemeColors copyWith({
    Color? border,
    Color? muted,
    Color? accent,
    Color? accentHover,
    Color? ok,
    Color? dotShadow,
  }) {
    return ClipThemeColors(
      border: border ?? this.border,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      ok: ok ?? this.ok,
      dotShadow: dotShadow ?? this.dotShadow,
    );
  }

  @override
  ClipThemeColors lerp(ClipThemeColors? other, double t) {
    if (other == null) return this;
    return ClipThemeColors(
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      dotShadow: Color.lerp(dotShadow, other.dotShadow, t)!,
    );
  }
}

extension ClipTheme on BuildContext {
  ClipThemeColors get clip => Theme.of(this).extension<ClipThemeColors>()!;
}

final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final bg = isLight ? ClipColors.lightBackground : ClipColors.darkBackground;
  final surface = isLight ? ClipColors.lightSurface : ClipColors.darkSurface;
  final border = isLight ? ClipColors.lightBorder : ClipColors.darkBorder;
  final text = isLight ? ClipColors.lightText : ClipColors.darkText;
  final muted = isLight ? ClipColors.lightMuted : ClipColors.darkMuted;
  final accent = isLight ? ClipColors.lightAccent : ClipColors.darkAccent;
  final accentHover = isLight ? ClipColors.lightAccentHover : ClipColors.darkAccentHover;
  final ok = isLight ? ClipColors.lightOk : ClipColors.darkOk;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: isLight ? Colors.white : const Color(0xFF06201C),
    secondary: accent,
    onSecondary: isLight ? Colors.white : const Color(0xFF06201C),
    error: isLight ? const Color(0xFFDC2626) : const Color(0xFFF87171),
    onError: Colors.white,
    surface: surface,
    onSurface: text,
    surfaceContainerHighest: isLight ? const Color(0xFFF4F4F5) : const Color(0xFF1D1D21),
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border,
    shadow: isLight ? ClipColors.lightShadow : ClipColors.darkShadow,
    scrim: Colors.black,
    inverseSurface: isLight ? ClipColors.darkText : ClipColors.lightText,
    onInverseSurface: isLight ? ClipColors.darkBackground : ClipColors.lightText,
    inversePrimary: accent,
    primaryContainer: isLight ? const Color(0xFFCCFBF1) : const Color(0xFF134E4A),
    onPrimaryContainer: isLight ? const Color(0xFF042F2A) : const Color(0xFFCCFBF1),
    secondaryContainer: isLight ? const Color(0xFFF0FDFA) : const Color(0xFF134E4A),
    onSecondaryContainer: isLight ? const Color(0xFF042F2A) : const Color(0xFFCCFBF1),
    tertiary: muted,
    onTertiary: bg,
    tertiaryContainer: isLight ? const Color(0xFFF4F4F5) : const Color(0xFF1D1D21),
    onTertiaryContainer: text,
    surfaceDim: isLight ? const Color(0xFFE4E4E7) : const Color(0xFF0C0C0E),
    surfaceBright: surface,
    surfaceContainerLowest: bg,
    surfaceContainerLow: isLight ? const Color(0xFFFCFCFB) : const Color(0xFF101013),
    surfaceContainer: isLight ? const Color(0xFFFAFAF9) : const Color(0xFF141417),
    surfaceContainerHigh: isLight ? const Color(0xFFF4F4F5) : const Color(0xFF18181C),
  );

  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: kFontSans,
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    extensions: [
      ClipThemeColors(
        border: border,
        muted: muted,
        accent: accent,
        accentHover: accentHover,
        ok: ok,
        dotShadow: isLight ? ClipColors.lightShadow : ClipColors.darkShadow,
      ),
    ],
    textTheme: base.textTheme
        .apply(
          bodyColor: text,
          displayColor: text,
          fontFamily: kFontSans,
        )
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontVariations: const [FontVariation('wght', 600)],
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontVariations: const [FontVariation('wght', 600)],
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
          bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12.5),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontVariations: const [FontVariation('wght', 500)],
          ),
        ),
    dividerTheme: DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: isLight ? const Color(0xFFE4E4E7) : const Color(0xFF27272A),
        disabledForegroundColor: muted,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: kFontSans,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: kFontSans,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontFamily: kFontSans, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSurface),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSurface),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSurface),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: muted, fontFamily: kFontSans),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      showDragHandle: true,
      dragHandleColor: border,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isLight ? Colors.white : const Color(0xFF06201C);
        }
        return isLight ? Colors.white : const Color(0xFF71717A);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return isLight ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46);
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFontSans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: text,
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: muted),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        color: isLight ? Colors.white : const Color(0xFF18181B),
        fontSize: 12,
        fontFamily: kFontSans,
      ),
    ),
  );
}

TextStyle mono(TextStyle style) => style.copyWith(fontFamily: kFontMono);

TextStyle sectionLabel(ThemeData theme) => mono(theme.textTheme.bodySmall!)
    .copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.2);
