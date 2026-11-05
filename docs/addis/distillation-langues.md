# Distillation : un modèle local qui parle les langues africaines

Décision du 5 nov. 2026 (validée par le porteur du projet) : entraîner le
modèle local (Qwen) sur des réponses d'un modèle « professeur » plus fort,
pour les 15 langues africaines de l'application, pas seulement le bambara.

Pourquoi : dans l'atelier, hors ligne, Qwen 2.5 7B écrit des phrases sans
sens en bambara (« Dabila daminɛ. Mɛnɛ, masini cogoya fo in ye. Joona
joona. ») en recombinant les mots du glossaire. Les filtres de sortie
ajoutés depuis rattrapent chaque phrase connue, pas la suivante. Gemini, en
ligne, répond correctement. Le matériel (RTX 3070 Laptop, 8 Go de VRAM,
15,6 Go de RAM) ne permet pas un modèle local beaucoup plus gros.

## ⚠️ Point à trancher avant d'utiliser Gemini comme professeur

Les conditions additionnelles de l'API Gemini (version en vigueur au
23 mars 2026, section *Use Restrictions*) interdisent :

- d'utiliser les Services pour développer des modèles qui leur font
  concurrence ;
- de tenter de répliquer un composant des Services, y compris les données
  ou les modèles sous-jacents.

Entraîner Qwen sur des réponses de Gemini peut tomber sous ces clauses.
C'est une question juridique, à trancher par le porteur du projet (relire
le texte, éventuellement interroger Google ou l'encadrement), pas par
l'outil. En attendant, le générateur refuse Gemini comme professeur tant
que `DISTILL_CGU_GEMINI=decision-du-porteur` n'est pas posé.

Pistes si la réponse est non :

| Professeur | Licence | Langues africaines | Remarque |
|---|---|---|---|
| Gemini | clause ci-dessus | bon (constat atelier) | meilleur professeur, risque juridique |
| Modèles ouverts (Qwen3, etc.) | à vérifier modèle par modèle | faible | les essais du 23 oct. et du 5 nov. le montrent |
| Gemma 3 | conditions Gemma : une version récente semble encadrer la distillation, **à vérifier** | moyen (140 langues annoncées) | le 27B ne tient pas sur ce PC |
| Textes écrits par des humains sous licence ouverte (jeux de données publics) | à vérifier par jeu | variable | pas de professeur : les meilleures données, mais peu sur la CNC |

Aucune de ces licences n'a été lue en entier ici : chacune est à vérifier
avant usage.

## La chaîne

1. **Corpus** — `tool/distill/generer_corpus_test.dart` (fait, voir plus bas).
2. **Relecture** — un échantillon par langue relu par un locuteur, ou un
   juge plus fort que le professeur. Indispensable, voir les résultats.
3. **Entraînement** — QLoRA (adaptateur LoRA sur le modèle quantifié en
   4 bits) de Qwen 2.5 7B : tient dans 8 Go de VRAM. Rien n'est installé
   pour l'instant (pas de PyTorch ni d'Unsloth/TRL sur ce PC ; 65 Go
   libres sur C:).
4. **Déploiement** — fusion, conversion GGUF, nouveau modèle Ollama
   (`forgeron-qwen-afr`), sans remplacer `forgeron-qwen` avant d'avoir
   mesuré.
5. **Mesure** — `tool/eval/conversation_langues_test.dart` (langue des
   réponses) et Forgeron-Bench (appels d'outils), avant et après.
   L'entraînement ne doit pas faire perdre les appels d'outils en
   français : mélanger au corpus des exemples français/anglais.

## Le générateur de corpus

Le professeur répond à la place du modèle local **dans le vrai agent**
(`AiAgentController`) : l'élève apprend sur exactement ce qu'il recevra dans
l'application (prompt construit pour le modèle local, outils des
spécialistes, historique compacté à son budget, résultats d'outils de la
machine simulée). Chaque appel au modèle devient un exemple au format
`messages` + `tools`.

- Graines : `tool/distill/graines_fr.json`, 29 phrases françaises sur ce que
  le lexique fermé ne couvre pas (converser, expliquer, guider, sécurité,
  limites). Le professeur les traduit dans chaque langue (traductions
  **non relues**, en cache dans `distill_data/`).
- Les cartes de confirmation sont refusées : le corpus n'apprend pas à
  l'élève qu'une action a eu lieu.
- Rejets automatiques : réponse vide, chinois, restes de gabarit
  (`/think`), boucle, salade de glossaire, dérive vers le français ou
  l'anglais, autre langue africaine, lettres étrangères à l'orthographe de
  la langue (ɛ/ɔ en haoussa…), donnée machine absente de tout ce que le
  professeur a reçu (« X0 », « 12 mm »), lecture de la machine demandée
  mais jamais faite.
- Sorties dans `distill_data/` (ignoré par git) : `corpus_*.jsonl`,
  `rejets_*.jsonl`, `rapport_*.md`.

```
$env:DISTILL_TEACHER='ollama:forgeron-qwen3-8b-nothink'   # ou gemini:<modèle>
$env:DISTILL_LANGS='sw,ha'        # défaut : les 15 langues africaines
flutter test tool/distill/generer_corpus_test.dart --reporter expanded
```

## Essai du 5 nov. 2026 (professeur local, pour tester la chaîne)

`gemma3n` ne peut pas servir de professeur : Ollama refuse les outils pour
ce modèle (« does not support tools »). Essai avec
`forgeron-qwen3-8b-nothink`, 4 graines, swahili et haoussa :

| Langue | Acceptés | Rejetés | Sans modèle |
|---|---|---|---|
| sw | 2 | 1 | 1 |
| ha | 0 | 4 | 0 |

Rejets : dérive vers le français (3), lecture machine non faite (2), reste
`/think` (1), lettres bambara dans du haoussa (1).

**Ce que l'essai apprend** : les filtres attrapent l'absurde visible, pas
le faux fluide. Les deux réponses swahili acceptées sont des phrases bien
formées mais sans sens (« Homing ni maelekezo ya kuzalisha maktaba ya
mafuta… »). La qualité du corpus dépend donc d'abord du professeur, et
l'étape 2 (relecture ou juge) n'est pas facultative : sans elle, on
graverait dans l'élève les erreurs du professeur.
