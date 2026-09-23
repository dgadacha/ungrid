import '../../app/constants.dart';
import '../models/block.dart';
import '../models/direction.dart';

/// Un bloc en train de se déplacer à l'écran.
///
/// Sert aussi bien à la sortie qu'au glissement et au retour en arrière : dans
/// les trois cas, un bloc va d'une case à une autre, l'une des deux pouvant se
/// trouver hors de la grille. Le moteur, lui, a déjà enregistré le résultat —
/// l'animation ne fait que le montrer.
class BlockMotion {
  BlockMotion({
    required this.blockId,
    required this.direction,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.startMs,
    required this.durationMs,
    this.fadeOut = false,
    this.fadeIn = false,
  });

  /// Glissement à l'intérieur de la grille.
  factory BlockMotion.slide({
    required Block block,
    required int fromX,
    required int fromY,
    required int startMs,
  }) {
    final distance = (block.x - fromX).abs() + (block.y - fromY).abs();
    return BlockMotion(
      blockId: block.id,
      direction: block.direction,
      fromX: fromX.toDouble(),
      fromY: fromY.toDouble(),
      toX: block.x.toDouble(),
      toY: block.y.toDouble(),
      startMs: startMs,
      durationMs: _durationFor(distance),
    );
  }

  /// Sortie : le bloc continue au-delà du bord, puis s'efface.
  factory BlockMotion.exit({
    required Block block,
    required int columns,
    required int rows,
    required int startMs,
  }) {
    final distance = switch (block.direction) {
      Direction.up => block.y + 1,
      Direction.down => rows - block.y,
      Direction.left => block.x + 1,
      Direction.right => columns - block.x,
    };
    final travel = distance + 1.0;
    return BlockMotion(
      blockId: block.id,
      direction: block.direction,
      fromX: block.x.toDouble(),
      fromY: block.y.toDouble(),
      toX: block.x + block.direction.dx * travel,
      toY: block.y + block.direction.dy * travel,
      startMs: startMs,
      durationMs: _durationFor(distance),
      fadeOut: true,
    );
  }

  /// Retour en arrière : l'animation exacte à l'envers.
  factory BlockMotion.reverse(
    BlockMotion motion,
    int startMs, {
    Direction? restoredDirection,
  }) => BlockMotion(
    blockId: motion.blockId,
    direction: restoredDirection ?? motion.direction,
    fromX: motion.toX,
    fromY: motion.toY,
    toX: motion.fromX,
    toY: motion.fromY,
    startMs: startMs,
    durationMs: motion.durationMs,
    fadeIn: motion.fadeOut,
  );

  final String blockId;
  final Direction direction;

  /// Coordonnées en cellules, éventuellement hors de la grille.
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;

  final int startMs;
  final int durationMs;

  /// Le bloc s'efface en fin de course : il quitte la grille.
  final bool fadeOut;

  /// Le bloc apparaît en début de course : il revient de l'extérieur.
  final bool fadeIn;

  /// Un trajet court doit rester vif, un trajet long ne doit pas paraître
  /// précipité : la durée suit la distance, dans des bornes serrées.
  static int _durationFor(int cells) {
    final base = GameTiming.blockExit.inMilliseconds;
    final scaled = (base * 0.55 + cells * 26).round();
    return scaled.clamp(110, base + 90);
  }

  double progress(int nowMs) {
    final elapsed = nowMs - startMs;
    if (elapsed <= 0) return 0;
    if (elapsed >= durationMs) return 1;
    return elapsed / durationMs;
  }

  bool isDone(int nowMs) => nowMs - startMs >= durationMs;
}

/// Le refus d'un bloc qui ne peut pas bouger : il s'élance, bute, revient.
class BlockedFeedback {
  BlockedFeedback({required this.block, required this.startMs});

  final Block block;
  final int startMs;

  /// Avancement de la secousse.
  double progress(int nowMs) => _ratio(nowMs, GameTiming.blockedShake);

  /// Avancement de l'étiquette, qui survit un peu à la secousse.
  double labelProgress(int nowMs) => _ratio(nowMs, GameTiming.blockedLabel);

  double _ratio(int nowMs, Duration duration) {
    final elapsed = nowMs - startMs;
    final total = duration.inMilliseconds;
    if (elapsed <= 0) return 0;
    if (elapsed >= total) return 1;
    return elapsed / total;
  }

  bool isDone(int nowMs) =>
      nowMs - startMs >= GameTiming.blockedLabel.inMilliseconds;
}

/// L'écrasement du bloc sous le doigt, joué à chaque tap.
class PressFeedback {
  PressFeedback({required this.blockId, required this.startMs});

  final String blockId;
  final int startMs;

  double progress(int nowMs) {
    final elapsed = nowMs - startMs;
    final total = GameTiming.tapPress.inMilliseconds;
    if (elapsed <= 0) return 0;
    if (elapsed >= total) return 1;
    return elapsed / total;
  }

  bool isDone(int nowMs) =>
      nowMs - startMs >= GameTiming.tapPress.inMilliseconds;
}
