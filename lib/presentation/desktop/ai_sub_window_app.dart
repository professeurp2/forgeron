import 'dart:async';
import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/forgeron_colors.dart';
import '../../core/theme/forgeron_fluent_theme.dart';
import 'ai_sub_window_content.dart';

/// Racine Dart d'une fenêtre ouverte par `AiWindowLauncher` — un second
/// moteur Flutter, indépendant de [ForgeronApp] (voir main.dart). Elle ne
/// connaît de la fenêtre principale que ce que `arguments` lui a transmis au
/// moment de la création : pas de Riverpod partagé entre les deux moteurs.
class AiSubWindowApp extends StatefulWidget {
  const AiSubWindowApp({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  State<AiSubWindowApp> createState() => _AiSubWindowAppState();
}

class _AiSubWindowAppState extends State<AiSubWindowApp> {
  late final Map<String, dynamic> _payload = _parse(widget.rawArguments);

  static Map<String, dynamic> _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fenêtre orpheline (arguments corrompus ou format inattendu) : on
      // affiche un état d'erreur lisible plutôt que de planter la fenêtre.
    }
    return const {'type': 'unknown'};
  }

  @override
  void initState() {
    super.initState();
    unawaited(_configureWindow());
  }

  Future<void> _configureWindow() async {
    await windowManager.ensureInitialized();
    final title = _payload['title'] as String? ?? 'Forgeron';
    await windowManager.setTitle(title);
    await windowManager.setMinimumSize(const Size(480, 360));
    await windowManager.setSize(const Size(760, 580));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: _payload['title'] as String? ?? 'Forgeron',
      theme: forgeronFluentTheme(forgeronDarkColors),
      home: _content(),
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
      default:
        return const ScaffoldPage(
          content: Center(child: Text('Fenêtre inconnue.')),
        );
    }
  }
}
