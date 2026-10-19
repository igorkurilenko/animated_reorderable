import 'dart:collection';

import 'package:flutter/widgets.dart';

/// A map by item key that hashes a [ValueKey] by its value alone.
///
/// A [ValueKey] hashes its `runtimeType` along with its value, and a
/// generic class's `runtimeType` is slow to get in release builds. The
/// package looks up each item it builds by its key: in a dense grid,
/// hashing the keys took a third of each rebuild. Equal value keys have
/// equal values, so they hash alike here too.
LinkedHashMap<Key, V> keyMap<V>() =>
    LinkedHashMap<Key, V>(equals: sameKey, hashCode: keyHash);

/// Whether [a] and [b] are equal keys, as `==` tells. Two value keys are
/// compared by `==`, with its `runtimeType`, only if their values are
/// equal.
///
/// It takes any object, as the map's functions must: after `removeWhere`,
/// the VM's map can compare a key with its own marker of a removed entry.
bool sameKey(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is ValueKey && b is ValueKey && a.value != b.value) return false;
  return a == b;
}

/// The hash of [key], by its value for a [ValueKey].
int keyHash(Object? key) => switch (key) {
  ValueKey(:final value) => value.hashCode,
  _ => key.hashCode,
};
