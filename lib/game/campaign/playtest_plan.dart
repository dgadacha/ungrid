/// Progression expérimentale : les scores sont des cibles de sélection,
/// à confronter au ressenti des joueurs, pas une mesure de leur plaisir.
class PlaytestStage {
  const PlaytestStage(
    this.targetScore,
    this.minBlocks,
    this.maxBlocks, {
    this.minStops = 0,
    this.maxStops = 2,
    this.minNarrowness = 0,
    this.minWrongRatio = 0,
    this.minDependency = 0,
    this.maxTriviality = 0.30,
  });

  final double targetScore;
  final int minBlocks;
  final int maxBlocks;
  final int minStops;
  final int maxStops;
  final double minNarrowness;
  final double minWrongRatio;
  final double minDependency;
  final double maxTriviality;
}

class PlaytestPlan {
  const PlaytestPlan._();

  static const assetPath = 'assets/levels/playtest_v1.json';
  static const chapters = [
    'FIRST CHOICES',
    'CROSSING PATHS',
    'PLAN AHEAD',
    'MASTERY',
  ];
  static const phases = [
    'Discover',
    'Practice',
    'Challenge',
    'Breathe',
    'Combine',
  ];

  static String chapterFor(int levelId) => chapters[(levelId - 1) ~/ 5];
  static String phaseFor(int levelId) => phases[(levelId - 1) % 5];

  // Les trois premiers niveaux apprennent les choix et le quatrième les
  // arrêts. Les chapitres suivants alternent montée et respiration.
  static const stages = [
    PlaytestStage(21, 4, 5, maxStops: 0, maxTriviality: 0.65),
    PlaytestStage(34, 4, 6, maxStops: 0, maxTriviality: 0.55),
    PlaytestStage(40, 5, 7, maxStops: 1, maxTriviality: 0.45),
    PlaytestStage(43, 5, 8, minStops: 1, maxTriviality: 0.40),
    PlaytestStage(
      52,
      6,
      9,
      minStops: 1,
      minWrongRatio: 0.35,
      minDependency: 0.55,
    ),
    PlaytestStage(40, 6, 9, minStops: 1),
    PlaytestStage(48, 6, 10, minStops: 1, minWrongRatio: 0.3),
    PlaytestStage(
      54,
      7,
      11,
      minNarrowness: 0.25,
      minWrongRatio: 0.4,
      minDependency: 0.6,
    ),
    PlaytestStage(44, 6, 9, minStops: 1),
    PlaytestStage(
      61,
      7,
      11,
      minStops: 1,
      minNarrowness: 0.35,
      minWrongRatio: 0.5,
      minDependency: 0.65,
    ),
    PlaytestStage(46, 7, 10, minStops: 1),
    PlaytestStage(
      56,
      7,
      11,
      minNarrowness: 0.3,
      minWrongRatio: 0.45,
      minDependency: 0.6,
    ),
    PlaytestStage(
      62,
      8,
      12,
      minNarrowness: 0.4,
      minWrongRatio: 0.55,
      minDependency: 0.65,
    ),
    PlaytestStage(49, 7, 10, minStops: 1),
    PlaytestStage(
      68,
      8,
      12,
      minStops: 1,
      minNarrowness: 0.5,
      minWrongRatio: 0.6,
      minDependency: 0.7,
      maxTriviality: 0.2,
    ),
    PlaytestStage(51, 7, 11, minStops: 1),
    PlaytestStage(
      61,
      8,
      12,
      minNarrowness: 0.4,
      minWrongRatio: 0.5,
      minDependency: 0.65,
    ),
    PlaytestStage(
      67,
      8,
      13,
      minNarrowness: 0.5,
      minWrongRatio: 0.6,
      minDependency: 0.7,
      maxTriviality: 0.2,
    ),
    PlaytestStage(54, 7, 11, minStops: 1),
    PlaytestStage(
      74,
      8,
      14,
      minStops: 1,
      minNarrowness: 0.6,
      minWrongRatio: 0.65,
      minDependency: 0.7,
      maxTriviality: 0.2,
    ),
  ];
}
