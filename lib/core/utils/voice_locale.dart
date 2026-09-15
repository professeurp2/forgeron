/// Rapprochement d'une langue souhaitée avec ce que l'appareil sait
/// réellement écouter (`speech_to_text`) ou prononcer (`flutter_tts`).
///
/// Nécessaire parce qu'aucune des deux listes n'est garantie : un téléphone
/// donné n'a que les voix installées, et les langues peu dotées manquent
/// souvent. Plutôt que de figer `fr_FR` partout, on cherche la meilleure
/// correspondance et on laisse l'appelant décider quoi faire d'un `null`
/// (typiquement : prévenir l'opérateur, sans casser le chat écrit).
library;

String _normalize(String tag) => tag.trim().toLowerCase().replaceAll('_', '-');

String _languageOf(String tag) => _normalize(tag).split('-').first;

/// Meilleure correspondance de [wanted] parmi [available], dans l'ordre :
/// étiquette exacte, puis même langue quelle que soit la région, puis chaque
/// entrée de [fallbacks] selon la même règle. Retourne l'identifiant tel
/// qu'il figure dans [available] (donc dans la graphie attendue par le
/// plugin : `fr_FR` pour la dictée, `fr-FR` pour la synthèse), ou `null` si
/// la langue est introuvable.
String? bestVoiceLocale(
  String wanted,
  Iterable<String> available, {
  List<String> fallbacks = const [],
}) {
  final options = available.where((e) => e.trim().isNotEmpty).toList();
  if (options.isEmpty) return null;

  for (final candidate in [wanted, ...fallbacks]) {
    if (candidate.trim().isEmpty) continue;
    final target = _normalize(candidate);

    for (final option in options) {
      if (_normalize(option) == target) return option;
    }

    final language = _languageOf(candidate);
    for (final option in options) {
      if (_languageOf(option) == language) return option;
    }
  }
  return null;
}
