import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/demo_benchmark_catalog.dart';
import '../providers/activity_log_provider.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/ai_artifacts_provider.dart';
import '../providers/controller_memory_provider.dart';
import '../providers/gcode_provider.dart';

/// Exécuteur en 1 clic des cas d'essai CAO/STEP & G-Code embarqués dans Forgeron
/// (Filière **Manufacturing** & Filière **Médecine**).
class DemoBenchmarkRunner {
  DemoBenchmarkRunner._();

  /// Lance un cas de test du catalogue [DemoBenchmarkCatalog] :
  /// 1. Charge le modèle STEP/STL dans `aiArtifactsProvider` (maillage 3D).
  /// 2. Charge le parcours G-code 5 axes associé dans `gcodeProvider` (visualiseur Trunnion).
  /// 3. Met à jour la Mémoire du Contrôleur (`controllerMemoryProvider`) et régénère
  ///    les nouvelles suggestions contextuelles post-opération.
  /// 4. Publie l'introduction technique de l'Agent IA dans le Chatbot Omniprésent.
  static Future<String> runSample(
    WidgetRef ref,
    DemoBenchmarkSample sample,
  ) async {
    return _execute(
      read: ref.read,
      sample: sample,
    );
  }

  static Future<String> runSampleFromRef(
    Ref ref,
    DemoBenchmarkSample sample,
  ) async {
    return _execute(
      read: ref.read,
      sample: sample,
    );
  }

  static Future<String> _execute({
    required T Function<T>(ProviderListenable<T>) read,
    required DemoBenchmarkSample sample,
  }) async {
    final artifacts = read(aiArtifactsProvider.notifier);
    final gcodeNotifier = read(gcodeProvider.notifier);
    final memory = read(controllerMemoryProvider.notifier);
    final activity = read(activityLogProvider.notifier);
    final aiController = read(aiAgentControllerProvider.notifier);

    int loadedLines = 0;
    Map<String, dynamic>? reportJson;

    // 1. Chargement de l'aperçu STEP/CAO s'il existe sur le disque
    final cadFile = File(sample.cadPath);
    if (await cadFile.exists()) {
      // Ne bloque pas si Python/OCCT n'est pas sollicité : utilise le cache JSON embarqué
      await artifacts.loadStep(sample.cadPath, force: false);
      artifacts.dock(AiDockedViewer.step);
    }

    // 2. Lecture du rapport JSON pré-calculé si disponible
    if (sample.reportJsonPath != null) {
      final reportFile = File(sample.reportJsonPath!);
      if (await reportFile.exists()) {
        try {
          reportJson = jsonDecode(await reportFile.readAsString())
              as Map<String, dynamic>;
          artifacts.setGcodeFromReport(reportJson);
        } catch (_) {}
      }
    }

    // 3. Chargement du programme G-Code 5 axes associé dans le visualiseur Trunnion
    if (sample.gcodePath != null) {
      final gcodeFile = File(sample.gcodePath!);
      if (await gcodeFile.exists()) {
        final content = await gcodeFile.readAsString();
        await gcodeNotifier.loadFile(content);
        loadedLines = read(gcodeProvider).allLines.length;
        if (reportJson == null) {
          artifacts.setGcodePath(sample.gcodePath!);
        }
        artifacts.dock(AiDockedViewer.toolpath);
      }
    }

    // 4. Mise à jour de la Mémoire du Contrôleur & génération des nouvelles suggestions
    final domainCode =
        sample.domain == DemoDomain.medicine ? 'medicine' : 'manufacturing';
    memory.recordOperation(
      OperationEventType.demoBenchmarkLoaded,
      summary: 'Cas d\'essai ${sample.domainLabel} chargé : ${sample.title}',
      filePath: sample.cadPath,
      demoDomain: domainCode,
    );

    activity.log(
      'Démo [${sample.domainLabel}] : ${sample.title} (${sample.cadPath}) — $loadedLines lignes G-code chargées',
    );

    // 5. Construction du message d'orientation de l'Agent IA dans le Chatbot
    final highlights = sample.keyHighlights.map((h) => '• $h').join('\n');
    final dimsInfo = reportJson != null && reportJson['dimensions_mm'] != null
        ? '\n📐 **Dimensions brutes détectées** : `${jsonEncode(reportJson['dimensions_mm'])}`'
        : '';
    final gcodeInfo = loadedLines > 0
        ? '\n✅ **Parcours 5 axes chargé** : `${sample.gcodePath}` (**$loadedLines blocs G-code** prêts dans le visualiseur 3D Trunnion).'
        : '\n📂 **Fichier CAO sélectionné** : `${sample.cadPath}`.';

    final pitch = '🎯 **[DÉMO ${sample.domainLabel}] — ${sample.title}**\n\n'
        '${sample.agentPitch}\n\n'
        '🔧 **Paramètres métier** : ${sample.materialAndTool}'
        '$dimsInfo'
        '$gcodeInfo\n\n'
        '**Points clés à observer :**\n$highlights\n\n'
        '💡 *Consultez les nouvelles suggestions ci-dessous pour simuler l\'usinage 5 axes, vérifier l\'enveloppe machine ou préparer le palpage G54.*';

    aiController.postProactiveAssistantMessage(
      pitch,
      toolName: 'run_demo_benchmark',
      toolArgs: {
        'domain': domainCode,
        'sample_id': sample.id,
        'cad_path': sample.cadPath,
      },
      toolResult: jsonEncode({
        'ok': true,
        'domain': domainCode,
        'title': sample.title,
        'cad_path': sample.cadPath,
        'gcode_path': sample.gcodePath,
        'gcode_lines': loadedLines,
      }),
    );

    return pitch;
  }
}

