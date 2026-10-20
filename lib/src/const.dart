import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// How far inside a dragged item the auto-scroller looks, so an item that
/// only touches an edge of the list does not scroll it.
const autoScrollEdgeInset = 0.001;

/// How long a dragged item takes to fly from one list's look to another's:
/// it has its new look by the time the items around it have made room.
const defaultFlightDuration = Duration(milliseconds: 200);

/// The curve a flight runs along, as a hero_here flight's does by default.
const defaultFlightCurve = Curves.easeInOut;

const maxInt = kIsWeb ? 9007199254740992 : ((1 << 63) - 1);

const maxZIndex = maxInt;

const defaultZIndex = 0;

const outgoingItemZIndex = -1;

const defaultAutoScrollVelocityScalar = 50.0;

/// How far, in logical pixels, an item's slot has to move for a moving
/// item to head for it anew.
const retargetTolerance = 0.5;

const defaultMotionAnimationCurve = Curves.easeInOut;

/// How long items take to move to their new places, as the items of
/// Flutter's reorderable lists do.
const defaultMotionAnimationDuration = Duration(milliseconds: 250);

const defaultSwipeToRemoveExtent = 0.6;

const defaultSwipeToRemoveVelocity = 700.0;

/// How long a held item's decoration takes to come or to go, as long as a
/// move takes.
const defaultDraggedItemDecorationAnimationDuration = Duration(
  milliseconds: 250,
);

/// How long an inserted item takes to come in, and a removed one to go, as
/// the items of Flutter's `AnimatedList` do.
const defaultInsertItemAnimationDuration = Duration(milliseconds: 300);

const defaultRemoveItemAnimationDuration = Duration(milliseconds: 300);

/// How long an item swiped away and let go at rest takes to get out of
/// sight, as long as a move takes. Let go faster, it gets out sooner.
const throwOutDuration = Duration(milliseconds: 250);

/// The spring that flings an item back to its place, the one
/// `SpringDescription.withDurationAndBounce` makes for 250 ms with no
/// bounce. It speeds an item let go at rest up over the first frames, and
/// takes it most of the way in a fifth of a second.
const defaultFlingSpringDescription = SpringDescription(
  mass: 1.0,
  // (2π / 0.25 s)², and twice its root, so it is critically damped.
  stiffness: 64 * math.pi * math.pi,
  damping: 16 * math.pi,
);
