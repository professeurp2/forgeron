import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_agent_settings_provider.dart';
import '../providers/di_providers.dart';

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

  const AiTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.category,
    required this.execute,
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
        await ref.read(machineRepositoryProvider).jog(
              input['axis'] as String,
              (input['distance'] as num).toDouble(),
              (input['feedrate'] as num).toDouble(),
            );
        return 'OK';
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
        final ok = await ref.read(machineRepositoryProvider).emergencyStop();
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
  ];

  static AiTool? byName(String name) {
    for (final tool in tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
