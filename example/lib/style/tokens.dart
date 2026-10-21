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

import 'package:flutter/widgets.dart';

/// Sizes, paddings and insets, as rose_app's: [s1] (4) to [s10] (64).
abstract final class S {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 48;
  static const double s10 = 64;
}

/// Gaps between the children of a [Column] (`h`) or a [Row] (`w`).
abstract final class G {
  static const Widget h4 = SizedBox(height: S.s1);
  static const Widget h8 = SizedBox(height: S.s2);
  static const Widget h16 = SizedBox(height: S.s4);
  static const Widget h24 = SizedBox(height: S.s6);
  static const Widget h32 = SizedBox(height: S.s7);
  static const Widget w12 = SizedBox(width: S.s3);
}

/// Corner radii, as rose_app's.
abstract final class R {
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
}

/// Font sizes, as rose_app's type scale.
abstract final class Fz {
  static const double displaySmall = 36;
  static const double headlineMedium = 24;
  static const double bodyLarge = 18;
  static const double bodyMedium = 16;
  static const double bodySmall = 14;
  static const double labelSmall = 12;
}

/// A heading's letter spacing at [fontSize], as Geist's own type scale sets
/// it: -2% of the size up to 20px, -4% from 24px, -6% from 40px. Body copy,
/// labels and buttons keep the font's own spacing.
double headingLetterSpacing(double fontSize) =>
    -fontSize * (fontSize >= 40 ? .06 : (fontSize >= 24 ? .04 : .02));
