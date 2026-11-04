/// Messages de la dictée vocale, un par cause réelle.
///
/// Avant, les deux écrans de chat jetaient l'erreur du moteur (`onError: (_)`)
/// et la console desktop affichait « Aucun micro détecté » pour TOUT échec
/// d'initialisation — même avec un micro branché et autorisé (constaté le
/// 29 octobre 2026 sur le PC de développement). Impossible alors de savoir si
/// c'était la permission, le réseau ou la langue.
///
/// Chaque message garde le code brut entre parenthèses : c'est lui qu'on
/// recopie pour diagnostiquer.
library;

import '../i18n/app_localizations.dart';

/// Message pour un code d'erreur du moteur de dictée ([code] : `errorMsg` de
/// `SpeechRecognitionError`, ou celui d'une `PlatformException`).
String speechErrorMessage(String code) {
  final c = code.trim();
  final String text;
  switch (c) {
    case 'error_permission':
      text = tr('Accès au micro refusé. Autorise le micro pour Forgeron dans '
          'les réglages de l\'appareil.');
    case 'error_network':
    case 'error_network_timeout':
    case 'error_server':
    case 'error_server_disconnected':
      text = tr('La dictée a besoin d\'Internet, et le WiFi de la machine n\'en '
          'a pas. Active les données mobiles, ou installe la reconnaissance '
          'vocale hors ligne pour cette langue.');
    case 'error_no_match':
    case 'error_speech_timeout':
      text = tr('Rien de clair n\'a été entendu. Parle juste après avoir '
          'appuyé sur le micro, plus près de l\'appareil.');
    case 'error_language_not_supported':
    case 'error_language_unavailable':
      text = tr('Cette langue n\'est pas disponible pour la dictée sur cet '
          'appareil.');
    case 'error_busy':
      text = tr('Le micro est déjà utilisé par une autre application.');
    case 'error_audio_error':
      text = tr('Le micro ne répond pas (erreur audio).');
    case 'error_too_many_requests':
      text = tr('Trop de demandes de dictée d\'affilée. Réessaie dans un '
          'instant.');
    case 'NOT_INITIALIZED':
      text = tr('La reconnaissance vocale n\'a pas démarré.');
    default:
      text = tr('Dictée impossible.');
  }
  return c.isEmpty ? text : '$text (${tr('code')} : $c)';
}

/// Message quand le moteur refuse de démarrer (`initialize` rend `false`,
/// sans code d'erreur).
String speechInitFailedMessage({required bool windows}) => windows
    ? tr('La reconnaissance vocale de Windows n\'a pas démarré. Vérifie '
        'Paramètres > Confidentialité > Microphone (accès des applications de '
        'bureau), et qu\'une langue de reconnaissance vocale est installée '
        '(Paramètres > Heure et langue > Voix).')
    : tr('Reconnaissance vocale indisponible : micro refusé, ou aucun service '
        'de dictée sur cet appareil (Google ou équivalent).');
