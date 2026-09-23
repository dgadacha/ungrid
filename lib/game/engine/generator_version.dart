/// Version du générateur.
///
/// Un couple (version, seed) doit produire exactement le même puzzle, partout
/// et toujours : aujourd'hui, après une mise à jour, sur iOS comme sur
/// Android. C'est ce qui permet de publier une solution en vidéo, de comparer
/// deux joueurs, et de reproduire un bug.
///
/// Toute modification du générateur qui change le board produit par une seed
/// déjà publiée exige une nouvelle version. On ne retouche jamais la
/// précédente : les niveaux déjà parus continuent d'utiliser la leur.
const int currentGeneratorVersion = 2;
