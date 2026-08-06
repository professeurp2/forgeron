import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_adapter.dart';
import 'package:forgeron/core/utils/kinematics_service.dart';
import 'package:vector_math/vector_math_64.dart';

/// Validation END-TO-END de la chaîne 5 axes CONTINU (Option A) :
///
///   parcours pièce voulu  --inverseRTCP-->  coords machine (G-code)
///                          --adaptateur-->  G-code exécutable (doit passer)
///                          --forward-->     parcours pièce reconstruit
///
/// On part d'un cercle dans le repère PIÈCE, avec bascule A et rotation C
/// SIMULTANÉES (vrai 5 axes continu), on « cuit » les coords machine via le
/// RTCP, on vérifie que l'adaptateur ne bloque pas, puis que la cinématique
/// directe reconstruit exactement le cercle d'origine. Un cercle qui reste un
/// cercle = la chaîne machine↔pièce est cohérente.
void main() {
  final k = KinematicsService(pivotToTableOffset: 8, toolLength: 0);
  const n = 180;
  const rWork = 10.0; // rayon du cercle dans le repère pièce (mm)

  // Génère le parcours (cercle pièce) + profils A/C continus → coords machine.
  final work = <Vector3>[];
  final buf = StringBuffer()
    ..writeln('G21')
    ..writeln('G90')
    ..writeln('G94');
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final ang = t * 2 * math.pi;
    final pw = Vector3(rWork * math.cos(ang), rWork * math.sin(ang), 0);
    final a = -30.0 * t; // bascule A : 0 → -30°
    final c = 360.0 * t; // rotation C : 0 → 360° (continu)
    final m = k.inverseRTCP(pw, a, c);
    buf.writeln('G1 X${m.x.toStringAsFixed(4)} Y${m.y.toStringAsFixed(4)} '
        'Z${m.z.toStringAsFixed(4)} A${a.toStringAsFixed(4)} '
        'C${c.toStringAsFixed(4)} F600');
    work.add(pw);
  }
  final gcodeMachine = buf.toString();

  test('l\'adaptateur laisse passer le parcours continu (coords machine)', () {
    final r = GcodeAdapter.adaptForFluidNC(gcodeMachine);
    expect(r.blocking, false,
        reason: 'coords machine, aucune transformation active');
    // Aucun avertissement bloquant ; A et C présents sur les lignes de coupe.
    expect(RegExp(r'A-?\d').hasMatch(r.gcode), true);
    expect(RegExp(r'C-?\d').hasMatch(r.gcode), true);
  });

  test('c\'est bien du 5 axes SIMULTANÉ (RTCP a déplacé X/Y/Z)', () {
    // Sur un cercle pièce à Z=0, si la machine ne faisait rien (pas de RTCP),
    // Z machine resterait constant. Ici le RTCP fait varier X/Y/Z.
    final lines = gcodeMachine
        .split('\n')
        .where((l) => l.startsWith('G1'))
        .toList();
    final zs = lines.map((l) => _num(l, 'Z')!).toList();
    final zSpan = zs.reduce(math.max) - zs.reduce(math.min);
    expect(zSpan > 1.0, true,
        reason: 'le RTCP doit faire bouger Z machine (bascule A)');
  });

  test('cinématique directe reconstruit le cercle pièce d\'origine', () {
    final r = GcodeAdapter.adaptForFluidNC(gcodeMachine);
    final lines = r.gcode.split('\n').where((l) => l.startsWith('G1')).toList();
    expect(lines.length, n + 1);

    var maxErr = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final m = Vector3(_num(l, 'X')!, _num(l, 'Y')!, _num(l, 'Z')!);
      final tip = k.forward(m, _num(l, 'A')!, _num(l, 'C')!);
      final err = (tip - work[i]).length;
      if (err > maxErr) maxErr = err;
    }
    // Tolérance large (le G-code est arrondi à 1e-4 mm) mais bien < 1 µm ici.
    expect(maxErr < 1e-3, true,
        reason: 'erreur max reconstruction = ${maxErr.toStringAsFixed(6)} mm');

    // Le parcours reconstruit doit rester un CERCLE de rayon rWork.
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final tip =
          k.forward(Vector3(_num(l, 'X')!, _num(l, 'Y')!, _num(l, 'Z')!),
              _num(l, 'A')!, _num(l, 'C')!);
      final radius = math.sqrt(tip.x * tip.x + tip.y * tip.y);
      expect(radius, closeTo(rWork, 1e-3),
          reason: 'point $i : rayon reconstruit');
      expect(tip.z, closeTo(0, 1e-3), reason: 'point $i : Z pièce = 0');
    }
  });
}

double? _num(String line, String word) {
  final m = RegExp('$word([-+]?[0-9]*\\.?[0-9]+)').firstMatch(line);
  return m == null ? null : double.tryParse(m.group(1)!);
}
