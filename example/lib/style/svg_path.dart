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

final _token = RegExp(
  r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d*\.\d+|\d+\.?)(?:[eE][+-]?\d+)?',
);
final _letter = RegExp(r'^[A-Za-z]$');

/// Minimal SVG path-data parser covering the commands the Unicons line icons
/// use (M/L/H/V/C/S/Q/T/A/Z, absolute and relative), as in rose_app. Arcs map
/// directly onto [Path.arcToPoint]. Coordinates are in the source SVG's own
/// view box; callers scale the returned [Path] to their display size.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;

  double cx = 0, cy = 0; // current point
  double sx = 0, sy = 0; // current sub-path start
  double cubicX = 0, cubicY = 0; // last cubic control point
  double quadX = 0, quadY = 0; // last quad control point
  var last = '';

  double next() => double.parse(tokens[i++]);
  bool hasNum() => i < tokens.length && !_letter.hasMatch(tokens[i]);

  while (i < tokens.length) {
    final cmd = tokens[i++];
    final rel =
        cmd == cmd.toLowerCase() &&
        _letter.hasMatch(cmd) &&
        cmd != cmd.toUpperCase();
    final up = cmd.toUpperCase();

    switch (up) {
      case 'M':
        var first = true;
        while (hasNum()) {
          var x = next(), y = next();
          if (rel) {
            x += cx;
            y += cy;
          }
          if (first) {
            path.moveTo(x, y);
            sx = x;
            sy = y;
            first = false;
          } else {
            path.lineTo(x, y);
          }
          cx = x;
          cy = y;
        }
      case 'L':
        while (hasNum()) {
          var x = next(), y = next();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.lineTo(x, y);
          cx = x;
          cy = y;
        }
      case 'H':
        while (hasNum()) {
          var x = next();
          if (rel) x += cx;
          path.lineTo(x, cy);
          cx = x;
        }
      case 'V':
        while (hasNum()) {
          var y = next();
          if (rel) y += cy;
          path.lineTo(cx, y);
          cy = y;
        }
      case 'C':
        while (hasNum()) {
          var x1 = next(),
              y1 = next(),
              x2 = next(),
              y2 = next(),
              x = next(),
              y = next();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          path.cubicTo(x1, y1, x2, y2, x, y);
          cubicX = x2;
          cubicY = y2;
          cx = x;
          cy = y;
          last = up;
        }
      case 'S':
        while (hasNum()) {
          var x2 = next(), y2 = next(), x = next(), y = next();
          if (rel) {
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          final smooth = last == 'C' || last == 'S';
          final x1 = smooth ? 2 * cx - cubicX : cx;
          final y1 = smooth ? 2 * cy - cubicY : cy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          cubicX = x2;
          cubicY = y2;
          cx = x;
          cy = y;
          last = up;
        }
      case 'Q':
        while (hasNum()) {
          var x1 = next(), y1 = next(), x = next(), y = next();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x += cx;
            y += cy;
          }
          path.quadraticBezierTo(x1, y1, x, y);
          quadX = x1;
          quadY = y1;
          cx = x;
          cy = y;
          last = up;
        }
      case 'T':
        while (hasNum()) {
          var x = next(), y = next();
          if (rel) {
            x += cx;
            y += cy;
          }
          final smooth = last == 'Q' || last == 'T';
          final x1 = smooth ? 2 * cx - quadX : cx;
          final y1 = smooth ? 2 * cy - quadY : cy;
          path.quadraticBezierTo(x1, y1, x, y);
          quadX = x1;
          quadY = y1;
          cx = x;
          cy = y;
          last = up;
        }
      case 'A':
        while (hasNum()) {
          final rx = next(), ry = next(), rotation = next();
          final largeArc = next() != 0, sweep = next() != 0;
          var x = next(), y = next();
          if (rel) {
            x += cx;
            y += cy;
          }
          if (rx == 0 || ry == 0) {
            path.lineTo(x, y);
          } else {
            path.arcToPoint(
              Offset(x, y),
              radius: Radius.elliptical(rx, ry),
              rotation: rotation,
              largeArc: largeArc,
              clockwise: sweep,
            );
          }
          cx = x;
          cy = y;
        }
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
    }
    last = up;
  }

  return path;
}
