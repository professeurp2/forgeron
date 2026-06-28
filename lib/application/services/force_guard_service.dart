import 'package:flutter/foundation.dart';
import '../../domain/models/machining_mode.dart';
import '../../domain/models/trunnion_config.dart';

/// Service de protection des efforts de coupe (ForceGuard).
///
/// Vérifie et bride automatiquement les paramètres de coupe en temps réel
/// pour garantir que l'effort résultant reste sous la limite du mode actif :
///   - **5AX** : R_max = 45,6 N (bridage automatique des vitesses d'avance).
///   - **3AX** : R_3ax = 180 N (A/C verrouillés, pas de bridage logiciel).
///
/// Ce service est intégré dans le pipeline de streaming G-code : chaque ligne
/// est vérifiée avant envoi à l'ESP32.
class ForceGuardService {
  final MachiningMode mode;
  final TrunnionConfig config;

  /// Compteur de lignes bridées (pour le diagnostic).
  int _clampedCount = 0;
  int get clampedCount => _clampedCount;

  /// Compteur de lignes bloquées (A/C en mode 3AX).
  int _blockedCount = 0;
  int get blockedCount => _blockedCount;

  ForceGuardService({required this.mode, required this.config});

  /// Réinitialise les compteurs (ex: nouveau fichier G-code).
  void reset() {
    _clampedCount = 0;
    _blockedCount = 0;
  }

  // ── Regex compilées une seule fois ──────────────────────────────────

  static final _feedRegex = RegExp(r'F(\d+\.?\d*)');
  static final _rotaryRegex = RegExp(r'[AC]-?\d');
  static final _commentOrSysRegex = RegExp(r'^[(%$;]');

  // ── Vérification ───────────────────────────────────────────────────

  /// Vérifie si une ligne G-code respecte les limites du mode actif.
  ///
  /// Retourne `null` si OK, ou un message d'alerte descriptif.
  String? checkLine(String gcodeLine) {
    final trimmed = gcodeLine.trim();
    if (trimmed.isEmpty || _commentOrSysRegex.hasMatch(trimmed)) return null;

    // Vérifier l'avance
    final feedMatch = _feedRegex.firstMatch(trimmed);
    if (feedMatch != null) {
      final feed = double.tryParse(feedMatch.group(1)!) ?? 0;
      if (feed > mode.maxFeedrate) {
        return 'Avance F${feed.toInt()} dépasse la limite ${mode.shortLabel} '
            '(max ${mode.maxFeedrate.toInt()} mm/min)';
      }
    }

    // En mode 3 axes : bloquer les commandes A/C
    if (mode == MachiningMode.threeAxis) {
      if (_rotaryRegex.hasMatch(trimmed)) {
        return 'Commande A/C interdite en mode 3 axes (A/C verrouillés)';
      }
    }

    return null;
  }

  /// Vérifie un fichier G-code complet. Retourne la liste des alertes.
  List<ForceGuardAlert> checkFile(List<String> lines) {
    final alerts = <ForceGuardAlert>[];
    for (int i = 0; i < lines.length; i++) {
      final msg = checkLine(lines[i]);
      if (msg != null) {
        alerts.add(ForceGuardAlert(lineIndex: i, line: lines[i], message: msg));
      }
    }
    return alerts;
  }

  // ── Bridage ────────────────────────────────────────────────────────

  /// Bride la vitesse d'avance d'une ligne G-code si elle dépasse la limite.
  ///
  /// En mode 5 axes, le ForceGuard assure que l'effort résultant
  /// ne dépasse pas R_max = 45,6 N en limitant F.
  String clampFeedrate(String gcodeLine) {
    final trimmed = gcodeLine.trim();
    if (trimmed.isEmpty || _commentOrSysRegex.hasMatch(trimmed)) {
      return gcodeLine;
    }

    final feedMatch = _feedRegex.firstMatch(trimmed);
    if (feedMatch != null) {
      final feed = double.tryParse(feedMatch.group(1)!) ?? 0;
      if (feed > mode.maxFeedrate) {
        _clampedCount++;
        final clamped = gcodeLine.replaceFirst(
          feedMatch.group(0)!,
          'F${mode.maxFeedrate.toInt()}',
        );
        debugPrint(
          '⚡ ForceGuard [${mode.shortLabel}]: F${feed.toInt()} → '
          'F${mode.maxFeedrate.toInt()} (R_max=${mode.maxResultantForce} N)',
        );
        return clamped;
      }
    }

    return gcodeLine;
  }

  /// Filtre une ligne G-code en mode 3 axes : supprime les commandes A/C.
  ///
  /// Si la ligne ne contient QUE du A/C (ex: `G1 A45 F200`), elle est
  /// remplacée par un commentaire. Si elle contient aussi X/Y/Z, seuls
  /// les mots A/C sont retirés.
  String filterRotaryAxes(String gcodeLine) {
    if (mode != MachiningMode.threeAxis) return gcodeLine;

    final trimmed = gcodeLine.trim();
    if (trimmed.isEmpty || _commentOrSysRegex.hasMatch(trimmed)) {
      return gcodeLine;
    }

    if (!_rotaryRegex.hasMatch(trimmed)) return gcodeLine;

    _blockedCount++;

    // Retirer les mots A et C (ex: A45.000, C-90.000)
    final filtered = trimmed
        .replaceAll(RegExp(r'[AC]-?\d+\.?\d*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Si il ne reste que le G-code modal (G0/G1) + F, c'est une ligne vide
    if (RegExp(r'^(G[0-3]\d?)?\s*(F\d+\.?\d*)?\s*$').hasMatch(filtered)) {
      debugPrint(
        '🔒 ForceGuard [3AX]: Ligne A/C bloquée → $trimmed',
      );
      return '(ForceGuard: A/C locked) ; $trimmed';
    }

    debugPrint(
      '🔒 ForceGuard [3AX]: A/C retiré → $filtered',
    );
    return filtered;
  }

  /// Pipeline complet : filtre A/C (si 3AX) puis bride F.
  String processLine(String gcodeLine) {
    var line = filterRotaryAxes(gcodeLine);
    line = clampFeedrate(line);
    return line;
  }
}

/// Alerte générée par le ForceGuard lors de la vérification d'un fichier.
class ForceGuardAlert {
  final int lineIndex;
  final String line;
  final String message;

  const ForceGuardAlert({
    required this.lineIndex,
    required this.line,
    required this.message,
  });

  @override
  String toString() => 'L${lineIndex + 1}: $message';
}
