import '../models/level.dart';
import 'game_engine.dart';
import 'seeded_random.dart';

/// Filtre comportemental : sortir les blocs dès que possible ne devrait pas
/// suffire pour les défis avancés. Ce n'est pas une mesure du temps humain.
class PlanningDifficulty {
  const PlanningDifficulty(this.deferredReturns, this.greedyWins);
  final int deferredReturns;
  final int greedyWins;
  static const trials = 24;

  static PlanningDifficulty measure(Level level, List<String> solution) {
    var returns = 0;
    final played = <String>{};
    String? previous;
    for (final id in solution) {
      if (played.contains(id) && previous != id) returns++;
      played.add(id);
      previous = id;
    }
    var wins = 0;
    for (var trial = 0; trial < trials; trial++) {
      final random = SeededRandom(trial + 1);
      final engine = GameEngine(level);
      for (var move = 0; move < level.optimalMoves; move++) {
        final exits = engine.exitableBlocks();
        final choices = exits.isEmpty ? engine.movableBlocks() : exits;
        if (choices.isEmpty) break;
        engine.tap(choices[random.nextInt(choices.length)].id);
      }
      if (engine.isCompleted) wins++;
    }
    return PlanningDifficulty(returns, wins);
  }

  bool get accepts => deferredReturns >= 3 && greedyWins <= 1;
  Map<String, int> toJson() => {
    'deferredReturns': deferredReturns,
    'greedyWins': greedyWins,
    'greedyTrials': trials,
  };
}
