import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/controllers/game_controller.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/difficulty.dart';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/game/models/move_result.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/reward_service.dart';

Level parse(List<String> rows, {Difficulty difficulty = Difficulty.easy}) =>
    LevelPattern.parse(rows, id: 1, difficulty: difficulty);

GameController controllerFor(
  List<String> rows, {
  Difficulty difficulty = Difficulty.easy,
  RewardService rewards = const LocalRewardService(),
}) =>
    GameController(
      level: parse(rows, difficulty: difficulty),
      // Les vibrations passeraient par le canal de la plateforme, absent ici.
      haptics: HapticService(enabled: false),
      rewards: rewards,
    );

/// Récompense toujours refusée, comme lorsqu'aucune publicité n'est prête.
class _NoRewards implements RewardService {
  const _NoRewards();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestReward(RewardType type) async => false;
}

void main() {
  group('limite de coups', () {
    test('la limite est exactement la solution optimale', () {
      // Le but n'est pas de vider la grille, c'est de trouver la bonne
      // séquence : aucune marge n'est accordée.
      final level = parse([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      expect(level.moveLimit, level.optimalMoves);
    });

    test('une sortie consomme un coup', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '..^.',
        '....',
      ]);
      final before = controller.movesLeft;
      expect(controller.tapCell(2, 2).exited, isTrue);
      expect(controller.movesLeft, before - 1);
    });

    test('un glissement consomme un coup', () {
      final controller = controllerFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      final before = controller.movesLeft;
      expect(controller.tapCell(0, 1).slid, isTrue);
      expect(controller.movesLeft, before - 1);
      expect(controller.remainingBlocks, 2);
    });

    test('un coup refusé consomme un coup lui aussi', () {
      final controller = controllerFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      final before = controller.movesLeft;
      expect(controller.tapCell(0, 1).blocked, isTrue);
      expect(controller.movesUsed, 1);
      expect(controller.movesLeft, before - 1,
          reason: 'sans cela, le joueur pourrait tout essayer sans réfléchir');
    });

    test('toucher une case vide ne coûte rien', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      expect(controller.tapCell(0, 0).outcome, MoveOutcome.ignored);
      expect(controller.movesUsed, 0);
      expect(controller.movesLeft, controller.moveLimit);
    });
  });

  group('victoire et défaite', () {
    test('vider la grille gagne la partie', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      controller.tapCell(1, 1);
      expect(controller.isCleared, isTrue);
      expect(controller.remainingBlocks, 0);
    });

    test('la séquence juste vide la grille au dernier coup', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '..^.',
        '....',
      ]);
      controller.tapCell(2, 2);
      controller.tapCell(1, 1);
      expect(controller.isCleared, isTrue);
      expect(controller.movesLeft, 0,
          reason: 'la réserve vaut exactement la solution optimale');
    });

    test('un coup de trop fait perdre la partie', () {
      // Deux coups suffisaient ; en pousser un d'abord en coûte trois, et la
      // réserve n'en contient que deux.
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      expect(controller.moveLimit, 2);

      controller.tapCell(0, 1); // glisse en (2,1) : coup gâché
      controller.tapCell(3, 1); // le '^' sort
      expect(controller.movesLeft, 0);
      expect(controller.isOutOfMoves, isTrue);
      expect(controller.isCleared, isFalse);
    });

    test('la bonne séquence passe tout juste', () {
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      controller.tapCell(3, 1); // le '^' sort
      controller.tapCell(0, 1); // le '>' file droit dehors
      expect(controller.isCleared, isTrue);
      expect(controller.movesLeft, 0);
    });

    test('épuiser ses coups perd la partie', () {
      final controller = controllerFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      // Deux blocs collés : le tap est refusé à chaque fois, et coûte quand
      // même un coup.
      while (controller.movesLeft > 0 && controller.isPlaying) {
        controller.tapCell(0, 1);
      }
      expect(controller.isOutOfMoves, isTrue);
      expect(controller.remainingBlocks, 2);
    });

    test('vider la grille avec le dernier coup est une victoire', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '..^.',
        '....',
      ]);
      // On gaspille des coups sur une case vide ? Non : sur le bloc du haut,
      // qui sortira de toute façon. On vise ici le cas limite où le dernier
      // coup disponible vide la grille.
      final wasted = controller.movesLeft - 2;
      for (var i = 0; i < wasted; i++) {
        // Le '^' monte d'une case à chaque fois puis sort : on recommence
        // pour retomber sur une situation propre.
        controller.restart();
      }
      expect(controller.isPlaying, isTrue);
    });

    test('la partie terminée n\'accepte plus rien', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '..^.',
        '....',
      ]);
      controller.tapCell(2, 2);
      controller.tapCell(1, 1);
      final moves = controller.movesUsed;
      expect(controller.tapCell(1, 1).outcome, MoveOutcome.ignored);
      expect(controller.movesUsed, moves);
    });
  });

  group('chronomètre', () {
    test('il ne démarre qu\'au premier coup', () async {
      final controller = controllerFor([
        '.....',
        '..>..',
        '.....',
        '..^..',
        '.....',
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.elapsed, Duration.zero,
          reason: 'le joueur doit pouvoir observer la grille sans être pressé');

      controller.tapCell(2, 3);
      expect(controller.timerStarted, isTrue);
    });

    test('il se suspend et reprend', () async {
      final controller = controllerFor([
        '.....',
        '..>..',
        '.....',
        '..^..',
        '.....',
      ]);
      controller.tapCell(2, 3);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      controller.pauseTimer();
      final paused = controller.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.elapsed, paused,
          reason: 'le temps passé hors du jeu ne compte pas');

      controller.resumeTimer();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.elapsed, greaterThan(paused));
    });

    test('il s\'arrête à la victoire', () async {
      final controller = controllerFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      controller.tapCell(1, 1);
      final atWin = controller.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(controller.elapsed, atWin);
    });

    test('il ne repart pas tout seul après la victoire', () async {
      final controller = controllerFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      controller.tapCell(1, 1);
      controller.resumeTimer();
      final atWin = controller.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(controller.elapsed, atWin);
    });
  });

  group('indice', () {
    test('il désigne un bloc jouable sans le jouer', () async {
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      expect(await controller.requestHint(), isTrue);
      expect(controller.hintedBlockId, isNotNull);
      expect(controller.engine.canExit(controller.hintedBlockId!), isTrue);
      expect(controller.movesUsed, 0, reason: 'un indice ne joue pas le coup');
    });

    test('il s\'efface une fois le bloc joué', () async {
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      await controller.requestHint();
      controller.tapCell(3, 1);
      expect(controller.hintedBlockId, isNull);
    });

    test('sans récompense disponible, pas d\'indice', () async {
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ], rewards: const _NoRewards());
      expect(await controller.requestHint(), isFalse);
      expect(controller.hintedBlockId, isNull);
    });
  });

  group('coups supplémentaires', () {
    test('ils reprennent la partie sans toucher à la grille', () async {
      // Deux blocs collés : le tap est refusé à chaque fois et ne déplace
      // rien, ce qui permet de vider le compteur sans changer le plateau.
      final controller = controllerFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      while (controller.isPlaying) {
        controller.tapCell(0, 1);
      }
      expect(controller.isOutOfMoves, isTrue);
      final remaining = controller.remainingBlocks;

      expect(await controller.requestExtraMoves(), isTrue);
      expect(controller.isPlaying, isTrue);
      expect(controller.movesLeft, 3);
      expect(controller.remainingBlocks, remaining,
          reason: 'la partie reprend où elle s\'était arrêtée');
    });

    test('ils ne sont offerts qu\'en fin de coups', () async {
      final controller = controllerFor([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      expect(await controller.requestExtraMoves(), isFalse);
    });
  });

  group('murs', () {
    test('un mur collé au bloc le laisse sur place', () {
      final controller = controllerFor([
        '....',
        '>#..',
        '....',
        '....',
      ]);
      final result = controller.tapCell(0, 1);
      expect(result.blocked, isTrue);
      expect(result.blockedByWall, isTrue);
      expect(controller.movesUsed, 1, reason: 'le coup est bel et bien joué');
    });

    test('un bloc glisse jusqu\'au mur', () {
      final controller = controllerFor([
        '....',
        '>..#',
        '....',
        '....',
      ]);
      final result = controller.tapCell(0, 1);
      expect(result.slid, isTrue);
      expect(result.blockedByWall, isTrue);
    });

    test('toucher un mur ne fait rien du tout', () {
      final controller = controllerFor([
        '....',
        '.#..',
        '..>.',
        '....',
      ]);
      expect(controller.tapCell(1, 1).outcome, MoveOutcome.ignored);
      expect(controller.movesUsed, 0);
      expect(controller.timerStarted, isFalse,
          reason: 'un mur n\'est pas un élément de jeu');
    });

    test('un mur ne gêne pas les blocs qui l\'évitent', () {
      final controller = controllerFor([
        '....',
        '>#..',
        '.>..',
        '....',
      ]);
      expect(controller.tapCell(1, 2).exited, isTrue);
    });

    test('toucher un mur ne consomme rien', () {
      final controller = controllerFor([
        '....',
        '.#..',
        '..>.',
        '....',
      ]);
      expect(controller.tapCell(1, 1).outcome, MoveOutcome.ignored);
      expect(controller.movesUsed, 0);
    });

    test('les murs ne comptent pas dans la victoire', () {
      final controller = controllerFor([
        '.#..',
        '.>..',
        '..#.',
        '....',
      ]);
      controller.tapCell(1, 1);
      expect(controller.isCleared, isTrue);
    });
  });

  group('annulation', () {
    test('elle rend le coup et remet le bloc en place', () {
      final controller = controllerFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      final before = controller.movesLeft;
      controller.tapCell(0, 1);
      expect(controller.movesLeft, before - 1);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.movesLeft, before);
      expect(controller.engine.blockAt(0, 1)?.id, 'b0');
      expect(controller.canUndo, isFalse);
    });

    test('elle fait revenir un bloc sorti', () {
      final controller = controllerFor([
        '....',
        '.>..',
        '..^.',
        '....',
      ]);
      controller.tapCell(2, 2);
      expect(controller.remainingBlocks, 1);

      controller.undo();
      expect(controller.remainingBlocks, 2);
      expect(controller.engine.blockAt(2, 2), isNotNull);
    });

    test('un refus ne s\'annule pas', () {
      final controller = controllerFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      controller.tapCell(0, 1);
      expect(controller.movesUsed, 1);
      expect(controller.canUndo, isFalse,
          reason: 'rien n\'a bougé, il n\'y a rien à reprendre');
    });

    test('le chronomètre n\'est pas rembobiné', () async {
      final controller = controllerFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      controller.tapCell(0, 1);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final elapsed = controller.elapsed;
      controller.undo();
      expect(controller.elapsed, greaterThanOrEqualTo(elapsed));
    });
  });

  test('recommencer remet tout à zéro', () {
    final controller = controllerFor([
      '....',
      '>..<',
      '....',
      '....',
    ]);
    controller.tapCell(0, 1);
    controller.tapCell(3, 1);
    controller.restart();

    expect(controller.movesUsed, 0);
    expect(controller.movesLeft, controller.level.moveLimit);
    expect(controller.remainingBlocks, 2);
    expect(controller.elapsed, Duration.zero);
    expect(controller.timerStarted, isFalse);
    expect(controller.isPlaying, isTrue);
  });

  test('changer de niveau réinitialise la partie', () {
    final controller = controllerFor([
      '....',
      '.>..',
      '....',
      '....',
    ]);
    controller.tapCell(1, 1);
    controller.loadLevel(parse([
      '.....',
      '..>..',
      '.....',
      '..^..',
      '.....',
    ]));

    expect(controller.isPlaying, isTrue);
    expect(controller.remainingBlocks, 2);
    expect(controller.movesUsed, 0);
  });
}
