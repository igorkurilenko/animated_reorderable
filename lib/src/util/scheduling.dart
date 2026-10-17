import 'package:flutter/widgets.dart';

void addPostFrame(VoidCallback cb) =>
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => cb());

extension StateRebuild on State {
  void rebuild([VoidCallback? cb]) {
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() => cb?.call());
  }
}
