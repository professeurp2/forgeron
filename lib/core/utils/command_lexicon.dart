/// Compréhension de commandes par **lexique fermé** — multilingue,
/// déterministe, sans modèle ni réseau.
///
/// C'est la « porte d'entrée » de l'assistant (voir
/// `lib/application/services/command_understanding.dart`) : un énoncé que ce
/// moteur comprend n'a pas besoin du modèle, et un énoncé qu'il refuse pour de
/// bonnes raisons (négation, question) prive le modèle des outils qui agissent.
/// L'étude qui l'a motivé : `docs/addis/05-etude-comparative-langues-locales.md` ;
/// sa gouvernance (qui relit, comment une langue devient « relue ») :
/// `docs/lexique-gouvernance.md`.
///
/// **Principe.** Le moteur ne « comprend » aucune langue : il reconnaît des
/// mots qu'une personne a déclarés dans `assets/lexicon/lexique.json`
/// (« jɔ » = arrêter, « broche » = la broche…), les assemble en une action et
/// un objet, et en tire un appel d'outil. Ajouter une langue, c'est ajouter un
/// bloc de données qu'un locuteur peut relire — pas du code.
///
/// **Confiance.** Chaque langue porte un statut : `brouillon` (écrite sans
/// relecteur nommé) ou `relu` (un relecteur nommé, une date). Un énoncé n'est
/// [LexiconMatch.trusted] que si CHAQUE mot qui compte vient d'une langue
/// relue ; la politique de l'application (confirmation, autonomie) s'appuie
/// dessus — le moteur, lui, ne décide jamais d'exécuter quoi que ce soit.
///
/// **Il refuse plutôt que de deviner.** Tout ce qui sort de ce qu'il sait
/// vérifier rend un refus motivé, et l'appelant retombe alors sur le modèle (qui
/// a ses propres garde-fous) ou pose la question à l'opérateur :
/// - négation (« ne démarre pas la broche ») — jamais d'action à l'envers ;
/// - condition ou enchaînement (« après le homing », « et puis ») ;
/// - mot de direction qu'il ne sait pas interpréter (« recule ») — jamais un
///   signe deviné sur un déplacement ;
/// - question (« c'est quoi le homing ? ») — seule la lecture d'état est permise ;
/// - mots inconnus au-delà de la tolérance de l'action : 0 pour tout ce qui
///   déplace, allume ou pose une origine ; un peu plus pour la lecture et l'arrêt ;
/// - nombre ambigu entre deux langues chargées (« saba » : 3 en bambara, 7 en
///   swahili) — un mauvais nombre est un déplacement faux.
///
/// **Orthographe.** Les lettres africaines (ɛ, ɔ, ɲ, ŋ, ɓ, ɗ…) sont pliées sur
/// l'ASCII des deux côtés (lexique et saisie) : un clavier de téléphone qui n'a
/// pas « ɛ » écrit « e » et se fait comprendre quand même.
///
/// **Mots proches.** Une faute de frappe ou une erreur de dictée (une lettre
/// sur un mot de 6 à 9 lettres, deux au-delà) est tolérée, jamais sur un mot
/// court ni sur un nombre : « stop » et « step » ne se confondent pas, et
/// « duuru » (5) ne devient jamais « wooro » (6).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'fingerprint.dart' as fp;

/// Statut d'une langue dont un relecteur NOMMÉ a validé les mots.
const kLexiconReviewed = 'relu';

/// Statut d'une langue écrite sans relecteur nommé (le défaut).
const kLexiconDraft = 'brouillon';

/// Version du FORMAT de `lexique.json` que ce moteur sait lire.
const kLexiconSchema = 1;

// ── Pliage orthographique ──────────────────────────────────────────────────

const Map<String, String> _foldMap = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ɛ': 'e', 'ẹ': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ɔ': 'o', 'ọ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ń': 'n', 'ṣ': 's', 'š': 's',
  'ɲ': 'ny', 'ŋ': 'ng', 'ɓ': 'b', 'ɗ': 'd', 'ƙ': 'k', 'œ': 'oe', 'æ': 'ae',
};

// Signes combinants (accents décomposés), voyelles brèves et allongement arabes.
final RegExp _marks = RegExp('[̀-ًͯ-ٟـ]');
final RegExp _quotes = RegExp('[\'’ʼ`´]');
final RegExp _dashes = RegExp('[−–—]');
final RegExp _tokenRe =
    RegExp(r'[-+]?\d+(?:[.,]\d+)?|[\p{L}\p{M}]+', unicode: true);

/// Minuscules, accents et lettres africaines pliés sur l'ASCII. Les écritures
/// non latines (arabe, éthiopien) sont conservées.
String foldWord(String s) {
  final b = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    b.write(_foldMap[ch] ?? ch);
  }
  return b.toString().replaceAll(_marks, '');
}

class _Tok {
  _Tok(this.raw, this.index)
      : word = foldWord(raw),
        number = RegExp(r'^[-+]?\d').hasMatch(raw)
            ? num.tryParse(raw.replaceAll(',', '.'))
            : null;
  final String raw;
  final String word;
  final int index;
  final num? number;
  bool get isNumber => number != null;
}

List<_Tok> _tokenize(String text) {
  final prepared =
      text.replaceAll(_quotes, ' ').replaceAll(_dashes, '-');
  final out = <_Tok>[];
  for (final m in _tokenRe.allMatches(prepared)) {
    out.add(_Tok(m.group(0)!, out.length));
  }
  return out;
}

/// Mots d'une expression du lexique tels que le moteur les lit (minuscules, pliés).
/// Sert au validateur : il doit compter ce que le moteur lira.
List<String> lexiconWords(String phrase) =>
    _tokenize(phrase).map((t) => t.word).toList();

// ── Mots proches ───────────────────────────────────────────────────────────

int _levenshtein(String a, String b, int cap) {
  if ((a.length - b.length).abs() > cap) return cap + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      rowMin = math.min(rowMin, cur[j]);
    }
    if (rowMin > cap) return cap + 1;
    prev = cur;
  }
  return prev[b.length];
}

/// Même mot, à une faute près pour 6 à 9 lettres, deux pour 10 et plus.
///
/// En mode [relaxed] (dictée, saisie très fautive) : une faute dès 5 lettres,
/// deux dès 7, trois dès 10 — jamais sur un mot de moins de 5 lettres (mesuré :
/// « sini » devenait « sigi » et une phrase sur la météo lisait l'état de la
/// machine). Un mode qui ne s'exécute JAMAIS sans confirmation à l'écran — voir
/// [LexiconMatch.relaxed].
bool _similar(String a, String b, {bool relaxed = false}) {
  if (a == b) return true;
  final m = math.min(a.length, b.length);
  final cap = relaxed
      ? (m >= 10 ? 3 : (m >= 7 ? 2 : (m >= 5 ? 1 : 0)))
      : (m >= 10 ? 2 : (m >= 6 ? 1 : 0));
  return cap > 0 && _levenshtein(a, b, cap) <= cap;
}

// ── Données du lexique ─────────────────────────────────────────────────────

class _Entry {
  _Entry(this.toks, this.role, this.value, this.lang);
  final List<String> toks;
  final String role;
  final String value;
  final String lang;

  String get label => '${toks.join(' ')} ($lang:$role${value.isEmpty ? '' : '/$value'})';
}

class _Numbers {
  _Numbers({
    required this.lang,
    required this.multiplierFirst,
    required this.units,
    required this.tens,
    required this.hundred,
    required this.thousand,
    required this.connectors,
    required this.tensPrefix,
    required this.quatreVingt,
  });

  final String lang;
  final bool multiplierFirst;
  final Map<String, int> units;
  final Map<String, int> tens;
  final Set<String> hundred;
  final Set<String> thousand;
  final Set<String> connectors;
  final String? tensPrefix;
  final bool quatreVingt;

  bool _starts(String w) =>
      units.containsKey(w) ||
      tens.containsKey(w) ||
      hundred.contains(w) ||
      thousand.contains(w) ||
      w == tensPrefix;

  /// Nombre écrit en lettres commençant en [start], ou `null`. Uniquement des
  /// mots exacts : un nombre ne se devine jamais.
  ({int value, int len})? parse(List<_Tok> toks, int start) {
    var total = 0;
    var cur = 0;
    var j = start;
    String? prev;
    bool word(int k) => k < toks.length && !toks[k].isNumber;

    if (multiplierFirst) {
      while (word(j)) {
        final w = toks[j].word;
        if (units.containsKey(w)) {
          cur += units[w]!;
        } else if (tens.containsKey(w)) {
          if (quatreVingt && (w == 'vingt' || w == 'vingts') && prev == 'quatre' && cur == 4) {
            cur = 80;
          } else {
            cur += tens[w]!;
          }
        } else if (hundred.contains(w)) {
          cur = (cur == 0 ? 1 : cur) * 100;
        } else if (thousand.contains(w)) {
          total += (cur == 0 ? 1 : cur) * 1000;
          cur = 0;
        } else {
          break;
        }
        prev = w;
        j++;
      }
      if (j == start) return null;
      return (value: total + cur, len: j - start);
    }

    // Le multiplicateur vient APRÈS le mot « cent » : « kɛmɛ saba » = 300,
    // « kɛmɛ ni saba » = 103.
    var any = false;
    var end = start;
    while (word(j)) {
      final w = toks[j].word;
      if (hundred.contains(w) || thousand.contains(w)) {
        final mult = hundred.contains(w) ? 100 : 1000;
        if (word(j + 1) && units.containsKey(toks[j + 1].word)) {
          total += mult * units[toks[j + 1].word]!;
          j += 2;
        } else {
          total += mult;
          j += 1;
        }
      } else if (w == tensPrefix) {
        if (word(j + 1) && units.containsKey(toks[j + 1].word)) {
          total += 10 * units[toks[j + 1].word]!;
          j += 2;
        } else {
          break;
        }
      } else if (tens.containsKey(w)) {
        total += tens[w]!;
        j += 1;
      } else if (units.containsKey(w)) {
        total += units[w]!;
        j += 1;
      } else if (connectors.contains(w) && any && word(j + 1) && _starts(toks[j + 1].word)) {
        j += 1;
        continue;
      } else {
        break;
      }
      any = true;
      end = j;
    }
    if (!any) return null;
    return (value: total, len: end - start);
  }
}

class _Intent {
  _Intent({
    required this.id,
    required this.tool,
    required this.args,
    required this.actions,
    required this.objects,
    required this.need,
    required this.slots,
    required this.readOnly,
    required this.alarmAlone,
    required this.tolerance,
  });

  final String id;
  final String tool;
  final Map<String, dynamic> args;
  final Set<String?> actions;
  final Set<String?> objects;
  final Set<String> need;
  final List<String> slots;
  final bool readOnly;
  final bool alarmAlone;
  final int tolerance;
}

class _Mark {
  _Mark(this.role, this.value, this.span, this.start,
      {this.number, this.candidates, this.langs});
  final String role;
  final String value;
  final int span;
  final int start;
  final num? number;

  /// Pour un nombre ambigu : langue → valeur.
  final Map<String, int>? candidates;

  /// Langues qui déclarent CE mot avec CE sens. `null` pour ce qui n'est à
  /// aucune langue (chiffres, nom d'axe, mot inconnu).
  final Set<String>? langs;
}

// ── Résultat ───────────────────────────────────────────────────────────────

/// Un appel d'outil déduit d'un énoncé.
class LexiconMatch {
  const LexiconMatch({
    required this.intent,
    required this.tool,
    this.args = const {},
    this.evidence = const [],
    this.relaxed = false,
    this.readOnly = false,
    this.trusted = false,
    this.languages = const [],
  });

  final String intent;
  final String tool;
  final Map<String, dynamic> args;

  /// L'intention ne fait que LIRE (état de la machine) : se tromper ne déplace
  /// rien, n'allume rien.
  final bool readOnly;

  /// Chaque mot qui compte vient d'une langue au statut `relu` (relecteur
  /// nommé). Faux dès qu'un seul mot vient d'un brouillon : le moteur ne dit
  /// pas quoi en faire, il dit seulement à quel point il peut être cru.
  final bool trusted;

  /// Langues dont viennent les mots reconnus (ex. `['bm', 'fr']` pour « broche
  /// daminɛ »), triées — pour dire à l'opérateur dans quelle langue il a été
  /// compris.
  final List<String> languages;

  /// Compris avec l'appariement SOUPLE (`interpret(…, relaxed: true)`) : c'est
  /// une **suggestion**, à montrer à l'opérateur en gros (« Arrêt ? », axe,
  /// distance, vitesse) et à ne JAMAIS exécuter sans son geste — y compris pour
  /// l'arrêt d'urgence, qui part sans confirmation quand il est compris sans
  /// réserve, mais pas sur une dictée douteuse.
  final bool relaxed;

  /// Ce qui a été reconnu, mot à mot — pour que l'opérateur (ou le relecteur)
  /// voie POURQUOI la machine a réagi.
  final List<String> evidence;

  @override
  String toString() => '$tool($args) [$intent]';
}

/// Soit un appel, soit un refus motivé. Jamais les deux.
class LexiconResult {
  const LexiconResult.match(LexiconMatch this.match) : refusal = null;
  const LexiconResult.refused(String this.refusal) : match = null;

  final LexiconMatch? match;
  final String? refusal;
}

// ── Le moteur ──────────────────────────────────────────────────────────────

/// Qui a relu une langue, et quand (`null` partout tant qu'elle est brouillon).
class LexiconReview {
  const LexiconReview({this.by, this.on});
  final String? by;
  final String? on;
}

class CommandLexicon {
  CommandLexicon._(
    this._entries,
    this._numbers,
    this._intents,
    this.languages,
    this.statuses, {
    required this.version,
    required this.fingerprint,
    required this.reviews,
    required Map<String, Map<String, String>> replies,
  }) : _replies = replies;

  /// Construit le moteur depuis `assets/lexicon/lexique.json`.
  factory CommandLexicon.fromJson(Map<String, dynamic> json) {
    final entries = <_Entry>[];
    final numbers = <_Numbers>[];
    final languages = <String>[];
    final statuses = <String, String>{};
    final reviews = <String, LexiconReview>{};
    final replies = <String, Map<String, String>>{};

    List<String> phrase(String s) => _tokenize(s).map((t) => t.word).toList();

    void add(String lang, String role, String value, Iterable<dynamic>? words) {
      for (final w in words ?? const []) {
        final toks = phrase('$w');
        if (toks.isNotEmpty) entries.add(_Entry(toks, role, value, lang));
      }
    }

    final langs = (json['languages'] as Map).cast<String, dynamic>();
    for (final lang in langs.keys) {
      final l = (langs[lang] as Map).cast<String, dynamic>();
      languages.add(lang);
      statuses[lang] = '${l['status'] ?? kLexiconDraft}';
      reviews[lang] = LexiconReview(
        by: l['reviewed_by'] as String?,
        on: l['reviewed_on'] as String?,
      );
      replies[lang] = {
        for (final e in ((l['replies'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      };
      for (final e in ((l['actions'] as Map?) ?? const {}).entries) {
        add(lang, 'action', '${e.key}', e.value as List);
      }
      add(lang, 'light', '', l['light'] as List?);
      for (final e in ((l['objects'] as Map?) ?? const {}).entries) {
        add(lang, 'object', '${e.key}', e.value as List);
      }
      add(lang, 'urgent', '', l['urgent'] as List?);
      add(lang, 'alarm', '', l['alarm'] as List?);
      add(lang, 'filler', '', l['fillers'] as List?);
      add(lang, 'neg', '', l['negations'] as List?);
      add(lang, 'cond', '', l['conditions'] as List?);
      add(lang, 'dir', '', l['directions'] as List?);
      add(lang, 'question', '', l['questions'] as List?);
      add(lang, 'feed', '', l['feed'] as List?);
      for (final e in ((l['units'] as Map?) ?? const {}).entries) {
        add(lang, 'unit', '${e.key}', e.value as List);
      }
      final n = l['numbers'] as Map?;
      if (n != null) {
        Map<String, int> ints(Object? m) => {
              for (final e in ((m as Map?) ?? const {}).entries)
                foldWord('${e.key}'): (e.value as num).toInt(),
            };
        Set<String> words(Object? m) =>
            {for (final w in ((m as List?) ?? const [])) foldWord('$w')};
        numbers.add(_Numbers(
          lang: lang,
          multiplierFirst: n['style'] != 'multiplier_after',
          units: ints(n['units']),
          tens: ints(n['tens']),
          hundred: words(n['hundred']),
          thousand: words(n['thousand']),
          connectors: words(n['connectors']),
          tensPrefix: n['tens_prefix'] == null ? null : foldWord('${n['tens_prefix']}'),
          quatreVingt: n['quatre_vingt'] == true,
        ));
      }
    }

    final intents = <_Intent>[];
    for (final raw in (json['intents'] as List)) {
      final m = (raw as Map).cast<String, dynamic>();
      intents.add(_Intent(
        id: '${m['id']}',
        tool: '${m['tool']}',
        args: ((m['args'] as Map?) ?? const {}).cast<String, dynamic>(),
        actions: {for (final a in (m['action'] as List)) a as String?},
        objects: {for (final o in (m['object'] as List)) o as String?},
        need: {for (final o in ((m['need'] as List?) ?? const [])) '$o'},
        slots: [for (final s in ((m['slots'] as List?) ?? const [])) '$s'],
        readOnly: m['read_only'] == true,
        alarmAlone: m['alarm_alone'] == true,
        tolerance: (m['tolerance'] as num?)?.toInt() ?? 0,
      ));
    }

    // Les phrases les plus longues d'abord : « segin a daminɛ yɔrɔ » (retour à
    // l'origine) doit l'emporter sur « daminɛ » (démarrer).
    entries.sort((a, b) => b.toks.length.compareTo(a.toks.length));
    return CommandLexicon._(
      entries,
      numbers,
      intents,
      languages,
      statuses,
      version: '${json['version'] ?? '0'}',
      // Sur le JSON ré-encodé, pas sur le texte du fichier : les fins de ligne
      // (CRLF sous Windows, LF ailleurs) ne doivent pas changer l'empreinte.
      fingerprint: fp.fingerprint(jsonEncode(json)),
      reviews: reviews,
      replies: replies,
    );
  }

  /// Construit le moteur depuis le TEXTE du fichier de données.
  factory CommandLexicon.fromJsonString(String source) =>
      CommandLexicon.fromJson(
          (jsonDecode(source) as Map).cast<String, dynamic>());

  final List<_Entry> _entries;
  final List<_Numbers> _numbers;
  final List<_Intent> _intents;
  final Map<String, Map<String, String>> _replies;

  /// Langues chargées.
  final List<String> languages;

  /// Statut de relecture par langue (`brouillon`, `relu`…).
  final Map<String, String> statuses;

  /// Version du contenu (`MAJEUR.MINEUR.CORRECTIF`) — change à chaque
  /// modification des données, voir `docs/lexique-gouvernance.md`.
  final String version;

  /// Empreinte du contenu : deux appareils qui ont la même comprennent pareil.
  /// Inscrite dans le journal de chaque tour, pour savoir QUEL lexique a
  /// compris un ordre.
  final String fingerprint;

  /// Relecteur et date par langue.
  final Map<String, LexiconReview> reviews;

  /// Vrai si les mots de [lang] ont été validés par un relecteur nommé.
  bool isReviewed(String lang) => statuses[lang] == kLexiconReviewed;

  /// Phrase fixe [key] dans la première langue de [langs] qui est **relue** et
  /// la possède ; `null` sinon (l'appelant retombe alors sur la langue de
  /// l'application).
  ///
  /// Une phrase de sécurité dite dans une langue qu'un modèle parle mal est un
  /// danger : ces phrases s'écrivent une fois, se relisent, et ne sont JAMAIS
  /// produites à la volée. Tant qu'une langue est brouillon, on n'en affiche
  /// rien.
  String? reply(String key, Iterable<String> langs) {
    for (final l in langs) {
      if (!isReviewed(l)) continue;
      final text = _replies[l]?[key];
      if (text != null && text.trim().isNotEmpty) return text;
    }
    return null;
  }

  /// Langues qui déclarent exactement ce mot avec ce sens (clé : mots + rôle +
  /// valeur). Un mot partagé (« stop » en français et en anglais) est validé
  /// dès que l'une de ses langues l'est.
  late final Map<String, Set<String>> _owners = () {
    final out = <String, Set<String>>{};
    for (final e in _entries) {
      out.putIfAbsent(_ownerKey(e), () => {}).add(e.lang);
    }
    return out;
  }();

  static String _ownerKey(_Entry e) => '${e.toks.join(' ')}|${e.role}|${e.value}';

  static const _maxTokens = 16;

  /// Nombre de mots/expressions par langue et par rôle : la charge de
  /// relecture d'un locuteur.
  Map<String, Map<String, int>> sizes() {
    final out = <String, Map<String, int>>{};
    for (final e in _entries) {
      final m = out.putIfAbsent(e.lang, () => {});
      m[e.role] = (m[e.role] ?? 0) + 1;
    }
    for (final n in _numbers) {
      final m = out.putIfAbsent(n.lang, () => {});
      m['nombre'] = n.units.length + n.tens.length + n.hundred.length + n.thousand.length + n.connectors.length + (n.tensPrefix == null ? 0 : 1);
    }
    return out;
  }

  /// Paires de mots qui se confondraient tout en voulant dire autre chose.
  /// Doit être VIDE : un mot proche d'un mot de sens opposé est un danger.
  ///
  /// Avec `relaxed: true`, la même vérification pour l'appariement souple : la
  /// liste y est plus longue, c'est la mesure de ce que le mode souple risque de
  /// confondre — d'où la confirmation obligatoire.
  List<String> conflicts({bool relaxed = false}) {
    final out = <String>[];
    for (var i = 0; i < _entries.length; i++) {
      for (var j = i + 1; j < _entries.length; j++) {
        final a = _entries[i], b = _entries[j];
        if (a.role == b.role && a.value == b.value) continue;
        if (a.toks.length != b.toks.length) continue;
        var same = true;
        for (var k = 0; k < a.toks.length && same; k++) {
          same = _similar(a.toks[k], b.toks[k], relaxed: relaxed);
        }
        if (same) out.add('${a.label} ≈ ${b.label}');
      }
    }
    return out;
  }

  // Mots désignant l'objet « axe » : pour reconnaître « axe z » ou « Z axis ».
  late final Set<String> _axisWords = {
    for (final e in _entries)
      if (e.role == 'object' && e.value == 'axe' && e.toks.length == 1) e.toks.first,
  };

  _Entry? _bestEntry(List<_Tok> toks, int i, {bool relaxed = false}) {
    _Entry? best;
    var bestExact = -1;
    for (final e in _entries) {
      if (best != null && e.toks.length < best.toks.length) break;
      if (i + e.toks.length > toks.length) continue;
      var ok = true;
      var exact = 0;
      for (var k = 0; k < e.toks.length && ok; k++) {
        final t = toks[i + k];
        if (t.isNumber) {
          ok = false;
        } else if (t.word == e.toks[k]) {
          exact++;
        } else {
          // Jamais de mot-outil deviné : « cets » (pour « cents ») ne doit pas
          // devenir « cet » et disparaître — « trois cets » valait 3, pas 300
          // (mesuré). Un mot abîmé qui n'est reconnu comme rien reste INCONNU.
          ok = _similar(t.word, e.toks[k], relaxed: relaxed && e.role != 'filler');
        }
      }
      if (ok && exact > bestExact) {
        best = e;
        bestExact = exact;
      }
    }
    return best;
  }

  /// Plus long nombre écrit en lettres en [i], toutes langues chargées. Deux
  /// langues qui le lisent différemment : ambigu, résolu plus tard par ce que
  /// le reste de la phrase dit de la langue.
  _Mark? _wordNumber(List<_Tok> toks, int i) {
    ({int value, int len})? best;
    final byLang = <String, int>{};
    for (final n in _numbers) {
      final p = n.parse(toks, i);
      if (p == null) continue;
      if (best == null || p.len > best.len) {
        best = p;
        byLang
          ..clear()
          ..[n.lang] = p.value;
      } else if (p.len == best.len) {
        byLang[n.lang] = p.value;
      }
    }
    if (best == null) return null;
    if (byLang.values.toSet().length > 1) {
      return _Mark('num_ambigu', '', best.len, i, candidates: byLang);
    }
    return _Mark('num', '', best.len, i,
        number: best.value, langs: byLang.keys.toSet());
  }

  bool _isAxis(List<_Tok> toks, int i) {
    final t = toks[i];
    if (t.raw.length != 1) return false;
    final upper = t.raw == t.raw.toUpperCase() && t.raw != t.raw.toLowerCase();
    final prevAxisWord = i > 0 && _axisWords.contains(toks[i - 1].word);
    final nextNumber = i + 1 < toks.length && toks[i + 1].isNumber;
    if ('xyz'.contains(t.word)) return upper || prevAxisWord || nextNumber;
    if (t.word == 'a' || t.word == 'c') return (upper && (prevAxisWord || nextNumber)) || prevAxisWord;
    return false;
  }

  List<_Mark> _mark(List<_Tok> toks, {bool relaxed = false}) {
    final marks = <_Mark>[];
    var i = 0;
    while (i < toks.length) {
      final t = toks[i];
      if (t.isNumber) {
        marks.add(_Mark('num', '', 1, i, number: t.number));
        i++;
        continue;
      }
      if (_isAxis(toks, i)) {
        marks.add(_Mark('axis', t.word.toUpperCase(), 1, i));
        i++;
        continue;
      }
      final e = _bestEntry(toks, i, relaxed: relaxed);
      if (e != null) {
        marks.add(_Mark(e.role, e.value, e.toks.length, i,
            langs: _owners[_ownerKey(e)]));
        i += e.toks.length;
        continue;
      }
      final n = _wordNumber(toks, i);
      if (n != null) {
        marks.add(n);
        i += n.span;
        continue;
      }
      marks.add(_Mark('unknown', t.word, 1, i));
      i++;
    }
    return marks;
  }

  /// Lève l'ambiguïté d'un nombre entre langues avec ce que la phrase dit de
  /// la langue : seuls comptent les mots PROPRES à une langue.
  Set<String> _evidenceLangs(List<_Mark> marks, List<_Tok> toks) {
    final owners = <String, Set<String>>{};
    for (final e in _entries) {
      owners.putIfAbsent(e.toks.join(' '), () => {}).add(e.lang);
    }
    final langs = <String>{};
    for (final m in marks) {
      if (m.role == 'unknown' || m.role == 'num' || m.role == 'num_ambigu') continue;
      final key = toks.sublist(m.start, m.start + m.span).map((t) => t.word).join(' ');
      final o = owners[key];
      if (o != null && o.length == 1) langs.addAll(o);
    }
    return langs;
  }

  /// Comprend [raw]. Avec [relaxed], l'appariement des mots est plus souple (voir
  /// `_similar`) et tout résultat est une SUGGESTION ([LexiconMatch.relaxed]) :
  /// les refus (négation, condition, direction, question, nombre ambigu,
  /// tolérance de mots inconnus) restent exactement les mêmes.
  LexiconResult interpret(String raw, {bool relaxed = false}) {
    final text = raw.trim();
    if (text.isEmpty) return const LexiconResult.refused('vide');
    final isQuestion =
        text.contains('?') || text.contains('？') || text.contains('؟');
    final toks = _tokenize(text);
    if (toks.isEmpty) return const LexiconResult.refused('vide');
    if (toks.length > _maxTokens) return const LexiconResult.refused('trop_long');

    var marks = _mark(toks, relaxed: relaxed);

    // Nombres ambigus entre langues.
    if (marks.any((m) => m.role == 'num_ambigu')) {
      final evidence = _evidenceLangs(marks, toks);
      final resolved = <_Mark>[];
      for (final m in marks) {
        if (m.role != 'num_ambigu') {
          resolved.add(m);
          continue;
        }
        final pick = m.candidates!.keys.where(evidence.contains).toList();
        if (pick.length != 1) return const LexiconResult.refused('nombre_ambigu');
        resolved.add(_Mark('num', '', m.span, m.start,
            number: m.candidates![pick.single], langs: {pick.single}));
      }
      marks = resolved;
    }

    bool has(String role) => marks.any((m) => m.role == role);
    if (has('neg')) return const LexiconResult.refused('negation');
    if (has('cond')) return const LexiconResult.refused('condition');
    if (has('dir')) return const LexiconResult.refused('direction');

    final actions = {for (final m in marks) if (m.role == 'action') m.value};
    if (actions.length > 1) return const LexiconResult.refused('actions_multiples');
    final objects = {for (final m in marks) if (m.role == 'object') m.value};
    final unknown = marks.where((m) => m.role == 'unknown').length;
    final asks = isQuestion || has('question');

    // Un mot d'alarme seul (« Urgence ! », « Au secours ») : arrêt d'urgence.
    final alarmOnly = actions.isEmpty &&
        objects.isEmpty &&
        has('alarm') &&
        marks.every((m) => const {'alarm', 'urgent', 'filler'}.contains(m.role));

    _Intent? chosen;
    var chosenScore = -1;
    var tie = false;
    for (final it in _intents) {
      final bool ok;
      if (alarmOnly) {
        ok = it.alarmAlone;
      } else {
        final actionOk = it.actions.contains(actions.isEmpty ? null : actions.single);
        final objectOk = (objects.isEmpty ? it.objects.contains(null) : objects.every(it.objects.contains)) &&
            it.need.every(objects.contains);
        ok = actionOk && objectOk;
      }
      if (!ok) continue;
      final score = objects.length + (actions.isEmpty ? 0 : 1);
      if (score > chosenScore) {
        chosen = it;
        chosenScore = score;
        tie = false;
      } else if (score == chosenScore && chosen != null && chosen.id != it.id) {
        tie = true;
      }
    }
    if (chosen == null) return const LexiconResult.refused('aucune_intention');
    if (tie) return const LexiconResult.refused('ambigu');

    if (asks && !chosen.readOnly) return const LexiconResult.refused('question');
    if (unknown > chosen.tolerance) return const LexiconResult.refused('mots_inconnus');

    final evidence = <String>[
      for (final m in marks)
        if (m.role != 'unknown')
          '${toks.sublist(m.start, m.start + m.span).map((t) => t.raw).join(' ')}→${m.role}${m.value.isEmpty ? '' : ':${m.value}'}'
    ];

    final numeric = marks.where((m) => m.role == 'num').toList();
    final withAxis = chosen.slots.contains('axis');
    if (!withAxis && has('axis')) return const LexiconResult.refused('axe_non_gere');
    if (chosen.slots.isEmpty && (numeric.isNotEmpty || has('unit') || has('feed'))) {
      return const LexiconResult.refused('nombre_inattendu');
    }

    final args = <String, dynamic>{...chosen.args};
    if (chosen.slots.isNotEmpty) {
      final slotError = _fillSlots(chosen, marks, args);
      if (slotError != null) return LexiconResult.refused(slotError);
    }

    // Confiance : seuls comptent les mots d'une langue (ni chiffres, ni noms
    // d'axe, ni mots-outils). Un mot partagé par deux langues est validé dès
    // que l'une d'elles est relue.
    final counted = marks
        .where((m) => m.langs != null && m.role != 'filler')
        .toList();
    final spoken = <String>{for (final m in counted) ...m.langs!};
    return LexiconResult.match(LexiconMatch(
      intent: chosen.id,
      tool: chosen.tool,
      args: args,
      evidence: evidence,
      relaxed: relaxed,
      readOnly: chosen.readOnly,
      trusted: counted.every((m) => m.langs!.any(isReviewed)),
      languages: spoken.toList()..sort(),
    ));
  }

  /// Axe, distance signée et vitesse d'un déplacement. `null` si tout va bien,
  /// sinon la raison du refus.
  String? _fillSlots(_Intent it, List<_Mark> marks, Map<String, dynamic> args) {
    final axes = {for (final m in marks) if (m.role == 'axis') m.value};
    if (axes.isEmpty) return 'manque:axe';
    if (axes.length > 1) return 'axes_multiples';

    // Rôle des nombres d'après leurs voisins : un nombre juste après le mot
    // « vitesse » (à deux mots-outils près) est la vitesse ; un nombre collé à
    // une unité, la distance.
    //
    // Une unité appartient au nombre qui la PRÉCÈDE (« 5 mm ») ; à défaut, à celui
    // qui la suit (« mm 5 ») — sinon, dans « 5 mm 300 », l'unité serait comptée
    // pour les deux nombres.
    final unitOf = <int, String>{};
    for (var k = 0; k < marks.length; k++) {
      if (marks[k].role != 'unit') continue;
      if (k > 0 && marks[k - 1].role == 'num') {
        unitOf[k - 1] = marks[k].value;
      } else if (k + 1 < marks.length && marks[k + 1].role == 'num') {
        unitOf[k + 1] = marks[k].value;
      }
    }
    final plain = <({num value, String? unit})>[];
    final feeds = <num>[];
    for (var k = 0; k < marks.length; k++) {
      final m = marks[k];
      if (m.role != 'num') continue;
      bool isRole(int idx, String role) => idx >= 0 && idx < marks.length && marks[idx].role == role;
      final feed = isRole(k - 1, 'feed') ||
          (isRole(k - 1, 'filler') && isRole(k - 2, 'feed')) ||
          (isRole(k - 1, 'filler') && isRole(k - 2, 'filler') && isRole(k - 3, 'feed'));
      if (feed) {
        feeds.add(m.number!);
        continue;
      }
      plain.add((value: m.number!, unit: unitOf[k]));
    }
    if (feeds.length > 1) return 'trop_de_nombres';
    if (plain.isEmpty) return 'manque:distance';
    num? feed;
    var dist = plain.first;
    if (feeds.isNotEmpty) {
      if (plain.length > 1) return 'trop_de_nombres';
      feed = feeds.single;
    } else if (plain.length == 2) {
      // Sans mot « vitesse » : le nombre collé à une unité de longueur est la
      // distance, l'autre la vitesse ; sans unité nulle part, le premier est la
      // distance. Deux longueurs : ambigu, refusé.
      final u0 = plain[0].unit != null, u1 = plain[1].unit != null;
      if (u0 && u1) return 'trop_de_nombres';
      if (u1) {
        dist = plain[1];
        feed = plain[0].value;
      } else {
        feed = plain[1].value;
      }
    } else if (plain.length > 2) {
      return 'trop_de_nombres';
    }
    if (feed == null) return 'manque:vitesse';

    var distance = dist.value;
    if (dist.unit == 'cm') distance = distance * 10;
    args['axis'] = axes.single;
    args['distance'] = distance == distance.roundToDouble() ? distance.round() : distance;
    args['feedrate'] = feed == feed.roundToDouble() ? feed.round() : feed;
    return null;
  }
}
