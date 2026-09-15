import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Filets de sécurité pour les langues que Flutter ne fournit pas.
///
/// `GlobalMaterialLocalizations` couvre une centaine de locales, mais pas le
/// wolof, le lingala, le kinyarwanda ni le shona. Sans ces délégués, choisir
/// une de ces langues fait échouer l'assertion « No MaterialLocalizations
/// found » et l'app tombe au démarrage.
///
/// `Localizations` ne retient que le **premier** délégué de chaque type qui
/// déclare supporter la locale : placés APRÈS les délégués globaux, ceux-ci
/// ne servent donc que pour les langues réellement absentes. Les libellés
/// internes de Material (mois, « OK », « Annuler » des sélecteurs) sont alors
/// en anglais — l'interface de Forgeron, elle, reste traduite.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  /// [SynchronousFuture], comme les délégués de Flutter : une vraie
  /// Future ferait construire une frame vide avant les libelles,
  /// visible comme un clignotement au changement de langue.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
          const DefaultMaterialLocalizations());

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
          const DefaultCupertinoLocalizations());

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
