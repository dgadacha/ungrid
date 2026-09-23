import '../models/level.dart';

/// Empreinte d'un niveau : de quoi vérifier qu'il est bien celui attendu.
///
/// Le catalogue ne stocke qu'une seed ; le board, lui, est reconstruit à
/// l'ouverture. L'empreinte compare ce qu'on obtient à ce qui était prévu, et
/// signale immédiatement une régression du générateur — un niveau publié qui
/// ne serait plus le même casserait les solutions partagées.
class LevelFingerprint {
  const LevelFingerprint._();

  /// Représentation canonique d'un niveau.
  ///
  /// Tout y est trié : deux boards identiques donnent forcément le même texte,
  /// quel que soit l'ordre dans lequel blocs et tuiles ont été construits.
  ///
  /// Les tuiles d'arrêt en font partie : deux boards aux mêmes blocs mais aux
  /// tuiles différentes ne se jouent pas pareil, et ne doivent donc pas
  /// partager une empreinte.
  static String canonical(Level level) {
    final blocks = [
      for (final block in level.blocks)
        '${block.x},${block.y},${block.direction.code}',
    ]..sort();
    final tiles = [for (final tile in level.stopTiles) '${tile.x},${tile.y}']
      ..sort();

    final rotation = level.rotationTiles.isEmpty
        ? ''
        : '|R:${([for (final p in level.rotationTiles) '${p.x},${p.y}']..sort()).join(';')}';
    return 'G:${level.columns}x${level.rows}'
        '|B:${blocks.join(';')}'
        '|S:${tiles.join(';')}'
        '$rotation'
        '${level.fragileStopTiles.isEmpty ? '' : '|F:${([for (final p in level.fragileStopTiles) '${p.x},${p.y}']..sort()).join(';')}'}';
  }

  /// Empreinte courte et stable, en hexadécimal.
  ///
  /// FNV-1a 64 bits : court à écrire, sans dépendance, et largement assez sûr
  /// pour ce qu'on lui demande — repérer un board qui a changé, pas résister à
  /// une attaque.
  static String of(Level level) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;

    var hash = offset;
    for (final unit in canonical(level).codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    // Les entiers Dart sont signés sur 64 bits : on écrit les deux moitiés
    // séparément, sans quoi une empreinte sur deux s'afficherait avec un moins
    // devant.
    final high = (hash >> 32) & 0xFFFFFFFF;
    final low = hash & 0xFFFFFFFF;
    return high.toRadixString(16).padLeft(8, '0') +
        low.toRadixString(16).padLeft(8, '0');
  }
}
