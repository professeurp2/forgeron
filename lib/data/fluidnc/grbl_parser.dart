import '../../domain/models/machine_state.dart';

/// Parser GRBL/FluidNC complet pour machine CNC 5-axes Trunnion (X,Y,Z,A,C)
///
/// Formats supportés :
///   Status  : State|MPos:x,y,z,a,c|WCO:...|FS:f,s|Ov:...|Bf:b,c|Lim:XYZAC (entouré de chevrons)
///   Alarme  : ALARM:N
///   Message : [MSG:texte]
///   Modal   : [GC:G0 G54 T1 F1200 S12000]
class GrblParser {
  // ──────────────────────────────────────────────────────────────────────────
  // STATUS REPORT : <State|Field:value|...>
  // ──────────────────────────────────────────────────────────────────────────
  static MachineState? parseStatusReport(
      String message, MachineState currentState) {
    if (!message.startsWith('<') || !message.endsWith('>')) return null;

    final content = message.substring(1, message.length - 1);
    final parts = content.split('|');
    if (parts.isEmpty) return null;

    MachineStatus status = _parseStatus(parts[0]);
    List<double> mPos = List.from(currentState.mPos);
    List<double> wPos = List.from(currentState.wPos);
    List<double> wco = List.from(currentState.wco);
    double feedrate = currentState.feedrate;
    double spindleSpeed = currentState.spindleSpeed;
    List<int> overrides = List.from(currentState.overrides);
    List<bool> limitSwitches = List.from(currentState.limitSwitches);
    int plannerBuffer = currentState.plannerBuffer;
    int rxBuffer = currentState.rxBuffer;
    bool probeTriggered = currentState.probeTriggered;
    bool emergencyTriggered = currentState.emergencyTriggered;
    double sdPercent = currentState.sdPercent;
    String? sdFilename = currentState.sdFilename;

    for (int i = 1; i < parts.length; i++) {
      final field = parts[i];

      if (field.startsWith('MPos:')) {
        final coords =
            field.substring(5).split(',').map(double.tryParse).toList();
        if (coords.length >= 6) {
          // FluidNC : X=0, Y=1, Z=2, A=3, B=4, C=5
          if (coords[0] != null) mPos[0] = coords[0]!;
          if (coords[1] != null) mPos[1] = coords[1]!;
          if (coords[2] != null) mPos[2] = coords[2]!;
          if (coords[3] != null) mPos[3] = coords[3]!;
          if (coords[5] != null) mPos[4] = coords[5]!; // C axis
        } else {
          for (int j = 0; j < coords.length && j < 5; j++) {
            if (coords[j] != null) mPos[j] = coords[j]!;
          }
        }
        // Calculer wPos depuis mPos et wco
        wPos = [for (int j = 0; j < 5; j++) mPos[j] - wco[j]];
      } else if (field.startsWith('WPos:')) {
        final coords =
            field.substring(5).split(',').map(double.tryParse).toList();
        if (coords.length >= 6) {
          if (coords[0] != null) wPos[0] = coords[0]!;
          if (coords[1] != null) wPos[1] = coords[1]!;
          if (coords[2] != null) wPos[2] = coords[2]!;
          if (coords[3] != null) wPos[3] = coords[3]!;
          if (coords[5] != null) wPos[4] = coords[5]!; // C axis
        } else {
          for (int j = 0; j < coords.length && j < 5; j++) {
            if (coords[j] != null) wPos[j] = coords[j]!;
          }
        }
        // Calculer mPos depuis wPos et wco
        mPos = [for (int j = 0; j < 5; j++) wPos[j] + wco[j]];
      } else if (field.startsWith('WCO:')) {
        // Work Coordinate Offset
        final coords =
            field.substring(4).split(',').map(double.tryParse).toList();
        if (coords.length >= 6) {
          if (coords[0] != null) wco[0] = coords[0]!;
          if (coords[1] != null) wco[1] = coords[1]!;
          if (coords[2] != null) wco[2] = coords[2]!;
          if (coords[3] != null) wco[3] = coords[3]!;
          if (coords[5] != null) wco[4] = coords[5]!; // C axis
        } else {
          for (int j = 0; j < coords.length && j < 5; j++) {
            if (coords[j] != null) wco[j] = coords[j]!;
          }
        }
        // Recalculer wPos avec le nouveau wco
        wPos = [for (int j = 0; j < 5; j++) mPos[j] - wco[j]];
      } else if (field.startsWith('FS:')) {
        // Feed & Spindle : FS:feed,spindle
        final fs = field.substring(3).split(',').map(double.tryParse).toList();
        if (fs.isNotEmpty && fs[0] != null) feedrate = fs[0]!;
        if (fs.length > 1 && fs[1] != null) spindleSpeed = fs[1]!;
      } else if (field.startsWith('F:')) {
        // Ancienne syntaxe : F:feed uniquement
        final f = double.tryParse(field.substring(2));
        if (f != null) feedrate = f;
      } else if (field.startsWith('Ov:')) {
        // Overrides : Ov:feed,rapid,spindle (en %)
        final ov = field.substring(3).split(',').map(int.tryParse).toList();
        for (int j = 0; j < ov.length && j < 3; j++) {
          if (ov[j] != null) overrides[j] = ov[j]!;
        }
      } else if (field.startsWith('Bf:')) {
        // Buffer : Bf:plannerBlocks,rxBytes
        final bf = field.substring(3).split(',').map(int.tryParse).toList();
        if (bf.isNotEmpty && bf[0] != null) plannerBuffer = bf[0]!;
        if (bf.length > 1 && bf[1] != null) rxBuffer = bf[1]!;
      } else if (field.startsWith('Pn:')) {
        // État des broches : Pn:P (Probe), Pn:E (E-Stop), Pn:S (Start), etc.
        final pn = field.substring(3).toUpperCase();
        probeTriggered = pn.contains('P');
        emergencyTriggered = pn.contains('E');
        if (pn.contains('X')) limitSwitches[0] = true;
        if (pn.contains('Y')) limitSwitches[1] = true;
        if (pn.contains('Z')) limitSwitches[2] = true;
        if (pn.contains('A')) limitSwitches[3] = true;
        if (pn.contains('C')) limitSwitches[4] = true;
      } else if (field.startsWith('SD:')) {
        // Progression SD : SD:percent,filename
        final sdParts = field.substring(3).split(',');
        if (sdParts.isNotEmpty) sdPercent = double.tryParse(sdParts[0]) ?? 0.0;
        if (sdParts.length > 1) sdFilename = sdParts[1];
      } else if (field.startsWith('Lim:')) {
        // Fins de course : Lim:XYZAC (lettres présentes = actif)
        final lim = field.substring(4).toUpperCase();
        limitSwitches = [
          lim.contains('X'),
          lim.contains('Y'),
          lim.contains('Z'),
          lim.contains('A'),
          lim.contains('C'),
        ];
      }
    }

    return currentState.copyWith(
      status: status,
      mPos: mPos,
      wPos: wPos,
      wco: wco,
      feedrate: feedrate,
      spindleSpeed: spindleSpeed,
      overrides: overrides,
      limitSwitches: limitSwitches,
      probeTriggered: probeTriggered,
      emergencyTriggered: emergencyTriggered,
      sdPercent: sdPercent,
      sdFilename: sdFilename,
      plannerBuffer: plannerBuffer,
      rxBuffer: rxBuffer,
      alarmCode: null, // reset alarme si statut normal
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ALARM : ALARM:N
  // ──────────────────────────────────────────────────────────────────────────
  static MachineState? parseAlarm(String message, MachineState currentState) {
    if (!message.startsWith('ALARM:')) return null;
    final codeStr = message.substring(6).trim();
    final code = int.tryParse(codeStr);
    return currentState.copyWith(
      status: MachineStatus.alarm,
      alarmCode: code,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MODAL STATE : [GC:G0 G54 T1 F1200 S12000]
  // ──────────────────────────────────────────────────────────────────────────
  static MachineState? parseModalState(
      String message, MachineState currentState) {
    if (!message.startsWith('[GC:') || !message.endsWith(']')) return null;
    final content = message.substring(4, message.length - 1);
    final tokens = content.split(' ');

    String activeWCS = currentState.activeWCS;
    int activeToolNum = currentState.activeToolNum;
    double feedrate = currentState.feedrate;
    double spindleSpeed = currentState.spindleSpeed;

    for (final token in tokens) {
      if (RegExp(r'^G5[4-9](\.\d)?$').hasMatch(token)) {
        activeWCS = token;
      } else if (token.startsWith('T')) {
        final n = int.tryParse(token.substring(1));
        if (n != null) activeToolNum = n;
      } else if (token.startsWith('F')) {
        final f = double.tryParse(token.substring(1));
        if (f != null) feedrate = f;
      } else if (token.startsWith('S')) {
        final s = double.tryParse(token.substring(1));
        if (s != null) spindleSpeed = s;
      }
    }

    return currentState.copyWith(
      activeWCS: activeWCS,
      activeToolNum: activeToolNum,
      feedrate: feedrate,
      spindleSpeed: spindleSpeed,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Parser de statut textuel → enum
  // ──────────────────────────────────────────────────────────────────────────
  static MachineStatus _parseStatus(String statusStr) {
    // FluidNC peut ajouter sous-état: "Hold:0", "Door:0", etc.
    final base = statusStr.split(':').first.toLowerCase();
    switch (base) {
      case 'idle':
        return MachineStatus.idle;
      case 'run':
        return MachineStatus.run;
      case 'hold':
        return MachineStatus.hold;
      case 'alarm':
        return MachineStatus.alarm;
      case 'home':
        return MachineStatus.home;
      case 'check':
        return MachineStatus.check;
      case 'door':
        return MachineStatus.door;
      case 'sleep':
        return MachineStatus.sleep;
      default:
        return MachineStatus.offline;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PROBE REPORT : [PRB:100.000,50.000,-10.000:1]
  // ──────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseProbeReport(String message) {
    if (!message.startsWith('[PRB:') || !message.endsWith(']')) return null;
    
    final content = message.substring(5, message.length - 1);
    final parts = content.split(':');
    if (parts.length < 2) return null;

    final coords = parts[0].split(',').map(double.tryParse).toList();
    final success = parts[1] == '1';

    return {
      'coords': coords.whereType<double>().toList(),
      'success': success,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Point d'entrée unique — dispatch selon le type de message
  // ──────────────────────────────────────────────────────────────────────────
  static MachineState? parse(String message, MachineState currentState) {
    final trimmed = message.trim();
    if (trimmed.startsWith('<')) {
      return parseStatusReport(trimmed, currentState);
    } else if (trimmed.startsWith('ALARM:')) {
      return parseAlarm(trimmed, currentState);
    } else if (trimmed.startsWith('[GC:')) {
      return parseModalState(trimmed, currentState);
    }
    return null; // ok, error, [PRB:], MSG: → ignorés ici
  }
}
