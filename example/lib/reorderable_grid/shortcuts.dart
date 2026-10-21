// What the reorderable grid example looks like, apart from the grid, which
// main.dart builds.

import 'package:flutter/material.dart';

import '../style/style.dart';

/// A shortcut on the grid: its name, its icon, and the tint behind it.
typedef Shortcut = ({String name, String icon, Color tint});

const _peach = Color(0xFFFFE6C7);
const _sky = Color(0xFFD6E6F5);
const _mint = Color(0xFFD9EED9);
const _rose = Color(0xFFF5DCE4);

/// The shortcuts the grid starts with, tinted so that no two side by side,
/// or one above the other, have the same tint.
const List<Shortcut> kShortcuts = [
  (name: 'Home', icon: UniconData.home, tint: _peach),
  (name: 'Search', icon: UniconData.search, tint: _sky),
  (name: 'Camera', icon: UniconData.camera, tint: _mint),
  (name: 'Music', icon: UniconData.music, tint: _rose),
  (name: 'Health', icon: UniconData.health, tint: _peach),
  (name: 'Maps', icon: UniconData.maps, tint: _sky),
  (name: 'Clock', icon: UniconData.clock, tint: _mint),
  (name: 'Stocks', icon: UniconData.stocks, tint: _rose),
  (name: 'Shop', icon: UniconData.shop, tint: _peach),
  (name: 'Contacts', icon: UniconData.contacts, tint: _sky),
  (name: 'Watch', icon: UniconData.watch, tint: _mint),
  (name: 'Phone', icon: UniconData.phone, tint: _rose),
];

/// The shortcut that Add shortcut adds.
const Shortcut kNewShortcut = (
  name: 'Files',
  icon: UniconData.files,
  tint: Color(0xFFE8E0F5),
);

/// A shortcut's tile: its icon on its tint, and its name, on a card.
class ShortcutTile extends StatelessWidget {
  const ShortcutTile(this.shortcut, {super.key});

  final Shortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // The tile's own node, which holds its moves for screen readers: a
      // card would take a touch on a node of its own, without them.
      label: shortcut.name,
      child: ExcludeSemantics(
        child: Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: shortcut.tint,
                  shape: squircle(R.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(S.s3),
                  child: Unicon(
                    shortcut.icon,
                    size: S.s6,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              G.h8,
              Text(shortcut.name, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar under the grid, with the page's one main action.
class AddShortcutBar extends StatelessWidget {
  const AddShortcutBar({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(S.s4, S.s2, S.s4, S.s4),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Unicon(UniconData.add),
        label: const Text('Add shortcut'),
      ),
    ),
  );
}

/// A held tile rises off the grid: it grows a little and casts a shadow.
Widget liftTile(Widget child, int index, Animation<double> animation) {
  final rise = animation.drive(CurveTween(curve: Curves.easeOut));
  return ScaleTransition(
    scale: rise.drive(Tween(begin: 1.0, end: 1.06)),
    child: Stack(
      // The card keeps its cell's size, as it has in the grid.
      fit: StackFit.passthrough,
      children: [
        // The shadow, behind the card.
        Positioned.fill(
          child: DecoratedBoxTransition(
            decoration: rise.drive(_shadow),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    ),
  );
}

/// The same squircle all the way, so that only the shadow grows.
final _shadow = DecorationTween(
  begin: ShapeDecoration(shape: squircle(R.lg)),
  end: ShapeDecoration(
    shape: squircle(R.lg),
    shadows: const [
      BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
  ),
);

/// A tile added to the grid pops in once the others have made room.
Widget popIn(Widget child, int index, Animation<double> animation) {
  final pop = animation.drive(CurveTween(curve: const Interval(.4, 1)));
  return FadeTransition(
    opacity: pop,
    child: ScaleTransition(
      scale: pop.drive(CurveTween(curve: Curves.easeOutBack)),
      child: child,
    ),
  );
}
