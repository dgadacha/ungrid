/// Ce que le joueur peut débloquer contre une publicité.
enum RewardType {
  /// Désigner le bloc à jouer.
  hint,

  /// Trois coups de plus pour reprendre la partie perdue.
  extraMoves,

  /// Une annulation de plus, une fois la gratuite dépensée.
  undo,
}

/// Accès aux récompenses.
///
/// La régie publicitaire n'est pas branchée : cette abstraction existe pour
/// que le jeu soit déjà écrit comme si elle l'était. Le jour où AdMob arrive,
/// il suffit d'une implémentation de plus, sans toucher au gameplay.
abstract class RewardService {
  /// `false` quand aucune publicité n'est disponible : l'interface masque
  /// alors l'action plutôt que de proposer un bouton mort.
  bool get isAvailable;

  /// Demande la récompense. Retourne `true` si elle est accordée.
  ///
  /// L'appelant met la partie en pause avant, et la reprend après : le temps
  /// passé devant une publicité ne doit pas compter dans le chronomètre.
  Future<bool> requestReward(RewardType type);
}

/// Implémentation de développement : accorde tout, immédiatement.
///
/// Elle permet de jouer et de tester indice et coups supplémentaires tant que
/// la régie n'est pas en place. À remplacer, pas à garder en production.
class LocalRewardService implements RewardService {
  const LocalRewardService();

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestReward(RewardType type) async => true;
}
