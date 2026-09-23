import '../engine/puzzle_analysis.dart';
import '../models/level.dart';

/// Profil retenu après le test humain : le niveau 10 du lot d'essai est
/// désormais le point de départ, y compris pendant les respirations.
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
