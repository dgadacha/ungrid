import '../models/difficulty.dart';

/// État d'un niveau publié.
enum LevelStatus {
  /// Jouable.
  active,

  /// Retiré de la campagne sans être oublié : sa place reste réservée pour ne
  /// pas décaler les numéros déjà connus des joueurs.
  disabled,
}

/// Ce que le catalogue retient d'un niveau officiel.
///
/// Le board n'est pas stocké : il se reconstruit à partir de la seed et de la
/// version du générateur. Ce qui est figé ici, c'est l'identité du niveau —
/// et une fois publiée, elle ne change plus. Remplacer la seed du niveau 284
/// rendrait fausses toutes les solutions déjà partagées.
class CampaignLevel {
  const CampaignLevel({
    required this.levelId,
    required this.seed,
    required this.generatorVersion,
    required this.difficulty,
    required this.difficultyScore,
    required this.optimalMoves,
    required this.fingerprint,
    this.status = LevelStatus.active,
  });

  final int levelId;
  final int seed;
  final int generatorVersion;

  final Difficulty difficulty;
  final double difficultyScore;

  /// Coups minimaux pour vider la grille, et réserve du joueur : c'est le
  /// même nombre. Un second champ qui vaudrait toujours celui-ci finirait par
  /// en diverger sans que rien ne le signale.
  final int optimalMoves;

  /// Empreinte du board attendu : elle signale toute régression du générateur.
  final String fingerprint;

  final LevelStatus status;

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'seed': seed,
        'generatorVersion': generatorVersion,
        'difficulty': difficulty.name,
        'difficultyScore': double.parse(difficultyScore.toStringAsFixed(2)),
        'optimalMoves': optimalMoves,
        'fingerprint': fingerprint,
        'status': status.name,
      };

  static CampaignLevel fromJson(Map<String, dynamic> json) => CampaignLevel(
        levelId: json['levelId'] as int,
        seed: json['seed'] as int,
        generatorVersion: json['generatorVersion'] as int,
        difficulty: Difficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => Difficulty.easy,
        ),
        difficultyScore: (json['difficultyScore'] as num).toDouble(),
        optimalMoves: json['optimalMoves'] as int,
        fingerprint: json['fingerprint'] as String,
        status: LevelStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => LevelStatus.active,
        ),
      );
}

/// La campagne publiée.
class Campaign {
  const Campaign({
    required this.catalogVersion,
    required this.generatorVersion,
    required this.levels,
  });

  final int catalogVersion;
  final int generatorVersion;
  final List<CampaignLevel> levels;

  int get levelCount => levels.length;

  CampaignLevel? operator [](int levelId) {
    if (levelId < 1 || levelId > levels.length) return null;
    final level = levels[levelId - 1];
    return level.levelId == levelId
        ? level
        : levels.cast<CampaignLevel?>().firstWhere(
              (l) => l?.levelId == levelId,
              orElse: () => null,
            );
  }

  Map<String, dynamic> toJson() => {
        'catalogVersion': catalogVersion,
        'generatorVersion': generatorVersion,
        'levelCount': levels.length,
        'levels': [for (final level in levels) level.toJson()],
      };

  static Campaign fromJson(Map<String, dynamic> json) => Campaign(
        catalogVersion: json['catalogVersion'] as int,
        generatorVersion: json['generatorVersion'] as int,
        levels: [
          for (final raw in json['levels'] as List)
            CampaignLevel.fromJson(raw as Map<String, dynamic>),
        ],
      );
}

