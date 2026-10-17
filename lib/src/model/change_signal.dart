part of 'model.dart';

/// A [ChangeNotifier] that whoever changes the model triggers.
class ChangeSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}
