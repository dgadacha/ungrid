import '../models/level.dart';
import '../models/grid_position.dart';
import 'game_engine.dart';
import 'level_solver.dart';
import 'slide_generator.dart';

/// Générateur opt-in, règles rotation v1. La campagne v2 reste reproductible.
/// Un candidat n'est livré que si sa solution optimale utilise chaque rotation
/// et cesse de fonctionner lorsqu'on remplace les rotations par des arrêts.
class RotationGenerator {
  const RotationGenerator({this.solver = const LevelSolver()});
  final LevelSolver solver;
  static const rulesVersion = 1;

  Level? fromSeed(int seed, {int levelId = 0}) {
    final base = const SlideGenerator().fromSeed(seed);
    if (base == null ||
        base.columns > 6 ||
        base.blocks.length > 12 ||
        base.stopTiles.isEmpty ||
        base.stopTiles.length > 2) {
      return null;
    }
    final candidate = base.copyWith(
      stopTiles: [],
      rotationTiles: base.stopTiles,
    );
    final solved = solver.solve(candidate);
    if (!solved.solvable || !solved.exhaustive) return null;
    final engine = GameEngine(candidate);
    final unchanged = GameEngine(base);
    final visited = <GridPosition>{};
    for (final id in solved.exampleSolution) {
      final move = engine.tap(id);
      if (move.to != null && candidate.rotationTiles.contains(move.to)) {
        visited.add(move.to!);
      }
      unchanged.tap(id);
    }
    if (!engine.isCompleted ||
        visited.length != candidate.rotationTiles.length ||
        unchanged.isCompleted) {
      return null;
    }
    return candidate.copyWith(id: levelId, optimalMoves: solved.minimumMoves);
  }
}
