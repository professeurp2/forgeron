import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/medical_implant_service.dart';
import 'package:forgeron/application/services/step_preview_service.dart';
import 'package:forgeron/application/services/tool_router.dart';
import 'package:forgeron/core/utils/gcode_critic.dart';
import 'package:forgeron/domain/models/medical_material.dart';

/// Écrit un petit fichier STL ASCII valide (plaque bombée 20 × 28 × 3 mm).
void _writeSyntheticImplantStl(File dest) {
  final buf = StringBuffer('solid implant_cranien\n');
  void tri(List<double> a, List<double> b, List<double> c) {
    buf.writeln('  facet normal 0 0 1');
    buf.writeln('    outer loop');
    buf.writeln('      vertex ${a[0]} ${a[1]} ${a[2]}');
    buf.writeln('      vertex ${b[0]} ${b[1]} ${b[2]}');
    buf.writeln('      vertex ${c[0]} ${c[1]} ${c[2]}');
    buf.writeln('    endloop');
    buf.writeln('  endfacet');
  }

  // Grille 4×4 de la face supérieure bombée + face inférieure
  const nx = 4, ny = 4;
  for (var j = 0; j < ny - 1; j++) {
    for (var i = 0; i < nx - 1; i++) {
      final x0 = -10.0 + i * (20.0 / (nx - 1));
      final x1 = -10.0 + (i + 1) * (20.0 / (nx - 1));
      final y0 = -14.0 + j * (28.0 / (ny - 1));
      final y1 = -14.0 + (j + 1) * (28.0 / (ny - 1));
      double zTop(double x, double y) =>
          1.5 * (1.0 - 0.3 * ((x / 10.0) * (x / 10.0) + (y / 14.0) * (y / 14.0)));

      final p00 = [x0, y0, zTop(x0, y0)];
      final p10 = [x1, y0, zTop(x1, y0)];
      final p11 = [x1, y1, zTop(x1, y1)];
      final p01 = [x0, y1, zTop(x0, y1)];
      tri(p00, p10, p11);
      tri(p00, p11, p01);

      final b00 = [x0, y0, p00[2] - 3.0];
      final b10 = [x1, y0, p10[2] - 3.0];
      final b11 = [x1, y1, p11[2] - 3.0];
      final b01 = [x0, y1, p01[2] - 3.0];
      tri(b00, b11, b10);
      tri(b00, b01, b11);
    }
  }
  buf.writeln('endsolid implant_cranien');
  dest.writeAsStringSync(buf.toString());
}

void main() {
  group('Catalogue matériaux biomédicaux & réalisme machine', () {
    test('les polymères (PMMA, UHMWPE, PEEK, cire) sont autorisés sous le plafond vibratoire', () {
      for (final m in [
        MedicalMaterialId.pmma,
        MedicalMaterialId.uhmwpe,
        MedicalMaterialId.peek,
        MedicalMaterialId.waxModel,
      ]) {
        final s = m.spec;
        expect(s.machinable, isTrue, reason: s.name);
        expect(s.apMax, lessThanOrEqualTo(0.20), reason: 'plafond vibratoire 0,2 mm');
        expect(s.aeMax, lessThanOrEqualTo(0.50), reason: 'plafond vibratoire 0,5 mm');
        expect(s.coolantAllowed, isFalse, reason: 'coupe à sec M9 obligatoire');
      }
    });

    test('le titane Ti-6Al-4V et le CoCrMo sont signalés hors capacité et bloqués', () {
      for (final metal in [MedicalMaterialId.ti6al4v, MedicalMaterialId.cocrmo]) {
        expect(metal.spec.machinable, isFalse);
        expect(metal.spec.refusalReason, contains('Hors capacité machine'));
        expect(metal.spec.refusalReason, contains('200 W'));
        expect(
          () => MedicalImplantService.validateGuardrails(
            material: metal,
            implantType: MedicalImplantType.cranialPlate,
            provenanceApproximate: false,
          ),
          throwsA(isA<MedicalImplantException>()),
        );
      }
    });

    test('garde-fou de provenance : un scan approximatif sans cote est refusé pour un implant', () {
      expect(
        () => MedicalImplantService.validateGuardrails(
          material: MedicalMaterialId.peek,
          implantType: MedicalImplantType.cranialPlate,
          provenanceApproximate: true,
        ),
        throwsA(isA<MedicalImplantException>()),
      );

      // Autorisé si une longueur cible métrique est fournie :
      expect(
        () => MedicalImplantService.validateGuardrails(
          material: MedicalMaterialId.peek,
          implantType: MedicalImplantType.cranialPlate,
          provenanceApproximate: true,
          targetLengthMm: 42.0,
        ),
        returnsNormally,
      );

      // Autorisé pour un modèle anatomique pré-opératoire de démonstration :
      expect(
        () => MedicalImplantService.validateGuardrails(
          material: MedicalMaterialId.waxModel,
          implantType: MedicalImplantType.anatomicalModel,
          provenanceApproximate: true,
        ),
        returnsNormally,
      );
    });
  });

  group('Critique G-code en mode médical (coupe à sec M9)', () {
    test('bloque tout programme contenant M7 ou M8 en mode médical', () {
      const criticMed = GcodeCritic(medicalMode: true);
      final bad = criticMed.review('G21 G90\nM3 S1000\nM8\nG1 X10 Y10 F200\nM5\nM30\n');
      expect(bad.usable, isFalse);
      expect(
        bad.findings.any((f) =>
            f.code == 'arrosage_interdit_en_medical' &&
            f.severity == CriticSeverity.blocking),
        isTrue,
      );

      final good = criticMed.review('G21 G90\nM9\nM3 S1000\nG1 X10 Y10 F200\nM5\nM30\n');
      expect(good.usable, isTrue);
      expect(
        good.findings.any((f) => f.code == 'arrosage_interdit_en_medical'),
        isFalse,
      );
    });
  });

  group('Routage IA pour les requêtes médicales', () {
    test('les mots-clés médicaux activent le groupe CAO', () {
      const router = ToolRouter();
      final all = AiToolCatalog.tools.map((t) => t.name).toList();
      final r = router.route(
        text: 'Prépare l\'usinage de cet implant crânien en PEEK depuis le fichier DICOM.',
        allTools: all,
      );
      expect(r.routed, isTrue);
      expect(r.tools, containsAll(['run_step_pipeline', 'preview_step_file']));
    });
  });

  group('Chaîne complète STL -> Préparation -> G-code & Dossier ISO 13485', () {
    test('génère l\'aperçu 3D, le G-code 5 axes en PEEK et le dossier de lot', () async {
      final tmp = Directory.systemTemp.createTempSync('forgeron_med_dart_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final stlFile = File('${tmp.path}${Platform.pathSeparator}implant_test.stl');
      _writeSyntheticImplantStl(stlFile);

      final preview = await StepPreviewService.run(stlFile.path, useCache: false);
      expect(preview.triangles, greaterThan(10));
      expect(preview.size.length, 3);

      final res = await MedicalImplantService.run(
        stlFile.path,
        material: MedicalMaterialId.peek,
        implantType: MedicalImplantType.cranialPlate,
        stepover: 2.0,
        lotId: 'LOT-TEST-13485',
        patientRef: 'CAS-007',
      );

      expect(res.critique.usable, isTrue);
      expect(res.dossier.lotId, 'LOT-TEST-13485');
      expect(res.dossier.patientRef, 'CAS-007');
      expect(res.dossier.material.id, MedicalMaterialId.peek);
      expect(res.dossier.apMm, closeTo(0.15, 1e-6));
      expect(res.dossier.sourceStlSha256.length, 64);
      expect(res.dossier.gcodeSha256.length, 64);
      expect(res.dossier.toMarkdownSummary(), contains('ISO 13485'));
    });

    test('refuse les formats de fichiers 3D non autorisés (.obj, .txt)', () async {
      final tmp = Directory.systemTemp.createTempSync('forgeron_bad_fmt_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final badFile = File('${tmp.path}${Platform.pathSeparator}modele.obj');
      badFile.writeAsStringSync('v 0 0 0\n');

      expect(
        () => MedicalImplantService.run(badFile.path),
        throwsA(
          isA<MedicalImplantException>().having(
            (e) => e.message,
            'message',
            contains('Format 3D non pris en charge'),
          ),
        ),
      );
    });
  });
}

