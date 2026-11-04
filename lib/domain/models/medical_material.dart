/// Catalogue des matériaux biomédicaux, types d'implants et dossier de lot
/// (inspiré ISO 13485) pour l'adaptation de Forgeron au domaine médical.
///
/// La sélection d'un matériau reflète l'enveloppe physique réelle du prototype
/// Forgeron (broche DC 775 de 200 W, bâti léger, transmission GT2, plafond
/// vibratoire ap ≤ 0,2 mm) :
/// - **Autorisés (`machinable: true`)** : PMMA chirurgical, UHMWPE, PEEK
///   implantable, cire/résine pour modèle anatomique pré-opératoire.
/// - **Bloqués (`machinable: false`)** : Titane Ti-6Al-4V ELI et Cobalt-Chrome
///   CoCrMo — présents au catalogue pour afficher un refus honnête et motivé
///   plutôt que de laisser lancer un usinage destructeur.
library;

enum MedicalMaterialId {
  pmma('pmma'),
  uhmwpe('uhmwpe'),
  peek('peek'),
  waxModel('wax_model'),
  ti6al4v('ti6al4v'),
  cocrmo('cocrmo');

  const MedicalMaterialId(this.wire);
  final String wire;

  static MedicalMaterialId fromWire(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final m in MedicalMaterialId.values) {
      if (m.wire == clean || m.name.toLowerCase() == clean) return m;
    }
    throw ArgumentError('Matériau médical inconnu : $raw');
  }
}

enum MedicalImplantType {
  surgicalGuide('guide_chirurgical', 'Guide chirurgical (perçage / ostéotomie)'),
  cranialPlate('plaque_cranienne', 'Implant crânio-maxillo-facial sur mesure'),
  articularInsert('insert_articulaire', 'Insert articulaire / cale orthopédique'),
  anatomicalModel('modele_anatomique', 'Modèle anatomique pré-opératoire (DICOM)');

  const MedicalImplantType(this.wire, this.label);
  final String wire;
  final String label;

  static MedicalImplantType fromWire(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final t in MedicalImplantType.values) {
      if (t.wire == clean || t.name.toLowerCase() == clean) return t;
    }
    throw ArgumentError('Type d\'implant inconnu : $raw');
  }
}

class MedicalMaterialSpec {
  const MedicalMaterialSpec({
    required this.id,
    required this.name,
    required this.standard,
    required this.machinable,
    required this.apMax,
    required this.aeMax,
    required this.stepoverRecommended,
    required this.feedRoughMax,
    required this.feedPlunge,
    required this.vSurfaceRecommended,
    required this.spindleRpm,
    required this.coolantAllowed,
    required this.clinicalUse,
    this.refusalReason,
  });

  final MedicalMaterialId id;
  final String name;
  final String standard;
  final bool machinable;
  final double apMax;
  final double aeMax;
  final double stepoverRecommended;
  final double feedRoughMax;
  final double feedPlunge;
  final double vSurfaceRecommended;
  final int spindleRpm;

  /// En usinage médical polymère sur Forgeron, l'arrosage (M7/M8) est toujours
  /// interdit (`false`) : un lubrifiant d'atelier contamine la pièce poreuse
  /// et provoque la fissuration (crazing) du PMMA.
  final bool coolantAllowed;
  final String clinicalUse;
  final String? refusalReason;
}

extension MedicalMaterialIdExtension on MedicalMaterialId {
  MedicalMaterialSpec get spec => kMedicalMaterials[this]!;
}

const Map<MedicalMaterialId, MedicalMaterialSpec> kMedicalMaterials = {
  MedicalMaterialId.pmma: MedicalMaterialSpec(
    id: MedicalMaterialId.pmma,
    name: 'PMMA chirurgical / résine acrylique',
    standard: 'ISO 5833 / USP Class VI',
    machinable: true,
    apMax: 0.20,
    aeMax: 0.50,
    stepoverRecommended: 0.35,
    feedRoughMax: 400.0,
    feedPlunge: 80.0,
    vSurfaceRecommended: 120.0,
    spindleRpm: 1000,
    coolantAllowed: false,
    clinicalUse:
        'Guides chirurgicaux, volets crâniens provisoires, prothèses dentaires',
  ),
  MedicalMaterialId.uhmwpe: MedicalMaterialSpec(
    id: MedicalMaterialId.uhmwpe,
    name: 'Polyéthylène UHMWPE médical',
    standard: 'ISO 5834-2 / ASTM F648',
    machinable: true,
    apMax: 0.20,
    aeMax: 0.40,
    stepoverRecommended: 0.30,
    feedRoughMax: 450.0,
    feedPlunge: 90.0,
    vSurfaceRecommended: 140.0,
    spindleRpm: 1000,
    coolantAllowed: false,
    clinicalUse:
        'Inserts articulaires (genou, cotyle), cales d\'essai orthopédiques',
  ),
  MedicalMaterialId.peek: MedicalMaterialSpec(
    id: MedicalMaterialId.peek,
    name: 'PEEK implantable (qualité médicale)',
    standard: 'ASTM F2026 / ISO 10993',
    machinable: true,
    apMax: 0.15,
    aeMax: 0.35,
    stepoverRecommended: 0.25,
    feedRoughMax: 300.0,
    feedPlunge: 60.0,
    vSurfaceRecommended: 100.0,
    spindleRpm: 1000,
    coolantAllowed: false,
    clinicalUse:
        'Implants crânio-maxillo-faciaux sur mesure, cages intersomatiques',
  ),
  MedicalMaterialId.waxModel: MedicalMaterialSpec(
    id: MedicalMaterialId.waxModel,
    name: 'Cire / résine pour modèle anatomique',
    standard: 'Modèle pré-opératoire non implantable',
    machinable: true,
    apMax: 0.20,
    aeMax: 0.50,
    stepoverRecommended: 0.40,
    feedRoughMax: 500.0,
    feedPlunge: 100.0,
    vSurfaceRecommended: 150.0,
    spindleRpm: 1000,
    coolantAllowed: false,
    clinicalUse:
        'Fantôme osseux issu de DICOM pour répétition chirurgicale ou fonderie',
  ),
  MedicalMaterialId.ti6al4v: MedicalMaterialSpec(
    id: MedicalMaterialId.ti6al4v,
    name: 'Titane médical Ti-6Al-4V ELI (Grade 23)',
    standard: 'ISO 5832-3 / ASTM F136',
    machinable: false,
    apMax: 0.0,
    aeMax: 0.0,
    stepoverRecommended: 0.0,
    feedRoughMax: 0.0,
    feedPlunge: 0.0,
    vSurfaceRecommended: 0.0,
    spindleRpm: 0,
    coolantAllowed: false,
    clinicalUse: 'Plaques d\'ostéosynthèse, tiges fémorales, visserie osseuse',
    refusalReason:
        'Hors capacité machine : le Ti-6Al-4V exige une rigidité de bâti élevée, '
        'un fort couple à basse vitesse et une puissance > 1,5 kW. Sur la broche '
        'DC 775 (200 W) et le bâti Forgeron (plafond vibratoire 0,2 mm sur alu), '
        'l\'outil frotte, écrouit le titane et casse immédiatement.',
  ),
  MedicalMaterialId.cocrmo: MedicalMaterialSpec(
    id: MedicalMaterialId.cocrmo,
    name: 'Alliage Cobalt-Chrome CoCrMo',
    standard: 'ISO 5832-4 / ASTM F75',
    machinable: false,
    apMax: 0.0,
    aeMax: 0.0,
    stepoverRecommended: 0.0,
    feedRoughMax: 0.0,
    feedPlunge: 0.0,
    vSurfaceRecommended: 0.0,
    spindleRpm: 0,
    coolantAllowed: false,
    clinicalUse: 'Condyles fémoraux, têtes prothétiques',
    refusalReason:
        'Hors capacité machine : alliage réfractaire à très fort écrouissage, '
        'incompatible avec la broche DC 775 (200 W) et la transmission GT2.',
  ),
};

/// Dossier de fabrication et de traçabilité d'un lot médical (inspiré ISO 13485).
class MedicalDossier {
  const MedicalDossier({
    required this.lotId,
    required this.patientRef,
    required this.timestampUtc,
    required this.implantType,
    required this.material,
    required this.sourceStlPath,
    required this.sourceStlSha256,
    this.sourceFormat = 'STL',
    required this.gcodePath,
    required this.gcodeSha256,
    required this.preparedSizeMm,
    required this.scaleFactor,
    required this.reorientedFlat,
    required this.volumeMm3,
    required this.openEdgesCount,
    required this.provenanceApproximate,
    required this.preparationNotes,
    required this.toolDiameterMm,
    required this.apMm,
    required this.aeMm,
    required this.stepoverMm,
    required this.crestUm,
    required this.roughLayers,
    required this.finishPoints,
    required this.aRangeDeg,
    required this.durationTotalMin,
    required this.gcodeLines,
  });

  final String lotId;
  final String patientRef;
  final String timestampUtc;
  final MedicalImplantType implantType;
  final MedicalMaterialSpec material;
  final String sourceStlPath;
  final String sourceStlSha256;
  final String sourceFormat;
  final String gcodePath;
  final String gcodeSha256;
  final List<double> preparedSizeMm;
  final double scaleFactor;
  final bool reorientedFlat;
  final double volumeMm3;
  final int openEdgesCount;
  final bool provenanceApproximate;
  final List<String> preparationNotes;
  final double toolDiameterMm;
  final double apMm;
  final double aeMm;
  final double stepoverMm;
  final double crestUm;
  final int roughLayers;
  final int finishPoints;
  final List<double> aRangeDeg;
  final double durationTotalMin;
  final int gcodeLines;

  factory MedicalDossier.fromJson(Map<String, dynamic> json) {
    final disp = (json['dispositif'] as Map?)?.cast<String, dynamic>() ?? const {};
    final mat = (json['materiau'] as Map?)?.cast<String, dynamic>() ?? const {};
    final files =
        (json['fichiers_et_empreintes'] as Map?)?.cast<String, dynamic>() ?? const {};
    final geom =
        (json['geometrie_et_provenance'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cut =
        (json['conditions_de_coupe'] as Map?)?.cast<String, dynamic>() ?? const {};
    final path =
        (json['parcours_et_duree'] as Map?)?.cast<String, dynamic>() ?? const {};

    final matId = MedicalMaterialId.fromWire((mat['id'] as String?) ?? 'peek');
    final impType =
        MedicalImplantType.fromWire((disp['type'] as String?) ?? 'plaque_cranienne');

    return MedicalDossier(
      lotId: (json['lot_id'] as String?) ?? 'LOT-MED-AUTO',
      patientRef: (json['patient_ref'] as String?) ?? 'PAT-ANONYME',
      timestampUtc: (json['horodatage_utc'] as String?) ?? '',
      implantType: impType,
      material: matId.spec,
      sourceStlPath: (files['source_fichier'] as String?) ??
          (files['source_stl'] as String?) ??
          '',
      sourceStlSha256: (files['source_fichier_sha256'] as String?) ??
          (files['source_stl_sha256'] as String?) ??
          '',
      sourceFormat: (files['format'] as String?) ??
          (files['source_format'] as String?) ??
          ((files['source_stl'] ?? files['source_fichier'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('.step')
              ? 'STEP'
              : 'STL'),
      gcodePath: (files['programme_nc'] as String?) ?? '',
      gcodeSha256: (files['programme_nc_sha256'] as String?) ?? '',
      preparedSizeMm: ((geom['dimensions_preparees_mm'] as List?) ?? const [0, 0, 0])
          .map((e) => (e as num).toDouble())
          .toList(growable: false),
      scaleFactor: (geom['facteur_echelle'] as num?)?.toDouble() ?? 1.0,
      reorientedFlat: (geom['reoriente_a_plat'] as bool?) ?? false,
      volumeMm3: (geom['volume_mm3'] as num?)?.toDouble() ?? 0.0,
      openEdgesCount: (geom['aretes_ouvertes'] as num?)?.toInt() ?? 0,
      provenanceApproximate: (geom['provenance_approximative'] as bool?) ?? false,
      preparationNotes: ((geom['notes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      toolDiameterMm: (cut['outil_fraise_boule_mm'] as num?)?.toDouble() ?? 6.0,
      apMm: (cut['ap_mm'] as num?)?.toDouble() ?? 0.15,
      aeMm: (cut['ae_mm'] as num?)?.toDouble() ?? 0.35,
      stepoverMm: (cut['stepover_mm'] as num?)?.toDouble() ?? 0.25,
      crestUm: (cut['crete_theorique_um'] as num?)?.toDouble() ?? 0.0,
      roughLayers: (path['couches_ebauche'] as num?)?.toInt() ?? 0,
      finishPoints: (path['points_finition'] as num?)?.toInt() ?? 0,
      aRangeDeg: ((path['plage_axe_a_deg'] as List?) ?? const [0.0, 0.0])
          .map((e) => (e as num).toDouble())
          .toList(growable: false),
      durationTotalMin: (path['duree_totale_min'] as num?)?.toDouble() ?? 0.0,
      gcodeLines: (path['lignes_gcode'] as num?)?.toInt() ?? 0,
    );
  }

  String get sizeLabel => preparedSizeMm.length >= 3
      ? '${preparedSizeMm[0].toStringAsFixed(1)} × '
          '${preparedSizeMm[1].toStringAsFixed(1)} × '
          '${preparedSizeMm[2].toStringAsFixed(1)} mm'
      : '';

  /// Génère une fiche synthétique de traçabilité (format Markdown/texte)
  /// exportable ou copiable dans le dossier de lot.
  String toMarkdownSummary() {
    final buf = StringBuffer()
      ..writeln('# Dossier de Lot Médical (ISO 13485) — $lotId')
      ..writeln('- **Référence cas / patient** : `$patientRef`')
      ..writeln('- **Horodatage UTC** : `$timestampUtc`')
      ..writeln('- **Dispositif** : ${implantType.label}')
      ..writeln('- **Matériau** : ${material.name} (${material.standard})')
      ..writeln('- **Hygiène de coupe** : Coupe à sec obligatoire (`M9`, sans lubrifiant)')
      ..writeln('- **Dimensions préparées (G54)** : $sizeLabel (volume ${volumeMm3.toStringAsFixed(1)} mm³)')
      ..writeln('- **Conditions de coupe** : Fraise boule Ø${toolDiameterMm.toStringAsFixed(1)} mm · '
          'ap ${apMm.toStringAsFixed(2)} mm · ae ${aeMm.toStringAsFixed(2)} mm · '
          'pas ${stepoverMm.toStringAsFixed(2)} mm (crête ${crestUm.toStringAsFixed(1)} µm)')
      ..writeln('- **Parcours** : $roughLayers couches d\'ébauche 3 axes + '
          '$finishPoints points de finition (A de ${aRangeDeg.first.toStringAsFixed(1)}° '
          'à ${aRangeDeg.last.toStringAsFixed(1)}°)')
      ..writeln('- **Durée estimée** : ${durationTotalMin.toStringAsFixed(1)} min ($gcodeLines lignes)')
      ..writeln('- **Modèle source ($sourceFormat)** : `${sourceStlPath.split(RegExp(r"[/\\]")).last}`')
      ..writeln('- **Empreinte modèle source (SHA-256)** : `${sourceStlSha256.substring(0, sourceStlSha256.length.clamp(0, 16))}…`')
      ..writeln('- **Empreinte G-code (SHA-256)** : `${gcodeSha256.substring(0, gcodeSha256.length.clamp(0, 16))}…`');
    if (preparationNotes.isNotEmpty) {
      buf.writeln('\n## Journal de préparation géométrique');
      for (final n in preparationNotes) {
        buf.writeln('- $n');
      }
    }
    return buf.toString();
  }
}

