abstract class HasId {
  int get id;
}

class Item implements HasId {
  @override
  final int id;
  final double? height;

  Item({
    required this.id,
    this.height,
  });

  @override
  String toString() => 'Item $id';
}

abstract class Sample {
  void insert();

  void remove();

  void moveRandom();
}
