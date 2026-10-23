import 'dart:convert';

/// Empreinte FNV-1a 64 bits, en hexadécimal (16 caractères).
///
/// Sert à NOMMER un prompt, un catalogue d'outils ou un jeu de scénarios : pas
/// à protéger quoi que ce soit, juste à savoir si deux journaux ou deux
/// rapports parlent de la même chose. Stable d'une plateforme à l'autre.
String fingerprint(String s) {
  final prime = BigInt.parse('1099511628211');
  final mask = (BigInt.one << 64) - BigInt.one;
  var h = BigInt.parse('14695981039346656037');
  for (final b in utf8.encode(s)) {
    h ^= BigInt.from(b);
    h = (h * prime) & mask;
  }
  return h.toRadixString(16).padLeft(16, '0');
}
