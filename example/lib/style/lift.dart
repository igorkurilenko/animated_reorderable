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

import 'theme.dart';
import 'tokens.dart';

/// A held card rising off its list or grid, as [animation] goes: it grows
/// to [scale] and casts [shadow] from the cards' squircle, inside [margin].
class Lift extends StatelessWidget {
  const Lift({
    super.key,
    required this.animation,
    required this.scale,
    required this.shadow,
    this.margin = EdgeInsets.zero,
    required this.child,
  });

  final Animation<double> animation;
  final double scale;
  final BoxShadow shadow;

  /// The space around the card, in its slot, which the shadow stays inside.
  final EdgeInsets margin;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rise = animation.drive(CurveTween(curve: Curves.easeOut));
    return ScaleTransition(
      scale: rise.drive(Tween(begin: 1.0, end: scale)),
      child: Stack(
        // The card keeps its slot's size, as it has in its list or grid.
        fit: StackFit.passthrough,
        children: [
          // The shadow, behind the card.
          Positioned.fill(
            child: Padding(
              padding: margin,
              child: DecoratedBoxTransition(
                // The same squircle all the way, so that only the shadow
                // grows.
                decoration: rise.drive(
                  DecorationTween(
                    begin: ShapeDecoration(shape: squircle(R.lg)),
                    end: ShapeDecoration(
                      shape: squircle(R.lg),
                      shadows: [shadow],
                    ),
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
