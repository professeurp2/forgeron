# speech_to_text_windows — copie corrigée pour Forgeron

Base : `speech_to_text_windows` 1.0.1 (pub.dev, licence BSD-3, voir `LICENSE`),
dernière version publiée au 29 octobre 2026. Branchée par
`dependency_overrides` dans `pubspec.yaml`. La partie Dart (`lib/`) est
inchangée ; seul `windows/` a été réécrit.

## Ce qui ne marchait pas

Sur le poste de l'atelier, le micro s'activait mais rien ne remontait quand on
parlait. Trois causes, établies une par une :

1. **Résultats envoyés depuis le mauvais fil.** Avec Flutter 3.41, le wrapper
   C++ n'a pas `GetTaskRunner()` : le plugin envoyait les résultats à Dart
   directement depuis son fil d'arrière-plan, ce que Flutter n'accepte pas.
2. **Dictée refusée dans le processus de l'application.**
   `SetDictationState` y échouait avec `0x88890008`
   (`AUDCLNT_E_UNSUPPORTED_FORMAT`), quelle que soit l'entrée audio (objet
   brut, entrée par défaut, format 16 kHz imposé). Le **même code, dans un
   processus à part**, démarre et transcrit, y compris pendant que
   l'application tourne (sonde du 29 octobre 2026). La cause exacte à
   l'intérieur du processus n'est pas identifiée.
3. **Échec silencieux.** L'original ignorait cet échec : `listen` répondait
   « faux » sans erreur, d'où « rien ne se passe ».

## Ce qui a changé

- La dictée SAPI tourne dans `forgeron_dictation.exe` (`dictation_helper.cpp`),
  construit avec le plugin et copié à côté de l'application. Le plugin le lance
  à l'initialisation et dialogue avec lui par ses flux (commandes `START`,
  `STOP`, `QUIT` ; évènements `READY`, `LISTENING`, `HYPO`, `RECO`, `SOUND`,
  `STOPPED`, `ERR`). Le programme s'arrête de lui-même si l'application se
  ferme ou plante.
- Les messages vers Dart partent du **fil principal**, via un message de
  fenêtre (`RegisterTopLevelWindowProcDelegate`).
- Un échec de démarrage de la dictée est signalé (`error_audio_error`).
- Le texte reconnu est échappé dans le JSON.
- La langue renvoyée par `locales` est celle du reconnaisseur installé (fr-FR
  sur le poste), plus la liste en dur « en-US / en-GB ».
- Les phrases d'une même écoute s'accumulent ; la transcription complète part
  comme résultat final à l'arrêt.

Vérifié dans l'application : clic sur le micro, phrase prononcée, texte écrit
dans le champ de saisie, puis conservé à l'arrêt.
