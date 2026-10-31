import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/fluidnc/grbl_parser.dart';
import '../providers/reco3d_provider.dart';
import '../providers/simulation_provider.dart';
import '../providers/ai_agent_settings_provider.dart';
import '../providers/ai_artifacts_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/di_providers.dart';
import '../providers/gcode_provider.dart';
import '../providers/streaming_provider.dart';
import '../providers/firmware_provider.dart';
import '../providers/network_stats_provider.dart';
import '../providers/config_provider.dart';
import '../providers/docs_provider.dart';
import 'docs_prefetch.dart';
import '../providers/machine_params_provider.dart';
import '../providers/activity_log_provider.dart';
import '../providers/jog_provider.dart';
import '../providers/workspace_provider.dart';
import '../../core/i18n/app_language.dart';
import '../../core/i18n/translations/translations.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_adapter.dart';
import '../../core/utils/gcode_command_guard.dart';
import '../../domain/models/machine_state.dart';
import 'ai_window_launcher.dart';
import 'cam_pipeline_service.dart';
import 'medical_implant_service.dart';
import 'prismatic_pipeline_service.dart';
import 'step_pipeline_service.dart';
import 'step_preview_service.dart';

/// État de la machine tel que l'agent le lit. Partagé par l'outil
/// `get_machine_state` et par le bloc « état actuel » du prompt : les deux
/// montrent exactement la même chose, ou le modèle recevrait deux vérités.
Map<String, dynamic> machineStateMap(MachineState s) => {
      'status': s.status.name,
      'wPos': s.wPos,
      'mPos': s.mPos,
      'activeWCS': s.activeWCS,
      'activeToolNum': s.activeToolNum,
      'feedrate': s.feedrate,
      'spindleSpeed': s.spindleSpeed,
      'overrides': s.overrides,
      'alarmCode': s.alarmCode,
    };

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

/// Une popup que l'agent veut montrer — un point à souligner en dehors du
/// fil de discussion (avertissement, résumé). Même logique de boîte aux
/// lettres que [aiToolImageProvider] : l'outil dépose la demande, l'écran
/// (seul détenteur d'un `BuildContext`) l'affiche puis la vide.
class AiPopupRequest {
  const AiPopupRequest({required this.title, required this.message, this.severity = 'info'});

  final String title;
  final String message;

  /// 'info' | 'warning' | 'danger' — détermine l'icône/couleur affichées.
  final String severity;
}

final aiPopupRequestProvider = StateProvider<AiPopupRequest?>((ref) => null);

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
        return jsonEncode(machineStateMap(s));
      },
    ),
    AiTool(
      name: 'search_docs',
      description:
          'Cherche dans les fiches (alarmes, G-code, broche, câblage, sécurité). '
          'Au plus 3 fiches avec identifiant et source : cite l\'identifiant. Liste vide = '
          'tu ne sais pas, n\'invente rien.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Mots-clés français (ex. alarme 9)'
          },
        },
        'required': ['query'],
      },
      category: null,
      execute: (input, ref) async {
        final query = ('${input['query'] ?? ''}').trim();
        if (query.isEmpty) return 'ERREUR: « query » obligatoire (mots-clés).';
        final corpus = await ref.read(docCorpusProvider.future);
        return searchDocsResult(corpus.index, query);
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
          'Jamais pour y mettre un programme NOUVEAU rédigé par toi. '
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
      description: 'HOMING : la machine SE DÉPLACE vers ses capteurs de fin de course pour retrouver son origine MACHINE. À utiliser seulement quand l\'opérateur demande le homing ou la prise d\'origine des axes — PAS pour poser le zéro pièce (c\'est set_work_zero). Axes indiqués, ou tous les axes configurés si la liste est vide/absente.',
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
        final line = input['gcode'] as String;
        // Jamais d'écriture des réglages du micrologiciel par l'agent
        // ($RST=*, $20=0…) : mesuré, le modèle local l'a tenté (voir le garde).
        final why = GcodeCommandGuard.refusal(line);
        if (why != null) return 'REFUSÉ (sécurité) : $why';
        await ref.read(machineRepositoryProvider).sendGCode(line);
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
          'Charge le programme G-code fourni (plusieurs lignes) PUIS l\'exécute, avec validation trajectoire + ForceGuard. Réservé à un programme que l\'OPÉRATEUR t\'a donné mot pour mot : jamais un programme rédigé par toi (une coordonnée fausse peut casser la machine). Remplace le programme actuellement chargé.',
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
        final why = GcodeCommandGuard.refusalInProgram(code);
        if (why != null) return 'REFUSÉ (sécurité) : $why';
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
          'state': {
            'type': 'string',
            'enum': ['cw', 'ccw', 'off'],
            'description':
                'OBLIGATOIRE. « cw » pour allumer (sens horaire), « off » pour éteindre.'
          },
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
        // Mesuré : un petit modèle omet parfois ce champ pourtant obligatoire.
        // Un message clair lui permet de se corriger ; un cast raté, non.
        final st = input['state'] as String?;
        if (st != 'cw' && st != 'ccw' && st != 'off') {
          return 'ERREUR: « state » obligatoire : cw (allumer), ccw ou off (éteindre).';
        }
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
          'Définit la position ACTUELLE comme zéro pièce (« origine pièce », « zéro ici ») pour les axes indiqués, dans le WCS actif (G10 L20). AUCUN mouvement : la machine ne bouge pas. Absent = X, Y, Z.',
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

    // ── Pipeline CAO : STEP -> G-code, révolution (5.b) ou prismatique (5.c) ─
    AiTool(
      name: 'run_step_pipeline',
      description:
          'Lit un fichier STEP ou STL et génère le G-code : pièces de révolution, prismatiques ou implants médicaux sur mesure (ébauche 3 axes + finition 5 axes). Charge automatiquement le programme dans la machine. Le rapport donne (\'pipeline\', \'gcode_path\', \'lignes_gcode\'). Prêt à être exécuté immédiatement sur la machine avec run_program.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'stepPath': {'type': 'string', 'description': 'Chemin absolu du fichier .step/.stp ou .stl'},
          'toolDiameter': {'type': 'number', 'description': 'Diamètre de la fraise boule, mm (défaut 6)'},
          'ap': {'type': 'number', 'description': 'Profondeur de passe ébauche, mm (défaut 0.2, 0.15 en PEEK). Plafond vibratoire machine.'},
          'ae': {'type': 'number', 'description': 'Engagement radial ébauche, mm (défaut 0.5)'},
          'stepover': {'type': 'number', 'description': 'Pas de finition sur la surface, mm (défaut 0.4)'},
          'stockRadius': {'type': 'number', 'description': 'Rayon du barreau brut, mm (optionnel pour les pièces de révolution).'},
        },
        'required': ['stepPath'],
      },
      category: null,
      execute: (input, ref) async {
        final stepPath = ((input['stepPath'] ??
                input['file_path'] ??
                input['filePath'] ??
                input['path']) as String?)
            ?.trim() ??
            '';
        if (stepPath.isEmpty) return 'Erreur: argument stepPath manquant.';
        try {
          final report = await CamPipelineService.run(
            stepPath,
            toolDiameter: (input['toolDiameter'] as num?)?.toDouble() ?? 6.0,
            ap: (input['ap'] as num?)?.toDouble() ?? 0.2,
            ae: (input['ae'] as num?)?.toDouble() ?? 0.5,
            stepover: (input['stepover'] as num?)?.toDouble() ?? 0.4,
            stockRadius: (input['stockRadius'] as num?)?.toDouble(),
          );
          final artifacts = ref.read(aiArtifactsProvider.notifier);
          artifacts.setGcodeFromReport(report);
          unawaited(artifacts.loadStep(stepPath));

          // Charger le programme G-code fini dans le contrôleur de la machine
          // pour permettre son exécution immédiate (run_program) en langage naturel.
          final gcodePath = report['gcode_path'] as String?;
          if (gcodePath != null && File(gcodePath).existsSync()) {
            final content = await File(gcodePath).readAsString();
            await ref.read(gcodeProvider.notifier).loadFile(content);
          }

          return jsonEncode({
            ...report,
            'programme_charge_dans_machine': true,
            'action_suivante': 'Le programme G-code est chargé dans la machine. '
                'L\'opérateur peut demander son exécution (run_program) en langage naturel quand il est prêt.',
          });
        } on StepPipelineException catch (e) {
          return 'Erreur: $e';
        } on PrismaticPipelineException catch (e) {
          return 'Erreur: $e';
        } on MedicalImplantException catch (e) {
          return 'Erreur: $e';
        }
      },
    ),

    // ── Expression de l'agent : popup, graphique, fenêtre détachée ────────
    // Trois outils « bénins » (aucune action machine, catégorie null =
    // toujours autorisés) qui donnent à l'agent un moyen de s'exprimer
    // au-delà du texte, sur desktop. Sur mobile/web, AiWindowLauncher répond
    // simplement que la fenêtre n'est pas disponible — l'agent le lit et
    // peut se rabattre sur du texte.
    AiTool(
      name: 'preview_step_file',
      description:
          'Affiche l\'aperçu 3D d\'un fichier STEP ou STL dans un panneau à côté de la discussion (desktop uniquement) : la pièce est facettisée puis affichée telle quelle, AVANT tout usinage. À utiliser dès qu\'un fichier 3D est mentionné, pour que l\'opérateur voie ce qui a été chargé — et pour vérifier soi-même que le fichier contient bien la pièce attendue. Retourne l\'encombrement, le volume et le nombre de triangles.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'stepPath': {'type': 'string', 'description': 'Chemin absolu du fichier .step/.stp ou .stl'},
        },
        'required': ['stepPath'],
      },
      category: null,
      execute: (input, ref) async {
        final path = ((input['stepPath'] ??
                input['file_path'] ??
                input['filePath'] ??
                input['path']) as String?)
            ?.trim() ??
            '';
        if (path.isEmpty) return 'Erreur: argument stepPath manquant.';
        try {
          final preview = await StepPreviewService.run(path);
          // `loadStep` retrouve le maillage dans le cache disque que vient de
          // remplir `run` : le panneau reçoit donc sa pièce tout de suite, et
          // rouvrir l'aperçu ensuite ne refacettise rien.
          final artifacts = ref.read(aiArtifactsProvider.notifier);
          await artifacts.loadStep(path);
          artifacts.dock(AiDockedViewer.step);
          return jsonEncode({
            'affichage': 'Aperçu affiché dans la console, à côté de la discussion.',
            'encombrement_mm': preview.size,
            'volume_mm3': preview.volume,
            'triangles': preview.triangles,
          });
        } on StepPreviewException catch (e) {
          return 'Erreur: $e';
        }
      },
    ),
    AiTool(
      name: 'open_toolpath_window',
      description:
          'Affiche le parcours d\'outil d\'un programme G-code en 3D, dans un panneau à côté de la discussion (desktop uniquement) — le tracé réel et lui seul, rapides en rouge et passes de travail en vert. À utiliser après avoir généré un programme, pour que l\'opérateur voie le parcours plutôt que d\'avoir à lire des lignes de G-code. La pièce n\'y est pas dessinée : elle masquerait les passes. Pour la voir, c\'est preview_step_file.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'gcodePath': {'type': 'string', 'description': 'Chemin absolu du fichier .nc / .gcode'},
        },
        'required': ['gcodePath'],
      },
      category: null,
      execute: (input, ref) async {
        final gcodePath = ((input['gcodePath'] ??
                input['path'] ??
                input['file_path'] ??
                input['filePath']) as String?)
            ?.trim() ??
            '';
        if (gcodePath.isEmpty) return 'Erreur: argument gcodePath manquant.';
        final artifacts = ref.read(aiArtifactsProvider.notifier);
        artifacts.setGcodePath(gcodePath);
        artifacts.dock(AiDockedViewer.toolpath);
        final name = gcodePath.split(RegExp(r'[/\\]')).last;
        return 'Parcours « $name » affiché dans la console, à côté de la discussion.';
      },
    ),
    AiTool(
      name: 'show_popup',
      description:
          'Affiche un message important dans une popup, en dehors du fil de discussion — pour un avertissement ou un résumé qui mérite d\'être vu, pas juste lu au milieu du texte.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'message': {'type': 'string'},
          'severity': {'type': 'string', 'enum': ['info', 'warning', 'danger']},
        },
        'required': ['title', 'message'],
      },
      category: null,
      execute: (input, ref) async {
        ref.read(aiPopupRequestProvider.notifier).state = AiPopupRequest(
          title: input['title'] as String,
          message: input['message'] as String,
          severity: input['severity'] as String? ?? 'info',
        );
        return 'Popup affichée.';
      },
    ),
    AiTool(
      name: 'open_chart_window',
      description:
          'Ouvre un graphique dans une fenêtre séparée (desktop uniquement) pour montrer l\'évolution d\'une mesure ou comparer des valeurs — plus lisible qu\'une liste de chiffres dans le texte.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'labels': {'type': 'array', 'items': {'type': 'string'}},
          'values': {'type': 'array', 'items': {'type': 'number'}},
          'unit': {'type': 'string'},
        },
        'required': ['title', 'labels', 'values'],
      },
      category: null,
      execute: (input, ref) async {
        return AiWindowLauncher.openChart(
          title: input['title'] as String,
          labels: ((input['labels'] as List?) ?? const []).map((e) => e.toString()).toList(),
          values: ((input['values'] as List?) ?? const [])
              .map((e) => (e as num).toDouble())
              .toList(),
          unit: input['unit'] as String? ?? '',
        );
      },
    ),
    AiTool(
      name: 'open_gcode_window',
      description:
          'Ouvre un programme G-code dans sa propre fenêtre (desktop uniquement), détachée du fil de discussion — utile pour le garder visible à côté du visualiseur pendant que la conversation continue.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['title', 'content'],
      },
      category: null,
      execute: (input, ref) async {
        return AiWindowLauncher.openGcode(
          title: input['title'] as String,
          content: input['content'] as String,
        );
      },
    ),
    AiTool(
      name: 'set_app_language',
      description:
          'Change la langue de TOUTE l\'interface, de tes réponses, de la dictée et '
          'de la voix, tout de suite et durablement. À utiliser quand l\'opérateur le '
          'demande, ou UNE SEULE FOIS quand il t\'écrit dans une langue de la liste '
          'alors que l\'interface est dans une autre (dis-le-lui dans sa langue, avec '
          'Paramètres > Langue pour revenir). Pas pour un mot étranger isolé, une '
          'langue absente, ni pendant un usinage. Codes : auto, fr, en, ar, sw, af, '
          'am, ha, yo, ig, zu, so, rw, sn, ln, wo, mg, bm (« auto » = langue du '
          'téléphone) ; tout autre code est refusé. La réponse donne le nombre de '
          'libellés traduits : si c\'est partiel, le reste reste en français — dis-le.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'language': {
            'type': 'string',
            'description':
                'Code de langue ISO 639-1 (« bm », « sw »…) ou « auto ».',
          },
        },
        'required': ['language'],
      },
      // Pas de catégorie : changer une langue ne fait pas bouger la machine et
      // se défait en deux touches. Le geste est tout de même journalisé, pour
      // qu'un pupitre qui change de langue tout seul soit traçable.
      category: null,
      execute: (input, ref) async {
        final brut = (input['language'] as String? ?? '').trim().toLowerCase();
        // « fr-FR », « fr_FR » → « fr » : les modèles donnent souvent la
        // forme régionale.
        final code = brut.split(RegExp(r'[-_]')).first;

        final connue = kAppLanguages.any((l) => l.id == code);
        if (code.isEmpty || !connue) {
          return jsonEncode({
            'ok': false,
            'raison': 'Code de langue inconnu : « $brut ». Aucun changement.',
            'codes_acceptes': kAppLanguages.map((l) => l.id).toList(),
          });
        }

        final avant = ref.read(appLanguageProvider);
        if (avant.id == code) {
          return jsonEncode({
            'ok': true,
            'change': false,
            'langue': avant.id,
            'libelle': avant.label,
            'note': 'L\'interface est déjà dans cette langue.',
          });
        }

        final apres = appLanguageById(code);
        await ref.read(appLanguageProvider.notifier).select(apres);
        ref.read(activityLogProvider.notifier).log(
            'Agent IA : langue de l\'interface ${avant.id} → ${apres.id}');

        final traduites = kAppTranslations[apres.id]?.length ?? 0;
        return jsonEncode({
          'ok': true,
          'change': true,
          'precedente': avant.id,
          'langue': apres.id,
          'libelle': apres.label,
          // Le français est la langue source : il n'a pas de dictionnaire.
          'libelles_traduits': apres.id == 'fr' ? 'source' : traduites,
          'relu_par_un_locuteur': false,
          'retour_arriere': 'Paramètres > Langue',
        });
      },
    ),

    // ── Scan 3D & Numérisation en machine (Jalon 5) ──────────────────────────
    AiTool(
      name: 'get_reco3d_status',
      description:
          'Interroge l\'état du poste de calcul de reconstruction 3D (reco3d) : '
          'vérifie la connexion, le GPU disponible (nom, VRAM libre), la file d\'attente '
          'et les moteurs installés (Meshroom photogrammétrie métrique, OCP/Trimesh '
          'forme conceptuelle).',
      inputSchema: const {
        'type': 'object',
        'properties': {},
      },
      category: null,
      execute: (input, ref) async {
        final client = ref.read(reco3dClientProvider);
        final rawUrl = ref.read(reco3dServerUrlProvider);
        try {
          final uri = Uri.parse(rawUrl);
          final health = await client.checkHealth(uri);
          return jsonEncode({
            'ok': true,
            'serveur_url': rawUrl,
            'status': health.status,
            'gpu': health.gpuName,
            'vram_libre_mb': health.gpuVramFreeMb,
            'queue_length': health.queueLength,
            'job_actif': health.activeJobId,
            'moteurs': health.engines,
          });
        } catch (e) {
          return jsonEncode({
            'ok': false,
            'serveur_url': rawUrl,
            'erreur': 'Poste de calcul injoignable : $e',
            'action_conseillee':
                'Vérifier que le serveur reco3d est démarré sur le PC (port 8765) '
                'et que le téléphone et le PC sont sur le même réseau Wi-Fi.',
          });
        }
      },
    ),

    AiTool(
      name: 'discover_reco3d_server',
      description:
          'Lance la découverte automatique du poste de calcul Scan 3D / Reco3D sur le réseau local '
          '(broadcast UDP + scan rapide des adresses IPv4) et met à jour l\'URL active.',
      inputSchema: const {
        'type': 'object',
        'properties': {},
      },
      category: null,
      execute: (input, ref) async {
        final client = ref.read(reco3dClientProvider);
        final found = await client.discoverServer();
        if (found != null) {
          ref.read(reco3dServerUrlProvider.notifier).state = found;
          ref.invalidate(reco3dHealthProvider);
          return jsonEncode({
            'ok': true,
            'serveur_url': found,
            'message': 'Poste de calcul détecté et configuré avec succès : $found',
          });
        }
        return jsonEncode({
          'ok': false,
          'message': 'Aucun poste de calcul détecté sur le réseau local. Vérifiez que le PC et le téléphone sont sur le même sous-réseau.',
        });
      },
    ),

    AiTool(
      name: 'start_machine_scan',
      description:
          'Lance un scan 3D automatique en machine (doc §12, Jalon 5) : le maître à reproduire '
          'est bridé sur le plateau. Le serveur reco3d commande la rotation des axes A/C par angles '
          'connus et capture via les caméras embarquées pour reconstruire la pièce en '
          'multi-vues calibrées. Course A autorisée : [-88.0, +90.0]°. Mouvement physique '
          'du plateau : requiert confirmation de l\'opérateur.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'poses': {
            'type': 'integer',
            'description': 'Nombre de poses de rotation C (ex. 8, 12, 16, 24). Défaut : 12.'
          },
          'aDeg': {
            'type': 'number',
            'description': 'Angle d\'inclinaison A en degrés, borné entre -88.0 et +90.0. Défaut : 0.0.'
          },
          'cameraUrl': {
            'type': 'string',
            'description': 'URL HTTP de la caméra ESP32-CAM (ex. http://192.168.0.50/capture). Si omise, utilise le flux de capture réseau ou la simulation.'
          },
          'synthetic': {
            'type': 'boolean',
            'description': 'True pour exécuter en simulation pure (caméra synthétique, test de plomberie sans matériel).'
          },
        },
      },
      category: AiActionCategory.movement,
      execute: (input, ref) async {
        final client = ref.read(reco3dClientProvider);
        final rawUrl = ref.read(reco3dServerUrlProvider);
        final uri = Uri.parse(rawUrl);

        final poses = (input['poses'] as num?)?.toInt() ?? 12;
        final aDeg = (input['aDeg'] as num?)?.toDouble() ?? 0.0;
        final cameraUrl = input['cameraUrl'] as String?;
        final synthetic = (input['synthetic'] as bool?) ?? false;

        if (aDeg < -88.0 || aDeg > 90.0) {
          return jsonEncode({
            'ok': false,
            'erreur': 'Angle A (${aDeg.toStringAsFixed(1)}°) hors course machine [-88.0, +90.0]°.',
          });
        }

        try {
          final job = await client.startMachineScan(
            baseUri: uri,
            poses: poses,
            aDeg: aDeg,
            cameraUrl: cameraUrl,
            synthetic: synthetic,
          );
          ref.read(activityLogProvider.notifier).log(
              'Agent IA : scan en machine lancé (${job.jobId}, $poses poses, A=$aDeg°)');
          return jsonEncode({
            'ok': true,
            'job_id': job.jobId,
            'mode': job.mode,
            'queue_position': job.queuePosition,
            'message': job.message,
            'notes': 'Job lancé. Utilise get_scan_job_status avec jobId: "${job.jobId}" pour suivre la reconstruction.',
          });
        } catch (e) {
          return jsonEncode({
            'ok': false,
            'erreur': 'Échec du démarrage du scan en machine : $e',
          });
        }
      },
    ),

    AiTool(
      name: 'get_scan_job_status',
      description:
          'Récupère l\'état et la progression d\'un job de scan 3D / reconstruction sur le poste '
          'de calcul reco3d (étape en cours, progression %, fichiers STL/STEP disponibles, '
          'notes d\'honnêteté et de provenance géométrique).',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'jobId': {
            'type': 'string',
            'description': 'Identifiant du job retourné par start_machine_scan (ex. job_a1b2c3d4).'
          },
        },
        'required': ['jobId'],
      },
      category: null,
      execute: (input, ref) async {
        final jobId = input['jobId'] as String;
        final client = ref.read(reco3dClientProvider);
        final rawUrl = ref.read(reco3dServerUrlProvider);
        final uri = Uri.parse(rawUrl);

        try {
          final status = await client.getJobStatus(uri, jobId);
          return jsonEncode({
            'job_id': status.jobId,
            'stage': status.stage,
            'progress_percent': status.progressPercent,
            'message': status.message,
            'has_mesh': status.hasMesh,
            'has_step': status.hasStep,
            'error': status.error,
            'provenance': status.provenance != null
                ? {
                    'mode': status.provenance!.mode,
                    'is_approximate': status.provenance!.isApproximate,
                    'notes': status.provenance!.notes,
                  }
                : null,
          });
        } catch (e) {
          return jsonEncode({
            'ok': false,
            'erreur': 'Impossible de récupérer l\'état du job $jobId : $e',
          });
        }
      },
    ),

    AiTool(
      name: 'download_scan_result',
      description:
          'Télécharge le résultat 3D d\'un job terminé depuis le poste de calcul reco3d '
          '(format "step" pour solide CAO OpenCASCADE ou "mesh" pour maillage triangulé STL). '
          'Charge automatiquement le fichier STEP dans le visualiseur 3D de l\'agent.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'jobId': {
            'type': 'string',
            'description': 'Identifiant du job terminé (ex. job_a1b2c3d4).'
          },
          'format': {
            'type': 'string',
            'enum': ['step', 'mesh'],
            'description': 'Format souhaité : "step" (.step solide) ou "mesh" (.stl).'
          },
        },
        'required': ['jobId'],
      },
      category: null,
      execute: (input, ref) async {
        final jobId = input['jobId'] as String;
        final format = (input['format'] as String? ?? 'step').toLowerCase();
        final client = ref.read(reco3dClientProvider);
        final rawUrl = ref.read(reco3dServerUrlProvider);
        final uri = Uri.parse(rawUrl);

        try {
          final dir = await getApplicationDocumentsDirectory();
          final ext = format == 'step' ? 'step' : 'stl';
          final dest = File('${dir.path}${Platform.pathSeparator}${jobId}_result.$ext');

          await client.downloadResult(uri, jobId, format: format, destination: dest);

          if (format == 'step') {
            final artifacts = ref.read(aiArtifactsProvider.notifier);
            await artifacts.loadStep(dest.path);
            artifacts.dock(AiDockedViewer.step);
          }

          ref.read(activityLogProvider.notifier).log(
              'Agent IA : fichier 3D téléchargé (${dest.path.split(Platform.pathSeparator).last})');

          return jsonEncode({
            'ok': true,
            'job_id': jobId,
            'format': format,
            'fichier_local': dest.path,
            'taille_octets': dest.lengthSync(),
            'message': 'Modèle 3D téléchargé avec succès${format == "step" ? " et affiché dans le panneau 3D de l'agent" : ""}.',
          });
        } catch (e) {
          return jsonEncode({
            'ok': false,
            'erreur': 'Échec du téléchargement du résultat pour $jobId : $e',
          });
        }
      },
    ),

    // ────────────────────────── SIMULATION 3D & CAMÉRA ─────────────────────
    AiTool(
      name: 'run_machining_simulation',
      description:
          'Configure le brut pré-usinage (cylindrique ou parallélépipédique/cuboid), '
          'ouvre le Jumeau Numérique 3D dans le panneau Simulateur, lance la simulation '
          'd\'enlèvement de matière en accéléré et retourne un rapport complet '
          '(durée estimée, nombre de segments, détection de collisions G0 dans le brut '
          'et dépassements de course machine). À utiliser avant l\'usinage réel ou quand '
          'l\'opérateur demande de simuler le parcours.',
      category: null,
      inputSchema: {
        'type': 'object',
        'properties': {
          'stock_shape': {
            'type': 'string',
            'enum': ['cylinder', 'cuboid'],
            'description': 'Forme du brut : "cylinder" (cylindre) ou "cuboid" (bloc parallélépipédique).',
          },
          'diameter_mm': {
            'type': 'number',
            'description': 'Diamètre du brut cylindrique en mm (défaut: 80).',
          },
          'width_mm': {
            'type': 'number',
            'description': 'Largeur X du brut parallélépipédique en mm (défaut: 80).',
          },
          'depth_mm': {
            'type': 'number',
            'description': 'Profondeur Y du brut parallélépipédique en mm (défaut: 80).',
          },
          'height_mm': {
            'type': 'number',
            'description': 'Hauteur Z du brut en mm (défaut: 50).',
          },
          'tool_diameter_mm': {
            'type': 'number',
            'description': 'Diamètre de l\'outil de coupe en mm (défaut: 6).',
          },
          'speed_multiplier': {
            'type': 'number',
            'description': 'Vitesse de lecture de la simulation (ex: 1, 5, 10, 20, 50 ; défaut: 10).',
          },
          'job_name': {
            'type': 'string',
            'description': 'Nom optionnel de la tâche d\'usinage (affiché dans Summary).',
          },
          'batch_size': {
            'type': 'integer',
            'description': 'Nombre de pièces du lot (Batch Size, défaut: 1).',
          },
        },
      },
      execute: (args, ref) async {
        final sim = ref.read(simulationProvider.notifier);
        final shapeStr = (args['stock_shape'] as String?)?.toLowerCase();
        final shape = shapeStr == 'cuboid'
            ? StockShape.cuboid
            : (shapeStr == 'cylinder' ? StockShape.cylinder : null);

        final currentDims = ref.read(simulationProvider).stockDimensions;
        final diam = (args['diameter_mm'] as num?)?.toDouble();
        final w = (args['width_mm'] as num?)?.toDouble() ?? diam ?? currentDims[0];
        final d = (args['depth_mm'] as num?)?.toDouble() ?? diam ?? currentDims[1];
        final h = (args['height_mm'] as num?)?.toDouble() ?? currentDims[2];
        final hasDims = args['diameter_mm'] != null ||
            args['width_mm'] != null ||
            args['depth_mm'] != null ||
            args['height_mm'] != null;

        sim.configureJob(
          jobName: args['job_name'] as String?,
          batchSize: (args['batch_size'] as num?)?.toInt(),
          stockShape: shape,
          stockDimensions: hasDims ? <double>[w, d, h] : null,
          toolDiameter: (args['tool_diameter_mm'] as num?)?.toDouble(),
        );

        // Ouvre le panneau Simulateur 3D à droite de la console IA.
        ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.toolpath);
        ref.read(visualizerModeProvider.notifier).state =
            VisualizerMode.simulation3d;

        final speed = (args['speed_multiplier'] as num?)?.toDouble() ?? 10.0;
        sim.play(speedMultiplier: speed);
        final report = sim.analyzeCurrentProgram();
        ref.read(activityLogProvider.notifier).log(
              'Agent IA : simulation 3D lancée (×${speed.toStringAsFixed(0)})',
            );
        return jsonEncode(report);
      },
    ),

    AiTool(
      name: 'control_simulation',
      description:
          'Contrôle la lecture du simulateur d\'usinage 3D (play, pause, reset, '
          'seek à un pourcentage, changement de vitesse ×1..×50) ou oriente la '
          'caméra 3D via le ViewCube (ISOMETRIC, TOP, FRONT, RIGHT, LEFT, BACK).',
      category: null,
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['play', 'pause', 'reset', 'seek', 'set_speed', 'set_view'],
            'description': 'Action à exécuter sur le simulateur 3D.',
          },
          'progress': {
            'type': 'number',
            'description': 'Position temporelle entre 0.0 (début) et 1.0 (fin) pour "seek".',
          },
          'speed_multiplier': {
            'type': 'number',
            'description': 'Multiplicateur de vitesse (0.25 à 100) pour "set_speed" ou "play".',
          },
          'camera_preset': {
            'type': 'string',
            'enum': ['ISOMETRIC', 'TOP', 'FRONT', 'RIGHT', 'LEFT', 'BACK'],
            'description': 'Vue caméra 3D (ViewCube) pour "set_view".',
          },
        },
        'required': ['action'],
      },
      execute: (args, ref) async {
        final action = (args['action'] as String?) ?? 'play';
        final sim = ref.read(simulationProvider.notifier);
        ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.toolpath);

        switch (action) {
          case 'play':
            if (args['speed_multiplier'] != null) {
              sim.setSpeed((args['speed_multiplier'] as num).toDouble());
            }
            sim.play();
            break;
          case 'pause':
            sim.pause();
            break;
          case 'reset':
            sim.reset();
            break;
          case 'seek':
            final p = (args['progress'] as num?)?.toDouble() ?? 0.0;
            sim.seekPercent(p <= 1.0 ? p * 100.0 : p);
            break;
          case 'set_speed':
            final s = (args['speed_multiplier'] as num?)?.toDouble() ?? 1.0;
            sim.setSpeed(s);
            break;
          case 'set_view':
            final preset = (args['camera_preset'] as String?) ?? 'ISOMETRIC';
            sim.setCameraPreset(preset);
            break;
        }

        final st = ref.read(simulationProvider);
        return jsonEncode({
          'ok': true,
          'action': action,
          'status': st.status.name,
          'progress_percent': double.parse(st.progressPct.toStringAsFixed(1)),
          'speed_multiplier': st.speedMultiplier,
          'camera_preset': st.cameraPreset,
        });
      },
    ),

    AiTool(
      name: 'switch_simulator_camera_tab',
      description:
          'Bascule l\'affichage du panneau droit entre le Simulateur 3D ("simulator") '
          'et le flux vidéo en direct de la caméra ESP32-CAM ("camera").',
      category: null,
      inputSchema: {
        'type': 'object',
        'properties': {
          'tab': {
            'type': 'string',
            'enum': ['simulator', 'camera'],
            'description': 'Onglet à afficher : "simulator" (Jumeau Numérique 3D) ou "camera" (ESP32-CAM).',
          },
        },
        'required': ['tab'],
      },
      execute: (args, ref) async {
        final tabStr = (args['tab'] as String?)?.toLowerCase() ?? 'simulator';
        final isCam = tabStr == 'camera';
        ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.toolpath);
        ref.read(simulationProvider.notifier).setActiveTab(
              isCam ? ConsoleRightTab.camera : ConsoleRightTab.simulator,
            );
        ref.read(visualizerModeProvider.notifier).state =
            isCam ? VisualizerMode.camera : VisualizerMode.simulation3d;
        return jsonEncode({
          'ok': true,
          'active_tab': isCam ? 'camera' : 'simulator',
        });
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
