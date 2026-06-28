import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/macro.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/di_providers.dart';

/// Service de gestion des Macros avec persistance locale et variables dynamiques.
class MacroService extends StateNotifier<List<Macro>> {
  final Ref _ref;
  static const String _storageKey = 'custom_macros';

  MacroService(this._ref) : super([]) {
    _loadMacros();
  }

  Future<void> _loadMacros() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      state = json.map((e) => Macro.fromJson(e)).toList();
    } else {
      // Charger les macros par défaut si vide
      state = defaultMacros;
    }
  }

  Future<void> saveMacro(Macro macro) async {
    final index = state.indexWhere((m) => m.name == macro.name);
    if (index >= 0) {
      state = [...state]..[index] = macro;
    } else {
      state = [...state, macro];
    }
    _persist();
  }

  Future<void> deleteMacro(String name) async {
    state = state.where((m) => m.name != name).toList();
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  /// Exécute une macro en injectant les variables d'environnement actuelles.
  Future<void> executeMacro(Macro macro) async {
    String gcode = macro.gcode;
    
    // Remplacement des variables dynamiques
    final machine = _ref.read(machineRepositoryProvider).currentState;
    
    final variables = {
      r'\$POS_X': machine.wPos[0].toStringAsFixed(3),
      r'\$POS_Y': machine.wPos[1].toStringAsFixed(3),
      r'\$POS_Z': machine.wPos[2].toStringAsFixed(3),
      r'\$MPOS_X': machine.mPos[0].toStringAsFixed(3),
      r'\$MPOS_Y': machine.mPos[1].toStringAsFixed(3),
      r'\$MPOS_Z': machine.mPos[2].toStringAsFixed(3),
      r'\$WCO_X': machine.wco[0].toStringAsFixed(3),
      r'\$WCO_Y': machine.wco[1].toStringAsFixed(3),
      r'\$WCO_Z': machine.wco[2].toStringAsFixed(3),
      r'\$SAFE_Z': '10.000', 
      r'\$TOOL': machine.activeToolNum.toString(),
      r'\$FEED': machine.feedrate.toStringAsFixed(0),
      r'\$SPINDLE': machine.spindleSpeed.toStringAsFixed(0),
    };

    variables.forEach((key, value) {
      gcode = gcode.replaceAll(RegExp(key), value);
    });

    // Envoi via le StreamingService (en batch pour la performance)
    final lines = gcode.split('\n');
    await _ref.read(machineRepositoryProvider).sendGCodeBatch(lines);
  }
}

final macroServiceProvider = StateNotifierProvider<MacroService, List<Macro>>((ref) {
  return MacroService(ref);
});
