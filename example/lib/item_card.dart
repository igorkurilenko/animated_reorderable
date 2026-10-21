// What the main example looks like: the cards of Flutter's ReorderableListView
// sample, apart from the list, which main.dart builds.

import 'package:flutter/material.dart';

/// A card of Flutter's ReorderableListView sample: 80 high, lime or purple.
class ItemCard extends StatelessWidget {
  const ItemCard(this.item, {super.key});

  final int item;

  @override
  Widget build(BuildContext context) => Semantics(
    // The item's own node, which holds its moves for screen readers: a
    // card would take a touch on a node of its own, without them.
    label: 'Card $item',
    child: ExcludeSemantics(
      child: Card(
        color: item.isOdd ? Colors.lime.shade100 : Colors.deepPurple.shade100,
        child: SizedBox(height: 80, child: Center(child: Text('Card $item'))),
      ),
    ),
  );
}

/// A held card rises, as in Flutter's sample: it grows a little and casts a
/// shadow.
Widget liftCard(Widget child, int index, Animation<double> animation) {
  final rise = animation.drive(CurveTween(curve: Curves.easeInOut));
  return ScaleTransition(
    scale: rise.drive(Tween(begin: 1.0, end: 1.02)),
    child: Stack(
      children: [
        // The shadow, behind the card, inside its margin.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: DecoratedBoxTransition(
              decoration: rise.drive(_shadow),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

final _shadow = DecorationTween(
  begin: BoxDecoration(borderRadius: BorderRadius.circular(12)),
  end: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    boxShadow: kElevationToShadow[6],
  ),
);
