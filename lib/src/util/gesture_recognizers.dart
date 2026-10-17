import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

MultiDragGestureRecognizer createReorderDragGestureRecognizer(
  BuildContext context,
) =>
    DelayedMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createHorizontalSwipeDragGestureRecognizer(
  BuildContext context,
) =>
    HorizontalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createVerticalSwipeDragGestureRecognizer(
  BuildContext context,
) =>
    VerticalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createImmediateDragGestureRecognizer(
  BuildContext context,
) =>
    ImmediateMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
