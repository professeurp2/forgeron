import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/forgeron_colors.dart';
import '../../core/theme/forgeron_fluent_theme.dart';
import 'ai_sub_window_content.dart';
import 'ai_viewer_windows.dart';

/// Racine Dart d'une fenêtre ouverte par `AiWindowLauncher` — un second
/// moteur Flutter, indépendant de [ForgeronApp] (voir main.dart). Elle ne
/// connaît de la fenêtre principale que ce que `arguments` lui a transmis au
/// moment de la création : pas de Riverpod partagé entre les deux moteurs.
///
/// Elle ouvre malgré tout son PROPRE [ProviderScope] : les fenêtres 3D
/// réutilisent le visualiseur et le parseur G-code de l'app, qui sont écrits
/// en Riverpod. Deux portées distinctes, donc deux états — c'est voulu :
/// charger un parcours dans une fenêtre détachée ne doit pas remplacer le
/// programme ouvert dans la fenêtre principale.
///
/// **Aucun plugin de gestion de fenêtres ici.** Le cadre, le titre et la
/// position sont posés par la fenêtre principale avant l'affichage (voir
/// `AiWindowLauncher._open`). C'est ce qui a corrigé le défaut le plus
/// déroutant de ces fenêtres : refermer une fenêtre détachée fermait
/// l'application entière. `window_manager` s'attache à UNE fenêtre native,
/// celle qu'il trouve à son initialisation ; initialisé dans ce second moteur,
/// il se raccrochait à la fenêtre principale et en détournait la procédure.
class AiSubWindowApp extends StatefulWidget {
  const AiSubWindowApp({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  State<AiSubWindowApp> createState() => _AiSubWindowAppState();
}

class _AiSubWindowAppState extends State<AiSubWindowApp> {
  late final Map<String, dynamic> _payload = _parse(widget.rawArguments);

  /// Les charges volumineuses (maillage d'une pièce) transitent par un
  /// fichier temporaire plutôt que par les arguments — voir
  /// `AiWindowLauncher._arguments`. Le fichier est consommé puis supprimé :
  /// personne d'autre n'en a l'usage, et il peut peser plusieurs mégaoctets.
  static Map<String, dynamic> _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {'type': 'unknown'};

      final path = decoded['payloadFile'] as String?;
      if (path == null) return decoded;

      final file = File(path);
      final full = jsonDecode(file.readAsStringSync());
      try {
        file.deleteSync();
      } catch (_) {
        // Fichier déjà nettoyé ou verrouillé : sans conséquence.
      }
      if (full is Map<String, dynamic>) return full;
    } catch (_) {
      // Fenêtre orpheline (arguments corrompus ou format inattendu) : on
      // affiche un état d'erreur lisible plutôt que de planter la fenêtre.
    }
    return const {'type': 'unknown'};
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ForgeronTheme(
        colors: forgeronDarkColors,
        child: FluentApp(
          debugShowCheckedModeBanner: false,
          title: _payload['title'] as String? ?? 'Forgeron',
          theme: forgeronFluentTheme(forgeronDarkColors),
          home: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_payload['type']) {
      case 'chart':
        return ChartWindow(payload: _payload);
      case 'gcode':
        return GcodeWindow(payload: _payload);
      case 'report':
        return ReportWindow(payload: _payload);
      case 'step_preview':
        return StepPreviewWindow(payload: _payload);
      case 'toolpath':
        return ToolpathWindow(payload: _payload);
      default:
        return const ScaffoldPage(
          content: Center(child: Text('Fenêtre inconnue.')),
        );
    }
  }
}
