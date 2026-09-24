import '../engine/planning_difficulty.dart';
import '../engine/puzzle_analysis.dart';
import '../models/level.dart';

/// Les quatre paliers de la campagne.
///
/// La version précédente n'avait qu'un profil : sept blocs et un score de
/// soixante partout, si bien que le premier niveau demandait déjà seize coups
/// et trois retours différés. On apprenait la règle sur un puzzle d'expert.
///
/// Chaque palier a désormais ses propres exigences, et elles portent sur ce
/// qui fait la marche à franchir — la longueur de la solution, le nombre de
/// blocs à tenir en tête, et surtout les retours différés : revenir à un bloc
/// après en avoir joué un autre est ce qui demande de planifier.
enum CampaignTier {
  /// 1 à 5 : on apprend. Une rotation, peu de blocs, une solution courte.
  tutorial(upTo: 5),

  /// 6 à 25 : la règle est acquise, l'ordre commence à compter.
  medium(upTo: 25),

  /// 26 à 50 : il faut prévoir plusieurs coups d'avance.
  hard(upTo: 50),

  /// 51 à 100 : sortir ce qui peut sortir ne suffit plus jamais.
  extreme(upTo: 100);

  const CampaignTier({required this.upTo});

  /// Dernier niveau du palier.
  final int upTo;

  /// Taille de la campagne.
  static const campaignLength = 100;

  static CampaignTier forLevel(int id) {
    if (id < 1 || id > campaignLength) {
      throw RangeError.range(id, 1, campaignLength);
    }
    return CampaignTier.values.firstWhere((tier) => id <= tier.upTo);
  }

  /// Nombre de niveaux que ce palier occupe.
  int get levelCount {
    final index = CampaignTier.values.indexOf(this);
    final from = index == 0 ? 0 : CampaignTier.values[index - 1].upTo;
    return upTo - from;
  }

  bool accepts(Level level, PuzzleAnalysis a, PlanningDifficulty p) =>
      switch (this) {
        // Rien sur le score : un premier niveau doit être lisible, pas noté.
        // Une seule rotation, sinon la règle s'apprend sur deux exemples à la
        // fois.
        CampaignTier.tutorial => level.blocks.length >= 4 &&
            level.blocks.length <= 7 &&
            level.rotationTiles.length == 1 &&
            a.optimalMoves >= 5 &&
            a.optimalMoves <= 9 &&
            a.unresolvedAlternatives == 0,
        CampaignTier.medium => level.blocks.length >= 6 &&
            level.blocks.length <= 10 &&
            a.optimalMoves >= 10 &&
            a.optimalMoves <= 15 &&
            a.difficultyScore() >= 50 &&
            p.deferredReturns >= 1 &&
            a.unresolvedAlternatives == 0 &&
            a.unusedStopTileCount == 0,
        CampaignTier.hard => level.blocks.length >= 8 &&
            a.optimalMoves >= 15 &&
            a.optimalMoves <= 20 &&
            a.difficultyScore() >= 60 &&
            a.trivialityPenalty <= 0.25 &&
            p.deferredReturns >= 2 &&
            a.unresolvedAlternatives == 0 &&
            a.unusedStopTileCount == 0,
        // Le palier que la v4 remplissait déjà : c'est son profil, repris tel
        // quel pour que ses cent niveaux restent éligibles.
        CampaignTier.extreme => level.blocks.length >= 7 &&
            a.optimalMoves >= 16 &&
            a.difficultyScore() >= 60 &&
            a.trivialityPenalty <= 0.2 &&
            a.optimalPathNarrowness >= 0.35 &&
            a.temptingWrongMoveRatio >= 0.5 &&
            a.dependencyComplexity >= 0.65 &&
            p.accepts &&
            a.unresolvedAlternatives == 0 &&
            a.unusedStopTileCount == 0,
      };
}

/// Profil de la campagne « tuiles d'arrêt », conservé pour la v2.
///
/// Il ne sert plus à construire : la campagne servie passe par
/// [CampaignTier]. Mais la v2 reste éprouvée par les tests, et c'est contre
/// ce profil-là qu'elle a été retenue — la juger sur les exigences actuelles
/// n'aurait aucun sens.
class CampaignProfile {
  const CampaignProfile(this.targetScore, {this.expert = false});

  static const levelCount = 100;
  final double targetScore;
  final bool expert;

  static CampaignProfile forLevel(int id) {
    if (id < 1 || id > levelCount) throw RangeError.range(id, 1, levelCount);
    if (id == 100) return const CampaignProfile(79, expert: true);
    final base = id <= 20
        ? 61.5
        : id <= 50
        ? 64.5
        : id <= 80
        ? 67.5
        : 70.5;
    const wave = [0.0, 1.0, 2.0, 0.0, 4.0];
    return CampaignProfile(base + wave[(id - 1) % 5], expert: id > 50);
  }

  bool accepts(Level level, PuzzleAnalysis a) =>
      level.blocks.length >= 7 &&
      level.blocks.length <= 14 &&
      level.columns <= 6 &&
      level.stopTiles.isNotEmpty &&
      level.stopTiles.length <= 2 &&
      a.unresolvedAlternatives == 0 &&
      a.unusedStopTileCount == 0 &&
      a.difficultyScore() >= 60 &&
      (a.difficultyScore() - targetScore).abs() <= 1.5 &&
      a.optimalPathNarrowness >= (expert ? 0.5 : 0.35) &&
      a.temptingWrongMoveRatio >= (expert ? 0.6 : 0.5) &&
      a.dependencyComplexity >= (expert ? 0.7 : 0.65) &&
      a.trivialityPenalty <= 0.2;
}
