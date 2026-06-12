extension SafeList<T> on List<T> {
  /// Returns the first element if not empty, otherwise null.
  T? get firstOrNull => isNotEmpty ? first : null;

  /// Returns the last element if not empty, otherwise null.
  T? get lastOrNull => isNotEmpty ? last : null;

  /// Returns the first element where [test] is true, otherwise null.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
