import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/fluidnc/grbl_parser.dart';
import '../providers/ai_agent_settings_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/di_providers.dart';
import '../providers/gcode_provider.dart';
import '../providers/streaming_provider.dart';
import '../providers/firmware_provider.dart';
import '../providers/network_stats_provider.dart';
import '../providers/config_provider.dart';
import '../providers/machine_params_provider.dart';
import '../providers/activity_log_provider.dart';
import '../providers/jog_provider.dart';
import '../providers/workspace_provider.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_adapter.dart';

/// Une action que l'agent IA peut exécuter, exposée à Gemini comme une
/// "function declaration" (function calling). [category] détermine la porte
/// de permission ([AiAgentSettings]) : `null` = toujours autorisée sans
/// confirmation (lecture seule, ou arrêt d'urgence qui doit rester immédiat
/// par sécurité).
///
/// Chaque outil appelle [machineRepositoryProvider] EXACTEMENT comme le fait
/// l'UI manuelle — aucun garde-fou existant (TrajectoryValidator, ForceGuard)
/// n'est contourné : l'agent est juste un appelant de plus du même chemin.
class AiTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final AiActionCategory? category;
  final Future<String> Function(Map<String, dynamic> input, Ref ref) execute;

  /// Vrai si l'outil peut produire une image en plus de son texte.
  ///
  /// Gemini ne transporte pas de binaire dans une `functionResponse` — celle-ci
  /// ne contient que du JSON. Une image doit voyager dans une part
  /// `inlineData` séparée, jointe au même tour de conversation. Les outils
  /// concernés déposent donc leurs octets dans [aiToolImageProvider], que la
  /// boucle d'outils vide immédiatement après l'exécution.
  ///
  /// Ce drapeau limite ce ramassage aux seuls outils qui le déclarent : aucune
  /// image ne peut fuir d'un appel où elle n'a rien à faire.
  final bool producesImage;

  const AiTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.category,
    required this.execute,
    this.producesImage = false,
  });

  /// Déclaration au format attendu par l'API Gemini (`FunctionDeclaration`) :
  /// même schéma que [inputSchema], mais avec les `type` en MAJUSCULES
  /// ("OBJECT", "STRING"...) comme l'exige l'énum `Schema.Type` de Gemini.
  Map<String, dynamic> toGeminiFunctionDeclaration() => {
        'name': name,
        'description': description,
        'parameters': _toGeminiSchema(inputSchema),
      };
}

/// Convertit récursivement un schéma JSON "classique" (types en minuscules,
/// façon Anthropic/OpenAI) vers le sous-ensemble supporté par le `Schema`
/// de l'API Gemini. Les mots-clés non supportés (minimum/maximum/minItems/
/// maxItems...) sont volontairement ignorés plutôt que de risquer un 400.
Map<String, dynamic> _toGeminiSchema(Map<String, dynamic> schema) {
  final out = <String, dynamic>{};
  final type = schema['type'];
  if (type is String) out['type'] = type.toUpperCase();
  if (schema['description'] is String) out['description'] = schema['description'];
  if (schema['enum'] is List) out['enum'] = schema['enum'];
  if (schema['required'] is List) out['required'] = schema['required'];
  final properties = schema['properties'];
  if (properties is Map) {
    out['properties'] = properties.map(
      (key, value) => MapEntry(
        key as String,
        _toGeminiSchema((value as Map).cast<String, dynamic>()),
      ),
    );
  }
  final items = schema['items'];
  if (items is Map) {
    out['items'] = _toGeminiSchema(items.cast<String, dynamic>());
  }
  return out;
}

/// Image produite par un outil, en route vers Gemini.
class AiToolImage {
  const AiToolImage({required this.bytes, this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

/// Boîte aux lettres à un seul message pour les images d'outils.
///
/// Portée volontairement minuscule : une image y est déposée par [AiTool.execute]
/// puis retirée dans la foulée par la boucle d'outils. Rien n'y survit d'un
/// tour à l'autre — c'est un passe-plat, pas un cache.
final aiToolImageProvider = StateProvider<AiToolImage?>((ref) => null);

class AiToolCatalog {
  static const _axisEnum = ['X', 'Y', 'Z', 'A', 'C'];
  static const _wcsEnum = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59'];

  static final List<AiTool> tools = [
    AiTool(
      name: 'get_machine_state',
      description:
          'Retourne l\'état courant de la machine : statut, position pièce/machine, WCS actif, overrides, alarme.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final s = ref.read(machineRepositoryProvider).currentState;
        return jsonEncode({
          'status': s.status.name,
          'wPos': s.wPos,
          'mPos': s.mPos,
          'activeWCS': s.activeWCS,
          'activeToolNum': s.activeToolNum,
          'feedrate': s.feedrate,
          'spindleSpeed': s.spindleSpeed,
          'overrides': s.overrides,
          'alarmCode': s.alarmCode,
        });
      },
    ),
    AiTool(
      name: 'get_diagnostics',
      description:
          'Retourne les infos de diagnostic : température cœur, charge broche, risque de singularité, RTCP, mode d\'usinage, ForceGuard, fins de course, palpeur, buffers, progression SD, firmware (\$I : version/options/carte) et réseau (latence/qualité/uptime).',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final s = ref.read(machineRepositoryProvider).currentState;
        final fw = ref.read(firmwareInfoProvider);
        final net = ref.read(networkStatsProvider);
        return jsonEncode({
          'temperatureC': s.coreTemp,
          'spindleLoad': s.spindleLoad,
          'singularityRisk': s.singularityRisk,
          'rtcpActive': s.isRtcpActive,
          'machiningMode': s.machiningMode.name,
          'forceGuardActive': s.forceGuardActive,
          'limitSwitches': s.limitSwitches,
          'probeTriggered': s.probeTriggered,
          'emergencyTriggered': s.emergencyTriggered,
          'plannerBuffer': s.plannerBuffer,
          'rxBuffer': s.rxBuffer,
          'sdPercent': s.sdPercent,
          'sdFilename': s.sdFilename,
          'activeLineIndex': s.activeLineIndex,
          'firmware': {
            'version': fw.version,
            'grblVersion': fw.grblVersion,
            'options': fw.options,
            'board': fw.board,
          },
          'network': {
            'connected': net.connected,
            'latencyMs': net.latencyMs,
            'qualityPct': net.qualityPct,
            'txCount': net.txCount,
            'rxCount': net.rxCount,
            'uptimeSec': net.uptime.inSeconds,
          },
        });
      },
    ),
    AiTool(
      name: 'get_activity_log',
      description:
          'Retourne le journal des dernières actions machine (jog, homing, WCS, origine, override, broche, cycle, réglages…), horodatées. Inclut les actions manuelles de l\'opérateur ET celles que tu as initiées. Utile pour la sécurité et l\'optimisation.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final log = ref.read(activityLogProvider);
        return jsonEncode({
          'count': log.entries.length,
          'actions': [
            for (final e in log.entries)
              {'time': e.time.toIso8601String(), 'action': e.text},
          ],
        });
      },
    ),
    AiTool(
      name: 'get_wcs_offsets',
      description:
          'Retourne les offsets de tous les systèmes de coordonnées pièce (G54..G59) lus via \$#, sous forme {wcs: [X,Y,Z,A,C]}.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final s = ref.read(machineRepositoryProvider).currentState;
        return jsonEncode({
          'activeWCS': s.activeWCS,
          'offsets': s.wcsOffsets,
        });
      },
    ),
    AiTool(
      name: 'get_axis_kinematics',
      description:
          'Retourne la cinématique par axe (steps_per_mm, vitesse max, accélération, course max) lue depuis la configuration FluidNC.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        try {
          final cfg = await ref.read(configResultProvider.future);
          final kin = parseAxisKinematics(cfg.yaml);
          return jsonEncode({
            'fromCache': cfg.fromCache,
            'axes': [
              for (final k in kin)
                {
                  'axis': k.axis,
                  'stepsPerMm': k.stepsPerMm,
                  'maxRate': k.maxRate,
                  'accel': k.accel,
                  'maxTravel': k.maxTravel,
                },
            ],
          });
        } catch (e) {
          return 'ERREUR: config indisponible ($e)';
        }
      },
    ),
    AiTool(
      name: 'get_config',
      description:
          'Retourne la configuration FluidNC (YAML) de la machine — utile pour répondre aux questions sur le câblage, les moteurs, les broches, les axes. Peut provenir du cache (consultation hors ligne).',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        try {
          final cfg = await ref.read(configResultProvider.future);
          // Borné pour ne pas exploser le budget de tokens.
          const maxLen = 6000;
          final yaml = cfg.yaml.length > maxLen
              ? '${cfg.yaml.substring(0, maxLen)}\n...[tronqué]'
              : cfg.yaml;
          return jsonEncode({
            'fromCache': cfg.fromCache,
            'cachedAt': cfg.cachedAt?.toIso8601String(),
            'yaml': yaml,
          });
        } catch (e) {
          return 'ERREUR: config indisponible ($e)';
        }
      },
    ),
    AiTool(
      name: 'list_workspace_files',
      description:
          'Liste les fichiers G-code de l\'espace de travail (le dossier de '
          'l\'appareil choisi par l\'opérateur). Retourne le nom et la taille de '
          'chaque fichier. Utilise-le avant read_workspace_file ou pour aider '
          'l\'opérateur à choisir un programme.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final folder = ref.read(workFolderProvider);
        if (folder == null || folder.isEmpty) {
          return 'Aucun dossier de travail sélectionné (écran Espace de '
              'travail → onglet Dossier).';
        }
        // Rafraîchit la liste depuis le système de fichiers avant lecture.
        ref.read(workFilesRefreshProvider.notifier).state++;
        final files = ref.read(workFilesProvider);
        return jsonEncode({
          'folder': folder,
          'count': files.length,
          'files': files
              .map((f) => {'name': f.name, 'size': f.size})
              .toList(),
          if (files.isEmpty)
            'note': 'Dossier vide ou accès aux fichiers refusé (permission).',
        });
      },
    ),
    AiTool(
      name: 'read_workspace_file',
      description:
          'Lit le contenu d\'un fichier G-code de l\'espace de travail, par son '
          'nom (tel que listé par list_workspace_files). Sert à analyser, '
          'vérifier ou expliquer un programme AVANT de l\'exécuter.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Nom exact du fichier (ex. « piece.nc »).'
          },
        },
        'required': ['name'],
      },
      category: null,
      execute: (input, ref) async {
        final name = (input['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return 'ERREUR: nom de fichier manquant.';
        final files = ref.read(workFilesProvider);
        final match = files
            .where((f) => f.name.toLowerCase() == name.toLowerCase())
            .toList();
        if (match.isEmpty) {
          final avail = files.map((f) => f.name).join(', ');
          return 'ERREUR: fichier "$name" introuvable. Disponibles : '
              '${avail.isEmpty ? '(aucun)' : avail}';
        }
        try {
          final content = await FilePickerService.readWorkFile(match.first.path);
          const maxLen = 8000; // borne le budget de tokens
          final text = content.length > maxLen
              ? '${content.substring(0, maxLen)}\n'
                  '...[tronqué — ${content.length} caractères au total]'
              : content;
          return jsonEncode({
            'name': match.first.name,
            'size': match.first.size,
            'content': text,
          });
        } catch (e) {
          return 'ERREUR: lecture impossible ($e)';
        }
      },
    ),
    AiTool(
      name: 'write_workspace_file',
      description:
          'Écrit un fichier G-code dans l\'espace de travail — typiquement pour '
          'SAUVEGARDER une version corrigée d\'un programme (ex. après avoir '
          'corrigé un dépassement de course). ⚠️ Pour ne PAS perdre l\'original, '
          'écris sous un NOUVEAU nom (ex. « piece_corrige.nc ») ; n\'écrase le '
          'fichier d\'origine que si l\'opérateur le demande explicitement. '
          'Action gardée : le contenu est confirmé par l\'opérateur.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Nom du fichier à écrire (ex. « piece_corrige.nc »).'
          },
          'content': {
            'type': 'string',
            'description': 'Contenu G-code complet à écrire dans le fichier.'
          },
        },
        'required': ['name', 'content'],
      },
      category: AiActionCategory.fileEdit,
      execute: (input, ref) async {
        final name = (input['name'] as String?)?.trim() ?? '';
        final content = input['content'] as String? ?? '';
        if (name.isEmpty) return 'ERREUR: nom de fichier manquant.';
        if (content.isEmpty) return 'ERREUR: contenu vide.';
        final folder = ref.read(workFolderProvider);
        if (folder == null || folder.isEmpty) {
          return 'ERREUR: aucun dossier de travail sélectionné.';
        }
        // Réutilise le chemin d'un fichier existant (remplacement), sinon
        // construit un nouveau chemin dans le dossier de travail.
        final existing = ref
            .read(workFilesProvider)
            .where((f) => f.name.toLowerCase() == name.toLowerCase())
            .toList();
        final path = existing.isNotEmpty
            ? existing.first.path
            : '${folder.endsWith('/') ? folder : '$folder/'}$name';
        try {
          await FilePickerService.writeWorkFile(path, content);
          ref.read(workFilesRefreshProvider.notifier).state++;
          return 'OK: ${existing.isNotEmpty ? 'fichier remplacé' : 'fichier créé'} '
              '"$name" (${content.length} caractères).';
        } catch (e) {
          return 'ERREUR: écriture impossible ($e)';
        }
      },
    ),
    AiTool(
      name: 'analyze_gcode',
      description:
          'Analyse la compatibilité FluidNC d\'un G-code : passe le fichier dans '
          'l\'adaptateur (SolidWorks/Fanuc → FluidNC) et rapporte ce qui a été '
          'traduit (cycles fixes développés, G43/H retirés, M6→pause…), les '
          'avertissements, et si le fichier est BLOQUÉ (RTCP, compensation rayon '
          'machine G41/G42, cycle non géré → à corriger dans le post CAM). '
          'Avec "name" : analyse ce fichier de l\'espace de travail (contenu '
          'brut). Sans "name" : rapporte l\'état du programme déjà chargé. '
          'Sert au travail collaboratif de correction du G-code.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Fichier workspace à analyser. Absent = programme chargé.'
          },
        },
      },
      category: null,
      execute: (input, ref) async {
        final name = (input['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) {
          final loaded = ref.read(gcodeProvider);
          if (loaded.allLines.isEmpty) {
            return 'Aucun programme chargé et aucun nom de fichier fourni.';
          }
          return jsonEncode({
            'source': 'programme chargé (déjà adapté)',
            'blocking': loaded.adaptBlocking,
            'executable': !loaded.adaptBlocking,
            'warnings': loaded.adaptWarnings,
          });
        }
        final files = ref.read(workFilesProvider);
        final match = files
            .where((f) => f.name.toLowerCase() == name.toLowerCase())
            .toList();
        if (match.isEmpty) {
          final avail = files.map((f) => f.name).join(', ');
          return 'ERREUR: fichier "$name" introuvable. Disponibles : '
              '${avail.isEmpty ? '(aucun)' : avail}';
        }
        try {
          final raw = await FilePickerService.readWorkFile(match.first.path);
          final r = GcodeAdapter.adaptForFluidNC(raw);
          return jsonEncode({
            'file': match.first.name,
            'blocking': r.blocking,
            'executable': !r.blocking,
            'warnings': r.warnings,
            'linesIn': raw.split('\n').length,
            'linesOut': r.gcode.split('\n').length,
          });
        } catch (e) {
          return 'ERREUR: analyse impossible ($e)';
        }
      },
    ),
    AiTool(
      name: 'jog_axis',
      description: 'Déplace un axe (X, Y, Z linéaires en mm ; A, C rotatifs en degrés) d\'une distance signée à une vitesse donnée.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'axis': {'type': 'string', 'enum': _axisEnum},
          'distance': {
            'type': 'number',
            'description': 'Distance signée (mm pour X/Y/Z, degrés pour A/C).'
          },
          'feedrate': {
            'type': 'number',
            'description': 'Vitesse en mm/min (axes linéaires) ou deg/min (axes rotatifs).'
          },
        },
        'required': ['axis', 'distance', 'feedrate'],
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        final axis = input['axis'] as String;
        final distance = (input['distance'] as num).toDouble();
        // Garde de sécurité (hors-course / fin de course active) identique à l'UI.
        final v = evaluateJogSafety(ref, axis, distance);
        if (!v.allowed) return 'REFUSÉ (sécurité) : ${v.message}';
        await ref.read(machineRepositoryProvider).jog(
              axis,
              distance,
              (input['feedrate'] as num).toDouble(),
            );
        return v.warningOnly ? 'OK — attention : ${v.message}' : 'OK';
      },
    ),
    AiTool(
      name: 'home',
      description: 'Prise d\'origine (homing) des axes indiqués, ou de tous les axes configurés si la liste est vide/absente.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'axes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Ex: ["X","Y","Z"]. Absent ou vide = tous les axes.',
          },
        },
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        final axes = (input['axes'] as List?)?.cast<String>() ?? const [];
        await ref.read(machineRepositoryProvider).home(axes);
        return 'OK';
      },
    ),
    AiTool(
      name: 'emergency_stop',
      description: 'Déclenche un arrêt d\'urgence immédiat (soft reset + purge du streaming). Toujours exécuté sans confirmation, quels que soient les réglages de permission.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        // Par le contrôleur : l'opérateur doit VOIR l'échec sur le bandeau
        // rouge, pas seulement le lire dans la conversation avec l'agent.
        final ok = await ref.read(streamingProvider.notifier).stopStream();
        return ok ? 'OK: arrêt transmis' : 'ERREUR: liaison coupée, arrêt NON transmis à la machine';
      },
    ),
    AiTool(
      name: 'set_feed_override',
      description: 'Définit le pourcentage d\'override de la vitesse d\'avance (10-200%).',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'percent': {'type': 'integer', 'minimum': 10, 'maximum': 200},
        },
        'required': ['percent'],
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).setFeedOverride(input['percent'] as int);
        return 'OK';
      },
    ),
    AiTool(
      name: 'set_spindle_override',
      description: 'Définit le pourcentage d\'override de la vitesse de broche (10-200%).',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'percent': {'type': 'integer', 'minimum': 10, 'maximum': 200},
        },
        'required': ['percent'],
      },
      category: AiActionCategory.spindleCoolant,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).setSpindleOverride(input['percent'] as int);
        return 'OK';
      },
    ),
    AiTool(
      name: 'select_wcs',
      description: 'Change le système de coordonnées pièce actif (G54 à G59).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'wcs': {'type': 'string', 'enum': _wcsEnum},
        },
        'required': ['wcs'],
      },
      category: AiActionCategory.wcsTool,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).sendGCode(input['wcs'] as String);
        return 'OK';
      },
    ),
    AiTool(
      name: 'set_wcs_offset',
      description: 'Définit l\'offset [X,Y,Z,A,C] d\'un système de coordonnées via G10 L2 (valeurs absolues, pas relatives à la position courante).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'wcs': {'type': 'string', 'enum': _wcsEnum},
          'offset': {
            'type': 'array',
            'items': {'type': 'number'},
            'minItems': 5,
            'maxItems': 5,
            'description': '[X, Y, Z, A, C] en mm/degrés.',
          },
        },
        'required': ['wcs', 'offset'],
      },
      category: AiActionCategory.wcsTool,
      execute: (input, ref) async {
        final offset =
            (input['offset'] as List).map((e) => (e as num).toDouble()).toList();
        await ref
            .read(machineRepositoryProvider)
            .setWcsOffset(input['wcs'] as String, offset);
        return 'OK';
      },
    ),
    AiTool(
      name: 'send_gcode',
      description: 'Envoie une seule ligne de G-code à la machine (ex: pour une commande ponctuelle, pas pour exécuter un programme complet).',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'gcode': {'type': 'string'},
        },
        'required': ['gcode'],
      },
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).sendGCode(input['gcode'] as String);
        return 'OK';
      },
    ),
    AiTool(
      name: 'pause',
      description: 'Met en pause le programme en cours d\'exécution (feed hold).',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).pause();
        return 'OK';
      },
    ),
    AiTool(
      name: 'resume',
      description: 'Reprend un programme en pause (cycle start).',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).resume();
        return 'OK';
      },
    ),
    AiTool(
      name: 'reset',
      description: 'Réinitialise le contrôleur (soft reset) — n\'est PAS un arrêt d\'urgence, utiliser emergency_stop pour ça.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        await ref.read(machineRepositoryProvider).reset();
        return 'OK';
      },
    ),
    AiTool(
      name: 'run_program',
      description:
          'Lance l\'exécution du programme G-code actuellement chargé (avec validation trajectoire + ForceGuard). Échoue si aucun programme n\'est chargé.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        final r = await ref.read(streamingProvider.notifier).startStream();
        if (r.isValid) return 'OK: exécution démarrée';
        final line = r.errorLine != null ? ' (ligne ${r.errorLine})' : '';
        return 'REFUSÉ: ${r.errorMessage}$line';
      },
    ),
    AiTool(
      name: 'run_gcode_program',
      description:
          'Charge le programme G-code fourni (plusieurs lignes) PUIS l\'exécute, avec validation trajectoire + ForceGuard. Utiliser pour exécuter un programme que tu viens de générer. Remplace le programme actuellement chargé.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'gcode': {
            'type': 'string',
            'description': 'Programme complet, lignes séparées par des retours à la ligne.'
          },
        },
        'required': ['gcode'],
      },
      category: AiActionCategory.streaming,
      execute: (input, ref) async {
        final code = (input['gcode'] as String?)?.trim() ?? '';
        if (code.isEmpty) return 'ERREUR: G-code vide';
        await ref.read(gcodeProvider.notifier).loadFile(code);
        final r = await ref.read(streamingProvider.notifier).startStream();
        if (r.isValid) return 'OK: programme chargé et exécution démarrée';
        final line = r.errorLine != null ? ' (ligne ${r.errorLine})' : '';
        return 'REFUSÉ: ${r.errorMessage}$line';
      },
    ),
    AiTool(
      name: 'stop_program',
      description:
          'Arrête l\'exécution du programme en cours (stoppe le streaming). N\'est pas un arrêt d\'urgence — utiliser emergency_stop pour un arrêt immédiat.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        await ref.read(streamingProvider.notifier).stopStream();
        return 'OK: exécution stoppée';
      },
    ),
    AiTool(
      name: 'set_spindle',
      description:
          'Commande la broche : marche (M3), anti-horaire (M4) ou arrêt (M5). '
          'Cette machine a une broche À RELAIS (tout-ou-rien) : la vitesse S '
          'n\'est pas variable, mais elle DOIT être > 0 pour allumer (M3 seul = '
          'S0 n\'allume pas). rpm par défaut = 1000.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'state': {'type': 'string', 'enum': ['cw', 'ccw', 'off']},
          'rpm': {
            'type': 'number',
            'description':
                'Vitesse S (ignoré si off). Broche relais : doit être > 0 ; '
                'défaut 1000.'
          },
        },
        'required': ['state'],
      },
      category: AiActionCategory.spindleCoolant,
      execute: (input, ref) async {
        final st = input['state'] as String;
        String cmd;
        if (st == 'off') {
          cmd = 'M5';
        } else {
          // Broche à relais : S doit être > 0 pour coller le relais.
          final rpm = (input['rpm'] as num?)?.toInt() ?? 1000;
          final s = rpm > 0 ? rpm : 1000;
          cmd = '${st == 'cw' ? 'M3' : 'M4'} S$s';
        }
        await ref.read(machineRepositoryProvider).sendGCode(cmd);
        return 'OK: $cmd';
      },
    ),
    AiTool(
      name: 'set_coolant',
      description:
          'Commande l\'arrosage : brouillard (M7), liquide (M8), ou arrêt (M9).',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'mode': {'type': 'string', 'enum': ['mist', 'flood', 'off']},
        },
        'required': ['mode'],
      },
      category: AiActionCategory.spindleCoolant,
      execute: (input, ref) async {
        final m = input['mode'] as String;
        final cmd = m == 'mist'
            ? 'M7'
            : m == 'flood'
                ? 'M8'
                : 'M9';
        await ref.read(machineRepositoryProvider).sendGCode(cmd);
        return 'OK: $cmd';
      },
    ),
    AiTool(
      name: 'goto_position',
      description:
          'Déplace la machine vers une position ABSOLUE (une ou plusieurs coordonnées parmi X,Y,Z en mm et A,C en degrés), en rapide (G0) ou en travail (G1). En travail, feedrate requis.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'x': {'type': 'number'},
          'y': {'type': 'number'},
          'z': {'type': 'number'},
          'a': {'type': 'number'},
          'c': {'type': 'number'},
          'rapid': {
            'type': 'boolean',
            'description': 'true = G0 (rapide, défaut), false = G1 (travail).'
          },
          'feedrate': {
            'type': 'number',
            'description': 'mm/min — requis si non rapide.'
          },
        },
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        final rapid = input['rapid'] as bool? ?? true;
        final buf = StringBuffer('G90 ${rapid ? 'G0' : 'G1'}');
        var any = false;
        for (final e in const {
          'x': 'X',
          'y': 'Y',
          'z': 'Z',
          'a': 'A',
          'c': 'C'
        }.entries) {
          final v = input[e.key];
          if (v is num) {
            buf.write(' ${e.value}$v');
            any = true;
          }
        }
        if (!any) return 'ERREUR: aucune coordonnée fournie';
        if (!rapid) {
          final f = (input['feedrate'] as num?)?.toInt();
          if (f == null) return 'ERREUR: feedrate requis en mode travail (G1)';
          buf.write(' F$f');
        }
        await ref.read(machineRepositoryProvider).sendGCode(buf.toString());
        return 'OK: ${buf.toString()}';
      },
    ),
    AiTool(
      name: 'set_work_zero',
      description:
          'Définit la position ACTUELLE comme zéro pièce (origine) pour les axes indiqués, dans le WCS actif (G10 L20). Absent = X, Y, Z.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'axes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Ex ["X","Y","Z"]. Absent = X, Y, Z.',
          },
        },
      },
      category: AiActionCategory.wcsTool,
      execute: (input, ref) async {
        final axes = (input['axes'] as List?)?.cast<String>() ?? const ['X', 'Y', 'Z'];
        if (axes.isEmpty) return 'ERREUR: liste d\'axes vide';
        final words = axes.map((a) => '${a.toUpperCase()}0').join(' ');
        await ref.read(machineRepositoryProvider).sendGCode('G10 L20 P0 $words');
        return 'OK: origine posée sur $axes';
      },
    ),
    AiTool(
      name: 'probe',
      description:
          'Palpage G38.2 : déplace un axe jusqu\'au contact du palpeur (distance relative signée, mm pour X/Y/Z, degrés pour A/C), à la vitesse donnée. Retourne la position de contact [X,Y,Z,A,C], ou une erreur si aucun contact. Retrait de sécurité de 2 mm après contact.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'axis': {'type': 'string', 'enum': _axisEnum},
          'distance': {
            'type': 'number',
            'description': 'Distance max de recherche, signée (relatif).'
          },
          'feedrate': {
            'type': 'number',
            'description': 'Vitesse de palpage en mm/min (défaut 100).'
          },
        },
        'required': ['axis', 'distance'],
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        final repo = ref.read(machineRepositoryProvider);
        final axis = (input['axis'] as String).toUpperCase();
        final dist = (input['distance'] as num).toDouble();
        final feed = (input['feedrate'] as num?)?.toInt() ?? 100;

        final completer = Completer<Map<String, dynamic>?>();
        final sub = repo.messageStream.listen((msg) {
          final report = GrblParser.parseProbeReport(msg);
          if (report != null && !completer.isCompleted) {
            completer.complete(report);
          }
        });
        await repo.sendGCode('G21 G91 G38.2 $axis$dist F$feed');
        Map<String, dynamic>? report;
        try {
          report = await completer.future.timeout(const Duration(seconds: 30));
        } catch (_) {
          report = null;
        } finally {
          await sub.cancel();
        }

        if (report == null) {
          return 'ERREUR: pas de rapport de palpage (timeout / hors ligne)';
        }
        if (report['success'] != true) {
          return 'ÉCHEC: contact non établi (course épuisée sans toucher le palpeur)';
        }
        // Retrait de sécurité de 2 mm dans le sens opposé au palpage.
        final dir = dist >= 0 ? 1 : -1;
        await repo.sendGCode('G91 G0 $axis${-2.0 * dir}');
        final coords =
            (report['coords'] as List).map((e) => (e as num).toDouble()).toList();
        return jsonEncode({'contact': true, 'axis': axis, 'probePos': coords});
      },
    ),
    AiTool(
      name: 'read_settings',
      description:
          'Lit les paramètres numériques bruts de la machine (commande \$\$) : renvoie les lignes \$N=valeur telles que retournées par FluidNC/GRBL. Pour la configuration détaillée (câblage, moteurs), préférer get_config.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: null,
      execute: (input, ref) async {
        final repo = ref.read(machineRepositoryProvider);
        final lines = <String>[];
        final sub = repo.messageStream.listen((m) {
          final t = m.trim();
          if (t.startsWith('\$') && t.contains('=')) lines.add(t);
        });
        repo.sendRaw('\$\$\n');
        await Future.delayed(const Duration(milliseconds: 1200));
        await sub.cancel();
        if (lines.isEmpty) {
          return 'Aucun paramètre reçu (machine hors ligne ?). La config détaillée '
              'est disponible via get_config.';
        }
        return jsonEncode({'settings': lines});
      },
    ),
    AiTool(
      name: 'get_camera_snapshot',
      description:
          'Capture une image de la zone de coupe avec la caméra de surveillance et te la montre. '
          'Sert à vérifier de tes yeux ce que les capteurs ne disent pas : bridage de la pièce, '
          'accumulation de copeaux, état de l\'outil, présence de l\'opérateur dans la zone, '
          'aspect réel d\'une passe en cours. L\'image est accompagnée de la position et de l\'état '
          'machine au moment de la prise. Échoue si aucune caméra n\'est configurée.',
      inputSchema: const {'type': 'object', 'properties': {}},
      // Lecture seule : prendre une photo ne touche pas la machine, l'outil
      // reste donc utilisable sans confirmation, comme get_machine_state.
      category: null,
      producesImage: true,
      execute: (input, ref) async {
        if (!ref.read(cameraEnabledProvider)) {
          return 'Erreur: aucune caméra n\'est configurée sur cette machine.';
        }

        final bytes = await ref.read(cameraRepositoryProvider).snapshot();
        ref.read(aiToolImageProvider.notifier).state =
            AiToolImage(bytes: bytes);

        // La photo seule ne vaut pas grand-chose : sans savoir où était l'outil
        // au moment du déclenchement, l'agent ne peut pas relier ce qu'il voit
        // à ce que fait la machine.
        final s = ref.read(machineRepositoryProvider).currentState;
        return jsonEncode({
          'captured': true,
          'sizeBytes': bytes.length,
          'status': s.status.name,
          'wPos': s.wPos,
          'spindleSpeed': s.spindleSpeed,
          'feedrate': s.feedrate,
          'note': 'Image jointe à ce tour.',
        });
      },
    ),
    AiTool(
      name: 'unlock_alarm',
      description:
          'Déverrouille la machine après une alarme (\$X). Requis avant de bouger si l\'état est ALARM. À n\'utiliser qu\'après avoir vérifié qu\'il est sûr de reprendre.',
      inputSchema: const {'type': 'object', 'properties': {}},
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        ref.read(machineRepositoryProvider).sendRaw('\$X\n');
        return 'OK: déverrouillage envoyé (\$X)';
      },
    ),
  ];

  static AiTool? byName(String name) {
    for (final tool in tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
