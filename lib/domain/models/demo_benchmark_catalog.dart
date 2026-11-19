/// Filière d'application pour les cas de test CAO/STEP embarqués dans Forgeron.
enum DemoDomain {
  manufacturing,
  medicine,
}

/// Fichier CAO (STEP / STL) et parcours G-Code pré-validé embarqué dans Forgeron
/// pour faciliter les tests et démonstrations en 1 clic.
class DemoBenchmarkSample {
  final String id;
  final DemoDomain domain;
  final String title;
  final String subtitle;
  final String cadPath;
  final String? previewJsonPath;
  final String? reportJsonPath;
  final String? gcodePath;
  final String materialAndTool;
  final String agentPitch;
  final List<String> keyHighlights;

  const DemoBenchmarkSample({
    required this.id,
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.cadPath,
    this.previewJsonPath,
    this.reportJsonPath,
    this.gcodePath,
    required this.materialAndTool,
    required this.agentPitch,
    required this.keyHighlights,
  });

  String get domainLabel =>
      domain == DemoDomain.manufacturing ? 'MANUFACTURING (INDUSTRIE)' : 'MÉDECINE (BIOMÉDICAL)';
}

/// Guide multimédia de « Prise en main » (Image + Vidéo animée interactive +
/// Script de présentation par l'Agent IA + Test direct).
class FeatureHandsOnGuide {
  final String id;
  final String title;
  final String badge;
  final String summary;
  final String agentIntroduction;
  final String imageAssetPath;
  final String videoSimulationType; // 'trunnion_5axis' | 'step_to_cam' | 'probing_cycle' | 'esp32_watchdog' | 'ai_memory'
  final List<String> steps;
  final String? linkedDemoSampleId;
  final int targetScreenIndex;

  const FeatureHandsOnGuide({
    required this.id,
    required this.title,
    required this.badge,
    required this.summary,
    required this.agentIntroduction,
    required this.imageAssetPath,
    required this.videoSimulationType,
    required this.steps,
    this.linkedDemoSampleId,
    required this.targetScreenIndex,
  });
}

/// Catalogue central des fichiers STEP de démonstration (Manufacturing & Médecine)
/// et des prises en main multimédias.
class DemoBenchmarkCatalog {
  DemoBenchmarkCatalog._();

  static const List<DemoBenchmarkSample> samples = [
    // ── FILIÈRE MANUFACTURING ──────────────────────────────────────────────
    DemoBenchmarkSample(
      id: 'manufacturing_impeller',
      domain: DemoDomain.manufacturing,
      title: 'Turbine / Roue à aubes 5-Axes (IMPELLER.STP)',
      subtitle: ' Aéronautique & Énergie — Surface gauche multi-pales',
      cadPath: 'scratch/3D/IMPELLER.STP',
      previewJsonPath: 'scratch/3D/IMPELLER_apercu.json',
      reportJsonPath: 'scratch/3D/IMPELLER_rapport.json',
      gcodePath: 'scratch/3D/IMPELLER.nc',
      materialAndTool:
          'Alliage Aluminium 7075-T6 • Fraise boule Ø6 mm carbure • 5 axes indexé & continu',
      agentPitch:
          'Voici la roue à aubes industrielle (IMPELLER.STP) déjà intégrée dans Forgeron. '
          'Ce test Manufacturing démontre l\'analyse topologique OCCT du fichier STEP, '
          'l\'inclinaison du berceau A et la rotation C pour usiner entre les pales sans collision, '
          'ainsi que la simulation 3D temps réel du parcours G-code.',
      keyHighlights: [
        'Import STEP natif (OpenCascade) avec maillage de prévisualisation haute fidélité',
        'Orientation 5 axes Trunnion (X, Y, Z, A, C) pour dégager le porte-outil des pales',
        'Vérification automatique anti-RTCP et respect des courses machine',
      ],
    ),
    DemoBenchmarkSample(
      id: 'manufacturing_archimedes',
      domain: DemoDomain.manufacturing,
      title: 'Vis d\'Archimède Hélicoïdale (STEP)',
      subtitle: 'Mécanique des fluides — Rotor hélicoïdal continu',
      cadPath:
          'scratch/3D/small-archimedes-impeller-1.snapshot.7/\u00d82.625in Archimedes Impeller, \u00d8.125in Shaft.step',
      previewJsonPath:
          'scratch/3D/small-archimedes-impeller-1.snapshot.7/\u00d82.625in Archimedes Impeller, \u00d8.125in Shaft_apercu.json',
      reportJsonPath:
          'scratch/3D/small-archimedes-impeller-1.snapshot.7/\u00d82.625in Archimedes Impeller, \u00d8.125in Shaft_rapport.json',
      gcodePath:
          'scratch/3D/small-archimedes-impeller-1.snapshot.7/\u00d82.625in Archimedes Impeller, \u00d8.125in Shaft_implant.nc',
      materialAndTool:
          'Acier Inox 316L / POM-C • Fraise hémisphérique Ø4 mm • Balayage hélicoïdal',
      agentPitch:
          'Ce modèle STEP de vis d\'Archimède permet de tester en direct le pipeline '
          'CAO → FAO de Forgeron sur des filets hélicoïdaux nécessitant une rotation '
          'continue de l\'axe C synchronisée avec X, Y et Z.',
      keyHighlights: [
        'Analyse géométrique automatique de l\'enveloppe cylindrique et du pas d\'hélice',
        'Synchronisation 5 axes simultanés sans saccades (buffer FluidNC optimisé)',
        'Test idéal pour valider la cinématique rotative C (360° continu)',
      ],
    ),
    DemoBenchmarkSample(
      id: 'manufacturing_dome_5axis',
      domain: DemoDomain.manufacturing,
      title: 'Dôme 5-Axes Simultané Continu (Air-Cut)',
      subtitle: 'Validation cinématique X, Y, Z, A, C en coordonnées machine',
      cadPath: 'pipeline/vase.stl',
      gcodePath: 'scratch/demo_dome_5axes_continu.nc',
      materialAndTool:
          'Essai à vide (Air-Cut sécurisé) • 5 axes simultanés X, Y, Z, A, C',
      agentPitch:
          'Ce parcours de référence déplace simultanément les 5 axes (X, Y, Z, A, C) '
          'sur une calotte sphérique. Idéal pour démontrer la fluidité du streaming '
          'WebSocket binaire vers l\'ESP32 FluidNC.',
      keyHighlights: [
        'Mouvement simultané 5 axes pré-compensé en coordonnées machine',
        'Zéro blocage RTCP (aucun G43.4 requis sur FluidNC)',
        'Exécutable immédiatement à vide (Air-Cut) devant le jury ou le client',
      ],
    ),

    // ── FILIÈRE MÉDECINE (BIOMÉDICAL & DENTAIRE) ───────────────────────────
    DemoBenchmarkSample(
      id: 'medicine_cranial_implant',
      domain: DemoDomain.medicine,
      title: 'Implant Crânien Sur-Mesure Patient (rend.step)',
      subtitle: 'Neurochirurgie reconstructrice — Prothèse anatomique STEP',
      cadPath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend.step',
      previewJsonPath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend_apercu.json',
      reportJsonPath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend_rapport.json',
      gcodePath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend_implant5.nc',
      materialAndTool:
          'PEEK Biomédical / Titane Grade 5 (Ti-6Al-4V ELI) • Fraise boule Ø3 mm • Crête 0,08 mm',
      agentPitch:
          'Voici l\'implant crânien patient-spécifique (rend.step) embarqué dans Forgeron. '
          'Issu d\'une reconstruction scanner 3D, cet implant à double courbure illustre '
          'l\'apport décisif de la CNC 5 axes en médecine : usiner localement à l\'hôpital '
          'ou au laboratoire une prothèse parfaitement ajustée à l\'anatomie du patient.',
      keyHighlights: [
        'Fichier STEP biomédical réel avec surfaces NURBS complexes à double courbure',
        'Parcours 5 axes (`rend_implant5.nc`) maintenant l\'outil proche de la normale',
        'Contrôle strict des limites d\'axes et de l\'état de surface chirurgical',
      ],
    ),
    DemoBenchmarkSample(
      id: 'medicine_dental_arch',
      domain: DemoDomain.medicine,
      title: 'Arcade Dentaire Maxillaire NIH 3D',
      subtitle: 'Odontologie & Prothèse CFAO — Modèle anatomique complet',
      cadPath: 'scratch/3D/Maxillary_teeth_w_base_NIH3D.stl',
      gcodePath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend_implant5.nc',
      materialAndTool:
          'Zircone Multicouche / PMMA Médical • Fraise boule diamantée Ø1.5 mm',
      agentPitch:
          'Ce modèle d\'arcade maxillaire NIH 3D démontre le potentiel de Forgeron '
          'pour la CFAO dentaire : le basculement du berceau A permet d\'atteindre '
          'les sillons occlusaux et les zones de contre-dépouille interdentaires.',
      keyHighlights: [
        'Géométrie organique haute densité issue de la banque médicale NIH 3D',
        'Indexation multi-angulaire 3+2 et balayage 5 axes des faces occlusales',
        'Validation de la précision des axes rotatifs A et C',
      ],
    ),
    DemoBenchmarkSample(
      id: 'medicine_dental_dentin',
      domain: DemoDomain.medicine,
      title: 'Couronne & Restauration Dentaire (Dentine / Émail)',
      subtitle: 'Micro-usinage 5 axes pour laboratoire dentaire',
      cadPath: 'scratch/3D/wk-blase-edit-schmelz-dicht-Dentin.stl',
      gcodePath:
          'scratch/3D/patient-specific-cranial-implant-1.snapshot.3/rend_implant5.nc',
      materialAndTool:
          'Disilicate de Lithium / Composite hybride • Fraise Ø1.0 mm',
      agentPitch:
          'Ce cas médical présente la structure interne de dentine (`Dentin.stl`) et '
          'd\'émail (`Schmelz.stl`) d\'une prothèse dentaire anatomique usinée en 5 axes.',
      keyHighlights: [
        'Assemblage multi-couches Dentine + Émail + Tenon radiculaire (`Post.stl`)',
        'Démonstration de la polyvalence de Forgeron entre industrie lourde et médical de précision',
      ],
    ),
  ];

  static const List<FeatureHandsOnGuide> handsOnGuides = [
    FeatureHandsOnGuide(
      id: 'feature_5axis_cockpit',
      title: '1. Cockpit 5-Axes Temps Réel & Jumeau Numérique Trunnion',
      badge: 'CONTRÔLE & CINÉMATIQUE',
      summary:
          'Pilotage direct des 5 axes (X, Y, Z linéaires + A, C rotatifs), DRO haute visibilité et visualisation 3D synchronisée.',
      agentIntroduction:
          'Bienvenue dans le Cockpit 5-Axes de Forgeron. Ici, chaque trame WebSocket binaire '
          'envoyée par l\'ESP32 FluidNC met à jour en temps réel les positions X, Y, Z, A, C '
          'et anime le berceau Trunnion en 3D. Vous pouvez tester immédiatement un déplacement '
          'ou charger notre parcours 5 axes continu.',
      imageAssetPath: 'assets/logo.png',
      videoSimulationType: 'trunnion_5axis',
      steps: [
        'Observez le DRO 5 axes (X, Y, Z en mm ; A, C en degrés) et le badge d\'état FluidNC.',
        'Manipulez l\'aperçu 3D Trunnion : la pointe d\'outil suit la cinématique réelle.',
        'Lancez un test 5 axes continu (Dôme Air-Cut) en 1 clic ci-dessous.',
      ],
      linkedDemoSampleId: 'manufacturing_dome_5axis',
      targetScreenIndex: 0,
    ),
    FeatureHandsOnGuide(
      id: 'feature_step_cam_pipeline',
      title: '2. Atelier CAO/FAO Embarqué : STEP → G-Code (Manufacturing & Médecine)',
      badge: 'CAO / FAO 5-AXES',
      summary:
          'Import direct de fichiers STEP industriels et médicaux, analyse géométrique OpenCascade et génération de parcours.',
      agentIntroduction:
          'Forgeron intègre son propre pipeline CAO/FAO sans logiciel externe obligatoire. '
          'Pour vos démonstrations, j\'ai préparé deux cas réels embarqués : une turbine '
          '5 axes pour le Manufacturing (IMPELLER.STP) et un implant crânien sur-mesure '
          'pour la Médecine (rend.step). Cliquez sur l\'un des deux pour lancer le test !',
      imageAssetPath: 'assets/logo.png',
      videoSimulationType: 'step_to_cam',
      steps: [
        'Sélectionnez un fichier STEP embarqué (Manufacturing : Turbine | Médecine : Implant crânien).',
        'Inspectez l\'aperçu 3D du maillage CAO, les dimensions du brut et la stratégie d\'outil.',
        'Générez et validez automatiquement le G-code adapté pour FluidNC.',
      ],
      linkedDemoSampleId: 'medicine_cranial_implant',
      targetScreenIndex: 3,
    ),
    FeatureHandsOnGuide(
      id: 'feature_probing_wcs',
      title: '3. Palpage Automatisé & Origines Pièce (G54..G59)',
      badge: 'MÉTROLOGIE & ORIGINES',
      summary:
          'Cycles de palpage électrique G38.2 (Z, coins X/Y, centre d\'alésage) et alignement du berceau rotatif A/C.',
      agentIntroduction:
          'Avant tout usinage 5 axes, l\'origine pièce (G54) et le centre de basculement '
          'du berceau A doivent être référencés au centième de millimètre. L\'assistant '
          'de palpage vérifie d\'abord le contact de la sonde avant d\'engager le mouvement.',
      imageAssetPath: 'assets/logo.png',
      videoSimulationType: 'probing_cycle',
      steps: [
        'Testez le contact de la sonde (Pn:P) à la main pour valider la continuité électrique.',
        'Lancez le cycle de palpage Z ou d\'étalonnage du centre de rotation A.',
        'Les offsets G54..G59 sont écrits dans l\'ESP32 via G10 L2 et relus via \$#.',
      ],
      targetScreenIndex: 1,
    ),
    FeatureHandsOnGuide(
      id: 'feature_esp32_guardian',
      title: '4. Supervision Temps Réel : Codes Alarme & Redémarrages ESP32',
      badge: 'SÉCURITÉ MATÉRIELLE',
      summary:
          'Interprétation instantanée des alarmes GRBL/FluidNC, des capteurs NF (GPIO 4, 13, 14, 5, 15) et des brownouts ESP32 depuis toute fenêtre.',
      agentIntroduction:
          'En tant que Mémoire du Contrôleur, je surveille la carte ESP32 en continu depuis '
          'n\'importe quelle fenêtre. Si un fin de course NF s\'ouvre (ALARM:1) ou si '
          'l\'allumage de la broche 775 (M3 sur GPIO 21) provoque un redémarrage par chute '
          'de tension (Brownout), j\'identifie immédiatement la cause matérielle et vous '
          'propose le déblocage en 1 clic.',
      imageAssetPath: 'assets/logo.png',
      videoSimulationType: 'esp32_watchdog',
      steps: [
        'Détection temps réel des bannières de boot ESP32, codes `rst:0xf (BROWNOUT)` et `ALARM:1..18`.',
        'Corrélation automatique avec le câblage GPIO (X=GPIO4, Y=GPIO13, Z=GPIO14, A=GPIO5, E-STOP=GPIO15, Broche=GPIO21).',
        'Boutons d\'action immédiate dans le Chatbot : Déverrouiller (\$X), Homing (\$H), Couper broche (M5).',
      ],
      targetScreenIndex: 5,
    ),
    FeatureHandsOnGuide(
      id: 'feature_omnipresent_ai',
      title: '5. Copilote IA Omniprésent, Mémoire Totale & Suggestions Post-Opération',
      badge: 'INTELLIGENCE EMBARQUÉE',
      summary:
          'Chatbot disponible partout (Flottant, Ancré en Bas ou à Droite), multilingue local sans dérive et suggestions dynamiques après chaque action.',
      agentIntroduction:
          'Vous n\'avez plus besoin de quitter votre écran de travail pour me parler : '
          'ancrez-moi à droite, en bas ou en fenêtre flottante. Après chaque opération '
          '(connexion, homing, chargement STEP, génération G-code ou alarme), je génère '
          'automatiquement de nouvelles suggestions pour vous guider étape par étape.',
      imageAssetPath: 'assets/logo.png',
      videoSimulationType: 'ai_memory',
      steps: [
        'Changez la position du Chatbot à la volée : Flottant (HUD), Bas (Console) ou Droite (Split-View).',
        'Cliquez sur les puces de suggestions dynamiques qui se mettent à jour après chaque opération.',
        'Changez la langue de l\'interface ou de l\'Agent IA en temps réel (Français, English, Bamanankan, Swahili, Arabe...).',
      ],
      targetScreenIndex: 0,
    ),
  ];

  static DemoBenchmarkSample? sampleById(String? id) {
    if (id == null) return null;
    for (final s in samples) {
      if (s.id == id || s.cadPath.toLowerCase().contains(id.toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  static List<DemoBenchmarkSample> byDomain(DemoDomain domain) =>
      samples.where((s) => s.domain == domain).toList();
}
