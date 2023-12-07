import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

const int maxInt = kIsWeb ? 9007199254740992 : ((1 << 63) - 1);
const outgoingItemZIndex = -1;
const defaultZIndex = 0;
const maxZIndex = maxInt;

const Duration duration500ms = Duration(milliseconds: 500);
// const Duration duration500ms = Duration(milliseconds: 10000);
const double defaultAutoScrollVelocityScalar = 50;
const alpha = 0.001;

const defaultSwipeAwayExtent = 0.6;
const defaultSwipeAwayVelocity = 700.0;

const defaultFlingSpringDescription = SpringDescription(
  mass: 1.0,
  stiffness: 500.0,
  damping: 75.0,
);
