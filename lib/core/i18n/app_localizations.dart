import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'translations/translations.dart';

/// Traduit [source] dans la langue courante de l'application.
///
/// La clé est le texte **français** du code : `tr('Démarrer')`. Une entrée
/// absente retombe silencieusement sur le français — sur un pupitre de
/// machine, un libellé en français vaut mieux qu'une clé nue ou qu'un plantage.
///
/// Les paramètres sont positionnels et notés `{}` :
/// `tr('Fichier {} introuvable', [nom])`.
///
/// Fonction de premier niveau, sans `BuildContext` : la table courante est
/// posée par [AppLocalizations] au moment où Flutter résout la locale, donc
/// avant que le moindre widget de l'app ne soit construit. Ça permet de
/// traduire depuis les dizaines de méthodes utilitaires qui ne reçoivent pas
/// de contexte, sans avoir à en propager un partout.
String tr(String source, [List<Object?> args = const []]) {
  var out = AppLocalizations.current[source] ?? source;
  for (final arg in args) {
    out = out.replaceFirst('{}', '$arg');
  }
  return out;
}

/// Table de traduction de la locale active, installée par le délégué.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> entries;

  const AppLocalizations(this.locale, this.entries);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Miroir statique lu par [tr]. Vide tant qu'aucune locale n'est résolue
  /// (tests de widgets isolés) : tout reste alors en français.
  static Map<String, String> current = const <String, String>{};

  @visibleForTesting
  static void setCurrentForTest(Map<String, String> entries) {
    current = entries;
  }

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('fr'), <String, String>{});
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  /// Toutes les locales sont acceptées : celles sans dictionnaire s'affichent
  /// en français plutôt que d'être écartées de la résolution.
  @override
  bool isSupported(Locale locale) => true;

  /// [SynchronousFuture] et non `async` : une vraie `Future` ferait construire
  /// une première frame sans traductions, puis tout rebâtir — visible à
  /// l'oeil sur un changement de langue.
  @override
  Future<AppLocalizations> load(Locale locale) {
    final entries =
        kAppTranslations[locale.languageCode] ?? const <String, String>{};
    AppLocalizations.current = entries;
    return SynchronousFuture<AppLocalizations>(
        AppLocalizations(locale, entries));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
