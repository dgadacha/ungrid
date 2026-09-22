/// Générateur pseudo-aléatoire déterministe (xorshift 32 bits).
///
/// `dart:math` ne garantit pas la même suite d'une version à l'autre : comme
/// un niveau doit rester identique à travers les mises à jour du jeu, la
/// génération s'appuie sur cette implémentation explicite.
class SeededRandom {
  SeededRandom(int seed) : _state = _scramble(seed);

  int _state;

  /// Mélange initial : deux seeds voisines doivent produire des suites très
  /// différentes, sinon les niveaux consécutifs se ressemblent.
  static int _scramble(int seed) {
    var x = seed & 0xFFFFFFFF;
    x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
    x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
    x = (x >> 16) ^ x;
    x &= 0xFFFFFFFF;
    return x == 0 ? 0x9e3779b9 : x;
  }

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  /// Entier dans `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'doit être > 0');
    return _next() % max;
  }

  double nextDouble() => _next() / 0x100000000;

  bool nextBool() => _next() & 1 == 1;

  /// Mélange une liste sur place (Fisher-Yates).
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}

/// Seed d'un niveau : déterministe, et suffisamment dispersée pour que deux
/// niveaux voisins ne partagent aucune structure.
int seedForLevel(int levelId, [int attempt = 0]) {
  var x = (levelId * 7919 + attempt * 2654435761) & 0xFFFFFFFF;
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
  x = (x >> 16) ^ x;
  return x & 0xFFFFFFFF;
}
