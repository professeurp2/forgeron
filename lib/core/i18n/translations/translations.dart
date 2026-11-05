import 'af.dart';
import 'am.dart';
import 'ar.dart';
import 'bm.dart';
import 'en.dart';
import 'ha.dart';
import 'ig.dart';
import 'ln.dart';
import 'mg.dart';
import 'rw.dart';
import 'sn.dart';
import 'so.dart';
import 'sw.dart';
import 'wo.dart';
import 'yo.dart';
import 'zu.dart';

/// Dictionnaires de l'interface, par code de langue ISO 639-1.
///
/// Genere par tool/i18n_gen.py : la liste suit les fichiers presents
/// dans tool/translations/. Le francais ne figure pas ici, c'est la
/// langue source, celle des cles. Une langue absente de cette table,
/// ou une cle absente d'un dictionnaire, affiche le francais.
const Map<String, Map<String, String>> kAppTranslations =
    <String, Map<String, String>>{
  'af': kAf,
  'am': kAm,
  'ar': kAr,
  'bm': kBm,
  'en': kEn,
  'ha': kHa,
  'ig': kIg,
  'ln': kLn,
  'mg': kMg,
  'rw': kRw,
  'sn': kSn,
  'so': kSo,
  'sw': kSw,
  'wo': kWo,
  'yo': kYo,
  'zu': kZu,
};

/// Nombre de textes du catalogue (tool/i18n_keys.json). Un dictionnaire
/// en couvre une partie : l'assistant dit « N sur ce total » plutôt
/// qu'un nombre seul, qu'un modèle local enjolivait.
const int kTranslationKeyCount = 1045;
