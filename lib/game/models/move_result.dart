import 'grid_position.dart';

/// Issue d'un tap sur la grille.
enum MoveOutcome {
  /// Rien ne barrait la route : le bloc a quitté la grille.
  exited,

  /// Le bloc a glissé jusqu'à la dernière case libre avant l'obstacle.
  slid,

  /// Le bloc est entré sur une tuile d'arrêt et s'y est posé.
  stopped,

  /// L'obstacle touchait le bloc : il n'a pas bougé d'un pouce.
  blocked,

  /// Le tap ne visait aucun bloc, ou le coup a été ignoré.
  ignored,
}

/// Ce qu'un coup a produit.
class MoveResult {
  const MoveResult({
    required this.outcome,
    this.blockId,
    this.from,
    this.to,
    this.remainingBlocks = 0,
  });

  const MoveResult.ignored()
    : outcome = MoveOutcome.ignored,
      blockId = null,
      from = null,
      to = null,
      remainingBlocks = 0;

  final MoveOutcome outcome;
  final String? blockId;

  /// Case de départ du bloc.
  final GridPosition? from;

  /// Case d'arrivée, `null` si le bloc a quitté la grille.
  final GridPosition? to;

  final int remainingBlocks;

  bool get exited => outcome == MoveOutcome.exited;
  bool get slid => outcome == MoveOutcome.slid;
  bool get blocked => outcome == MoveOutcome.blocked;
  bool get stopped => outcome == MoveOutcome.stopped;

  /// Le coup a-t-il modifié le plateau ? Un refus n'y change rien, et n'a donc
  /// rien à annuler.
  bool get changedBoard => exited || slid || stopped;

  bool get isLevelComplete => exited && remainingBlocks == 0;
}
