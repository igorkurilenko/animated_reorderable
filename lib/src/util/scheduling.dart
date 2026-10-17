import 'package:flutter/widgets.dart';

void addPostFrame(VoidCallback cb) =>
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => cb());
