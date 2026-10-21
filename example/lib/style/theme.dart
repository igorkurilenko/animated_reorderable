// Copyright 2026 Igor Kurilenko
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// The examples' look, as rose_app's: Geist type, neutral grays with one
/// accent, flat controls with squircle corners, and 20px Unicons.
final ThemeData exampleTheme = _buildTheme();

/// Squircle corners of [radius], as rose_app's (there Figma's, with 0.6
/// smoothing; here Flutter's own superellipse, with no package).
RoundedSuperellipseBorder squircle(
  double radius, {
  BorderSide side = BorderSide.none,
}) => RoundedSuperellipseBorder(
  side: side,
  borderRadius: BorderRadius.circular(radius),
);

/// The tint a control takes when hovered, focused or pressed, in [color]:
/// the only feedback, as controls stay flat and nothing ripples.
WidgetStateProperty<Color> buttonOverlay(
  Color color,
) => WidgetStateProperty.resolveWith(
  (states) => switch (states) {
    _ when states.contains(WidgetState.disabled) => Colors.transparent,
    _ when states.contains(WidgetState.pressed) => color.withValues(alpha: .18),
    _ when states.contains(WidgetState.focused) => color.withValues(alpha: .16),
    _ when states.contains(WidgetState.hovered) => color.withValues(alpha: .08),
    _ => Colors.transparent,
  },
);

/// The accent, Pinterest's red: the page's one main action, and what stands
/// out.
const _accent = Color(0xFFCC0120);

ThemeData _buildTheme() {
  final colors =
      ColorScheme.fromSeed(
        // A gray seed, so the generated colors carry no tint.
        seedColor: const Color(0xFF808080),
      ).copyWith(
        primary: _accent,
        onPrimary: Colors.white,
        surface: const Color(0xFFFAFAFA),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: const Color(0xFFF4F4F4),
        surfaceContainerHigh: const Color(0xFFEFEFEF),
        surfaceContainerHighest: const Color(0xFFE8E8E8),
        outline: const Color(0xFFE2E2E2),
        outlineVariant: const Color(0xFFEDEDED),
        onSurfaceVariant: const Color(0xFF6B6B6B),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
  );
  final text = _geist(base.textTheme);

  return base.copyWith(
    textTheme: text,
    iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: S.s5),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: squircle(R.lg, side: BorderSide(color: colors.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            disabledBackgroundColor: colors.primary.withValues(alpha: .4),
            disabledForegroundColor: colors.onPrimary.withValues(alpha: .4),
            minimumSize: const Size(0, S.s9 + S.s1),
            // At its full height whatever the theme's density, as rose_app's.
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: S.s5),
            shape: squircle(R.xl),
            textStyle: text.labelLarge?.copyWith(
              fontSize: Fz.bodyMedium,
              fontWeight: FontWeight.w700,
            ),
          ).copyWith(
            elevation: const WidgetStatePropertyAll(0),
            overlayColor: buttonOverlay(colors.onPrimary),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        iconSize: S.s5,
        minimumSize: const Size.square(S.s8),
      ).copyWith(overlayColor: buttonOverlay(colors.onSurface)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: .6),
      space: 1,
      thickness: 1,
    ),
  );
}

/// The type scale in Geist, as rose_app's: headings, the display, headline
/// and title slots, tracked by [headingLetterSpacing]; body copy and labels
/// at the font's own spacing.
TextTheme _geist(TextTheme base) {
  final geist = base.apply(fontFamily: 'Geist');
  TextStyle? style(
    TextStyle? from, {
    required double size,
    required double height,
    FontWeight weight = FontWeight.w400,
    bool heading = false,
  }) => from?.copyWith(
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: heading ? headingLetterSpacing(size) : 0,
  );

  return geist.copyWith(
    displaySmall: style(
      geist.displaySmall,
      size: Fz.displaySmall,
      height: 1.1,
      weight: FontWeight.w700,
      heading: true,
    ),
    headlineMedium: style(
      geist.headlineMedium,
      size: Fz.headlineMedium,
      height: 1.2,
      weight: FontWeight.w600,
      heading: true,
    ),
    headlineSmall: style(
      geist.headlineSmall,
      size: Fz.headlineMedium,
      height: 1.2,
      weight: FontWeight.w600,
      heading: true,
    ),
    titleLarge: style(
      geist.titleLarge,
      size: Fz.bodyLarge,
      height: 1.3,
      weight: FontWeight.w600,
      heading: true,
    ),
    titleMedium: style(
      geist.titleMedium,
      size: Fz.bodyMedium,
      height: 1.3,
      weight: FontWeight.w600,
      heading: true,
    ),
    titleSmall: style(
      geist.titleSmall,
      size: Fz.bodySmall,
      height: 1.3,
      weight: FontWeight.w500,
      heading: true,
    ),
    bodyLarge: style(geist.bodyLarge, size: Fz.bodyLarge, height: 1.6),
    bodyMedium: style(geist.bodyMedium, size: Fz.bodyMedium, height: 1.6),
    bodySmall: style(geist.bodySmall, size: Fz.bodySmall, height: 1.5),
    labelLarge: style(
      geist.labelLarge,
      size: Fz.bodySmall,
      height: 1.4,
      weight: FontWeight.w500,
    ),
    labelMedium: style(
      geist.labelMedium,
      size: Fz.labelSmall,
      height: 1.4,
      weight: FontWeight.w500,
    ),
    labelSmall: style(
      geist.labelSmall,
      size: Fz.labelSmall,
      height: 1.4,
      weight: FontWeight.w500,
    ),
  );
}
