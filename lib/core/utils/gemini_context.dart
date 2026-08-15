// Allègement de l'historique de conversation Gemini (`contents`).
//
// L'API refacture l'INTÉGRALITÉ de `contents` à chaque tour : sans allègement,
// une longue discussion brûle le quota gratuit puis finit par dépasser la
// fenêtre du modèle.
//
// Contrainte à ne jamais violer : le protocole exige une `functionResponse`
// pour CHAQUE `functionCall`. Couper au milieu d'une paire rend tout le fil
// invalide (HTTP 400), donc on ne coupe qu'à une frontière sûre.

import 'dart:convert';

/// Budget par défaut, en caractères de JSON encodé.
const int kMaxContextChars = 60000;

/// Nombre d'entrées de fin laissées strictement intactes.
const int kKeepIntact = 10;

/// Longueur au-delà de laquelle un résultat d'outil ancien est abrégé.
const int kOldToolResultMax = 400;

int contextChars(List<Map<String, dynamic>> contents) =>
    jsonEncode(contents).length;

/// Réduit [contents] **en place** sous [maxChars], en deux temps :
///
/// 1. abrège les gros résultats d'outils anciens — YAML de config et contenus
///    de fichiers G-code pèsent l'essentiel du contexte, alors que l'agent
///    peut toujours rappeler l'outil s'il a de nouveau besoin du détail ;
/// 2. si c'est encore trop, coupe la tête à une frontière sûre.
void compactGeminiContents(
  List<Map<String, dynamic>> contents, {
  int maxChars = kMaxContextChars,
  int keepIntact = kKeepIntact,
  int toolResultMax = kOldToolResultMax,
}) {
  if (contextChars(contents) <= maxChars) return;

  final cut = contents.length - keepIntact;
  for (var i = 0; i < cut; i++) {
    final parts = contents[i]['parts'];
    if (parts is! List) continue;
    contents[i] = {
      ...contents[i],
      'parts': parts.map((p) => shrinkPart(p, toolResultMax)).toList(),
    };
  }

  while (contextChars(contents) > maxChars) {
    final index = safeCutIndex(contents, keepIntact);
    if (index <= 0) break;
    contents.removeRange(0, index);
  }
}

/// Abrège un `functionResponse` volumineux ; laisse tout le reste intact.
Object? shrinkPart(Object? part, [int maxLen = kOldToolResultMax]) {
  if (part is! Map) return part;
  final call = part['functionResponse'];
  if (call is! Map) return part;
  final response = (call['response'] as Map?)?.cast<String, dynamic>();
  final result = response?['result'];
  if (result is! String || result.length <= maxLen) return part;
  return {
    'functionResponse': {
      'name': call['name'],
      'response': {
        'result': '${result.substring(0, maxLen)}'
            '…[abrégé — ${result.length} caractères ; rappelle l\'outil si tu '
            'as besoin du détail]',
      },
    },
  };
}

/// Premier index où couper sans casser une paire appel/réponse : un message
/// utilisateur qui ne porte **pas** de `functionResponse`. Retourne 0 si aucune
/// frontière sûre n'existe (on préfère un contexte trop gros à un fil invalide).
int safeCutIndex(List<Map<String, dynamic>> contents,
    [int keepIntact = kKeepIntact]) {
  for (var i = 1; i < contents.length - keepIntact; i++) {
    final entry = contents[i];
    if (entry['role'] != 'user') continue;
    final parts = entry['parts'];
    if (parts is! List) continue;
    if (parts.any((p) => p is Map && p.containsKey('functionResponse'))) {
      continue;
    }
    return i;
  }
  return 0;
}
