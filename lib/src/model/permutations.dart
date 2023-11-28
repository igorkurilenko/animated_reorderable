class Permutations {
  final _permutations = <_Permuration>[];
  final _indexByElementId = <int, int>{};
  final _elementIdByIndex = <int, int>{};

  void addPermutation({
    required int elementId,
    required int from,
    required int to,
  }) =>
      _add(_Permuration(
        elementId: elementId,
        from: from,
        to: to,
      ));

  void _add(_Permuration p) {
    final curIndexOfElement = indexOf(p.elementId);
    _elementIdByIndex.remove(curIndexOfElement);

    final unorderedElementId = elementIdAt(p.to);
    _indexByElementId.remove(unorderedElementId);

    _indexByElementId[p.elementId] = p.to;
    _elementIdByIndex[p.to] = p.elementId;

    _permutations.add(p);
  }

  int? indexOf(int elementId) => _indexByElementId[elementId];

  int? elementIdAt(int index) => _elementIdByIndex[index];

  void apply<T>(List<T> list) {
    final unordered = <int, T>{};
    final emptySlots = <int>{};
    for (final p in _permutations) {
      if (!emptySlots.contains(p.to)) {
        unordered[p.to] = list[p.to];
      }
      if (unordered.containsKey(p.from)) {
        list[p.to] = unordered.remove(p.from) as T;
      } else {
        list[p.to] = list[p.from];
        emptySlots.add(p.from);
      }
      emptySlots.remove(p.to);
    }
  }

  bool get isEmpty => _permutations.isEmpty;

  @override
  String toString() => _permutations.toString();
}

class _Permuration {
  final int elementId;
  final int from;
  final int to;

  _Permuration({
    required this.elementId,
    required this.from,
    required this.to,
  });
}