import 'package:flutter/foundation.dart';

const draggedItemDecoratorId = 'dragged-item-decorator';
const swipedItemDecoratorId = 'swiped-item-decorator';
const int maxInt = kIsWeb
    ? 9007199254740992 
    : ((1 << 63) - 1);
const minZIndex = 0;
const maxZIndex = maxInt;
// const Duration du300ms = Duration(milliseconds: 500);
const Duration du300ms = Duration(milliseconds: 10000);
const double defaultAutoScrollVelocityScalar = 50;
const alpha = 0.001;
