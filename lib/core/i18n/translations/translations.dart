import 'af.dart';
import 'am.dart';
import 'ar.dart';
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
/// Le français n'y figure pas : c'est la langue source, celle des clés. Une
/// langue absente de cette table, ou une clé absente d'un dictionnaire,
/// affiche le français.
const Map<String, Map<String, String>> kAppTranslations =
    <String, Map<String, String>>{
  'en': kEn,
  'ar': kAr,
  'sw': kSw,
  'af': kAf,
  'am': kAm,
  'ha': kHa,
  'yo': kYo,
  'ig': kIg,
  'zu': kZu,
  'so': kSo,
  'rw': kRw,
  'sn': kSn,
  'ln': kLn,
  'wo': kWo,
  'mg': kMg,
};
