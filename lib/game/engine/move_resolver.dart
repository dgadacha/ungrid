import 'dart:typed_data';

import '../models/move_result.dart';

/// Case libre.
const int cellEmpty = 0;

/// Un bloc occupe la case.
const int cellOccupied = 1;

/// La case porte une tuile d'arrêt.
const int cellStopTile = 2;

/// Ce qu'un glissement produit, avant toute mise à jour du plateau.
typedef SlideOutcome = ({
  MoveOutcome outcome,

  /// Cases parcourues. Zéro pour un refus.
  int distance,

  /// Case d'arrivée, `-1` si le bloc quitte la grille.
  int cell,
});

/// La règle du glissement, écrite une seule fois.
///
/// Le moteur et le solveur explorent le même jeu ; s'ils l'interprétaient
/// chacun de leur côté, la solution annoncée finirait par diverger de ce que
/// le joueur obtient — et rien ne le signalerait. Ils appellent donc tous deux
/// cette fonction, qui ne connaît ni objets ni état : une grille de drapeaux,
/// une case, une direction.
///
/// La grille est indexée `y * columns + x`, chaque case portant les drapeaux
/// [cellOccupied] et [cellStopTile].
class MoveResolver {
  const MoveResolver._();

  /// Fait glisser une case dans sa direction jusqu'à ce que quelque chose
  /// l'arrête.
  ///
  /// Trois choses peuvent l'arrêter, dans cet ordre de priorité :
  ///
  /// - **un bloc**, qui barre la case suivante — le bloc s'arrête avant lui,
  ///   ou ne bouge pas du tout si le voisin le touche déjà ;
  /// - **une tuile d'arrêt**, sur laquelle le bloc entre puis se pose ;
  /// - **le bord**, qu'il franchit.
  ///
  /// La tuile d'arrêt n'agit que sur un bloc qui *entre* dessus : celui qui
  /// démarre sur une tuile n'est pas retenu, sans quoi il ne repartirait
  /// jamais et la case deviendrait un piège.
  static SlideOutcome resolve({
    required int cell,
    required int stepX,
    required int stepY,
    required int columns,
    required int rows,
    required Uint8List cells,
  }) {
    var x = cell % columns;
    var y = cell ~/ columns;
    var distance = 0;

    while (true) {
      final nx = x + stepX;
      final ny = y + stepY;

      if (nx < 0 || ny < 0 || nx >= columns || ny >= rows) {
        return (outcome: MoveOutcome.exited, distance: distance, cell: -1);
      }

      final target = ny * columns + nx;
      if (cells[target] & cellOccupied != 0) {
        return distance == 0
            ? (outcome: MoveOutcome.blocked, distance: 0, cell: cell)
            : (
                outcome: MoveOutcome.slid,
                distance: distance,
                cell: y * columns + x,
              );
      }

      x = nx;
      y = ny;
      distance++;

      if (cells[target] & cellStopTile != 0) {
        return (
          outcome: MoveOutcome.stopped,
          distance: distance,
          cell: target,
        );
      }
    }
  }
}
