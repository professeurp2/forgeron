# speech_to_text_windows — copie corrigée pour Forgeron

Base : `speech_to_text_windows` 1.0.1 (pub.dev, licence BSD-3, voir `LICENSE`),
dernière version publiée au 29 octobre 2026. Branchée par
`dependency_overrides` dans `pubspec.yaml`.

Défaut constaté : sur Windows, le micro s'activait mais rien ne remontait quand
on parlait. Avec Flutter 3.41, `GetTaskRunner()` n'existe pas dans le wrapper
C++ : le plugin envoyait donc les résultats à Dart **directement depuis son fil
d'arrière-plan**, ce que Flutter n'accepte pas. Il créait aussi les objets SAPI
sur un fil et les interrogeait depuis un autre, sans y initialiser COM.

Corrections (seulement `windows/speech_to_text_windows_plugin.{h,cpp}`) :

- tous les objets SAPI vivent sur un fil dédié, COM initialisé (MTA), réveillé
  par l'évènement de notification de SAPI au lieu d'une boucle d'attente ;
- les messages vers Dart sont mis en file et envoyés depuis le **fil principal**,
  via un message de fenêtre (`RegisterTopLevelWindowProcDelegate`) ;
- le texte reconnu est échappé dans le JSON (un guillemet cassait le message) ;
- la langue renvoyée par `locales` est celle du reconnaisseur installé (fr-FR
  sur le poste de l'atelier), plus la liste en dur « en-US / en-GB » ;
- les phrases d'une même écoute s'accumulent, et la transcription complète part
  comme résultat final à l'arrêt.

La partie Dart (`lib/`) est inchangée.
