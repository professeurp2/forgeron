# Chapitre 3 — Méta-Prompt v4 (Final)
## Section 3.4 : Dimensionnement COMPLET du Trunnion (A et C)
## NEMA 17 + GT2 10T→60T (6:1) — Étage unique

---

```
Tu es un ingénieur mécatronicien senior. Tu rédiges la section 3.4 du
Chapitre 3 d'un PFE sur une fraiseuse CNC 5 axes compacte Trunnion.

Cette section est COMPLÈTE et AUTONOME : transmission, arbres, fatigue,
roulements, liaisons. Aucun renvoi vers d'autres sections.

Style IDENTIQUE aux sections 3.3.1–3.3.3 (axes linéaires) :
  1) Formule littérale
  2) Application numérique — Cas nominal 5-axes
  3) Application numérique — Cas nominal 3-axes (A/C verrouillés)
  4) Application numérique — Cas extrême
  5) Conclusion et coefficient de sécurité

═══════════════════════════════════════════════════════════════════
                    DONNÉES EN AMONT
═══════════════════════════════════════════════════════════════════

■ DEUX RÉGIMES OPÉRATIONNELS (approche standard industrielle) :

  Cas nominal 5-axes (A et C actifs, coupe adaptée) :
    Paramètres : fraise Ø6 carbure 3 dents, alu 6061
    ap = 0,5 mm, ae = 1,5 mm, fz = 0,05 mm/dent
    R_5ax = 30 N (résultante estimée)
    Ce régime est imposé par le logiciel embarqué Forgeron qui
    limite automatiquement les avances en mode 5-axes simultané.

  Cas nominal 3-axes (A et C verrouillés en position, seuls X,Y,Z bougent) :
    Paramètres : identiques à la section 3.2 du PFE
    R_3ax = 180 N
    Les axes A et C sont bloqués en position ; le moteur fournit
    son couple de maintien. Les efforts sont repris par la structure
    (arbres + roulements), pas par le moteur en rotation.

  Cas extrême (théorique, pleine matière) :
    R_ext = 8 312 N
    Ce cas n'est pas un régime permanent. Il sert uniquement à
    identifier les limites structurelles de l'arbre.

  IMPORTANT : les sections 3.2 et 3.3 (axes linéaires X,Y,Z) restent
  inchangées — elles sont dimensionnées pour R = 180 N / 8 312 N
  avec des NEMA 23 + vis T8, ce qui est correct et validé.

■ MASSES ET POIDS :
    m_pièce = 2 kg → W_pièce = 19,62 N
    m_plateau = 1,5 kg
    m_berceau = 0,5 kg
    m_A = 4 kg → W_A = 39,24 N

■ GÉOMÉTRIE DU TRUNNION :
    Entraxe paliers arbre A (Lb) : 120 mm
    Diamètre plateau C (Dp)      : 100 mm
    Offset TCP / axe A           : e_A = 60 mm
    Offset TCP / axe C           : e_C = 30 mm
    Plage A : ±90° | Plage C : 360° continu

■ TRANSMISSION — ÉTAGE UNIQUE : NEMA 17 + GT2 10T→60T

  Architecture : simple, compacte, un seul étage de courroie.
  Chaîne cinématique (identique pour A et C) :
    Moteur NEMA 17 → Poulie GT2-10T (sur arbre moteur Ø5)
    → Courroie GT2 (7 mm) → Poulie GT2-60T (sur arbre A ou C, Ø8)
    → Arbre → Berceau (A) ou Plateau (C)

  Moteur NEMA 17 (42BYGHW811), identique pour A et C :
    T_hold = 0,48 N·m (couple de maintien)
    T_nom = 0,40 N·m (couple nominal à 200 rpm)
    Courant : 1,2 A/phase
    Pas : 1,8° (200 pas/tour)
    Arbre moteur : Ø5 mm

  Poulie menante (moteur) :
    GT2, 10 dents, alésage Ø5 mm
    d_menante = 10 × 2 / π = 6,37 mm | r_menante = 3,18 mm

  Poulie menée (arbre) :
    GT2, 60 dents, alésage Ø8 mm
    d_menée = 60 × 2 / π = 38,20 mm | r_menée = 19,10 mm

  Rapport de réduction : i = 60 / 10 = 6
  Rendement : η = 0,95 (étage unique, courroie crantée)

  Courroie GT2 — 7 mm de large :
    Pas : p = 2 mm
    Largeur : b = 7 mm
    Tension admissible continue (basse vitesse) : ~70 N
    Effort admissible par dent en prise : ~4 N (échelle 7/6 du 6mm)

  Entraxe estimé :
    a_A ≈ 60 mm (axe A)
    a_C ≈ 50 mm (axe C)

■ COUPLES EN SORTIE :
    T_hold,sortie = 0,48 × 6 × 0,95 = 2,74 N·m
    T_nom,sortie = 0,40 × 6 × 0,95 = 2,28 N·m
    R_max = T_hold / e_A = 2,74 / 0,060 = 45,6 N (> R_5ax = 30 N ✓)

■ MATÉRIAU DES ARBRES : Acier C45 normalisé
    Re = 340 MPa | Rm = 620 MPa | E = 210 GPa | G = 81 GPa
    σ_adm = Re / s = 170 MPa (s = 2)

■ FATIGUE :
    σ'_D = 0,5 × Rm = 310 MPa (brute)
    Facteurs correctifs :
      Ks = 0,75 (surface usinée)
      Kt = 0,85 (taille, d ≈ 20 mm)
      Kf = 0,56 (concentration de contrainte, gorge)
      Kr = 0,897 (fiabilité 90 %)
    Broche : N = 8 680 tr/min, Z = 3 dents → f_dents = 434 Hz
    Durée de vie cible : > 10⁷ cycles (endurance illimitée)

■ ROULEMENTS :
    Vitesse max axe A : n_A ≈ 30 tr/min
    Vitesse max axe C : n_C ≈ 60 tr/min
    Durée de vie cible : L10h > 20 000 h
    Classe de précision : P5 minimum

■ COEFFICIENT DE SÉCURITÉ GLOBAL : s = 2

═══════════════════════════════════════════════════════════════════
                    TRAVAIL DEMANDÉ
═══════════════════════════════════════════════════════════════════

Chaque calcul doit présenter les 3 cas : nominal 5-axes, 3-axes, extrême.

──────────────────────────────────────────────
3.4.1 — ARCHITECTURE ET JUSTIFICATION
──────────────────────────────────────────────
  • Présenter le Trunnion : berceau basculant (A) + plateau rotatif (C)
  • Transmission : un seul étage GT2, moteur NEMA 17 déporté
    [Figure 3.XX : Schéma cinématique du Trunnion GT2 10T→60T]
  • Justification du choix :
    - Coût (composants standards, <10 €/axe)
    - Compacité (un étage, moteur hors du berceau)
    - Rapport 6:1 → couple multiplié par 6
    - Amortissement vibrations par la courroie élastique
    - Maintenance aisée (remplacement courroie en minutes)
  • Tableau comparatif : entraînement direct vs courroie 3:1 vs courroie 6:1
  • Expliquer les DEUX régimes opérationnels :
    - Mode 5-axes : R ≤ 30 N (coupe adaptée, limitation Forgeron)
    - Mode 3-axes : R = 180 N (A/C verrouillés, maintien moteur)
  • Montrer que R_max = 45,6 N > R_5ax = 30 N → marge de 1,52

──────────────────────────────────────────────
3.4.2 — DIMENSIONNEMENT DE LA TRANSMISSION PAR COURROIE
──────────────────────────────────────────────

3.4.2.1 — Axe A
  a) Rapport de réduction et couple :
     i_A = 60/10 = 6
     T_A = T_mot × i × η = 0,40 × 6 × 0,95
  b) Diamètres primitifs :
     d_menante = 10 × 2 / π, d_menée = 60 × 2 / π
  c) Longueur de courroie :
     L = 2a + π/2·(d1+d2) + (d2-d1)²/(4a)
     avec a_A = 60 mm
  d) Nombre de dents en prise (poulie 10T) :
     z_prise = Z_menante/2 × (1 - (d2-d1)/(2a))
     ⚠ Avec une poulie 10T, z_prise sera faible → vérifier ≥ 6
  e) Vérification courroie :
     F_u = T_A / r_menée (effort utile)
     F_adm = z_prise × 4 N (pour 7mm)
     Vérifier F_u ≤ F_adm
  f) Tension et charge radiale sur arbre :
     F_1 ≈ 1,5 × F_u (brin tendu, pré-tension)
     F_2 = F_1 - F_u
     F_courroie_A = F_1 + F_2

3.4.2.2 — Axe C (même structure, a_C = 50 mm)

3.4.2.3 — Synthèse transmission
  | Paramètre | Axe A | Axe C |

──────────────────────────────────────────────
3.4.3 — MODÉLISATION ET CALCUL DES ARBRES DE ROTATION
──────────────────────────────────────────────

3.4.3.1 — Schéma de chargement de l'arbre A
  [Figure 3.XX : Schéma de chargement — arbre A]
  Modèle : poutre bi-appuyée, Lb = 120 mm
  Charges :
    - W_A = 39,24 N (poids, au centre, permanent)
    - M_coupe = R × e_A :
        5-axes : 30 × 0,06 = 1,80 N·m
        3-axes : 180 × 0,06 = 10,80 N·m
        Extrême : 8312 × 0,06 = 498,72 N·m
    - T_A = couple de torsion (calculé en 3.4.2)
    - F_courroie_A = charge radiale (calculée en 3.4.2)
  Réactions aux appuis R1, R2
  Diagrammes T(x) et Mf(x) : analytiques
  Section dangereuse : identifier

3.4.3.2 — Diamètre minimal arbre A (Von Mises)
  σ_f = 32·Mf/(π·d³)
  τ = 16·T_A/(π·d³)
  σ_eq = √(σ_f² + 3·τ²) ≤ σ_adm
  d_min = ∛( (32/(π·σ_adm)) × √(Mf² + 0,75·T²) )
  CAS NOMINAL 5-AXES : Mf=?, T=?, d_min=?
  CAS NOMINAL 3-AXES : Mf=?, T=?, d_min=?
  CAS EXTRÊME : Mf=?, T=?, d_min=?
  Choix d_A normalisé, vérification n_sécu pour les 3 cas

3.4.3.3 — Schéma de chargement de l'arbre C [Figure]
  Modèle : arbre vertical, appui inf + guidage sup
  Charges : W_pièce, M_C = R × e_C (3 cas), T_C, F_courroie_C

3.4.3.4 — Diamètre minimal arbre C (Von Mises)
  Particularité : σ_traction = 4·W_pièce/(π·d²)
  σ_eq = √((σ_f + σ_traction)² + 3·τ²) ≤ σ_adm
  3 cas, choix d_C normalisé

3.4.3.5 — Synthèse arbres
  | Arbre | Mf_5ax | Mf_3ax | Mf_ext | T | d_min_5ax | d_min_3ax | d_min_ext | d_choisi | n_5ax | n_3ax | n_ext |

──────────────────────────────────────────────
3.4.4 — VÉRIFICATION À LA FATIGUE ET À LA RIGIDITÉ
──────────────────────────────────────────────

3.4.4.1 — Limite d'endurance corrigée
  σ_D = σ'_D × Ks × Kt × Kf × Kr
  Application numérique → σ_D = ? MPa

3.4.4.2 — Diagramme de Haigh — Arbre A
  [Figure 3.XX : Diagramme de Haigh — arbre A]
  Contraintes moyennes (poids permanent) :
    σ_m = 32·M_W,A/(π·d³), τ_m = 16·T_A/(π·d³)
    σ_m,eq = √(σ_m² + 3·τ_m²)
  Contraintes alternées (coupe cyclique) :
    σ_a = 32·M_coupe/(π·d³)
    σ_a,eq = √(σ_a² + 3·τ_a²)
  Goodman : σ_a/σ_D + σ_m/Rm ≤ 1/s
  n_fatigue pour les 3 cas
  Position du point de fonctionnement sur la droite de Goodman

3.4.4.3 — Diagramme de Haigh — Arbre C [Figure]
  Rotation continue → flexion tournante (σ_m ≈ 0)
  Critère : σ_a ≤ σ_D/s
  n_fatigue pour les 3 cas

3.4.4.4 — Rigidité en torsion
  θ = T·L/(G·Ip) ≤ 0,25°/m
  Calcul pour les 2 arbres

3.4.4.5 — Flèche en flexion
  f = F·L³/(48·E·I) ≤ 0,01 mm
  Calcul pour l'arbre A

3.4.4.6 — Synthèse
  | Arbre | n_fat_5ax | n_fat_3ax | n_fat_ext | θ (°/m) | f (mm) | Validé ? |

──────────────────────────────────────────────
3.4.5 — SÉLECTION DES ROULEMENTS DE PRÉCISION
──────────────────────────────────────────────
3.4.5.1 — Réactions aux paliers
3.4.5.2 — Choix type (contact oblique / butée+radial)
3.4.5.3 — Charge équivalente Pe = fw × (X·Fr + Y·Fa)
3.4.5.4 — Durée de vie L10h > 20 000 h (3 cas)
3.4.5.5 — Charge statique Fs = C0/P0 ≥ 3
3.4.5.6 — Synthèse
  | Palier | Type | Réf | C(kN) | Pe(N) | L10h(h) | Fs | Verdict |

──────────────────────────────────────────────
3.4.6 — DIMENSIONNEMENT DES LIAISONS MÉCANIQUES
──────────────────────────────────────────────
3.4.6.1 — Arbre / poulie GT2-60T (clavette DIN 6885 ou vis de pression)
  Matage : P_mat = 2·T/(d × t2 × Lu) ≤ P_adm
  Cisaillement : τ = 2·T/(d × b × Lu) ≤ 0,6·Re/s
  Pour les 2 arbres
3.4.6.2 — Moteur / poulie GT2-10T (vis de serrage M3)
3.4.6.3 — Synthèse liaisons

──────────────────────────────────────────────
3.4.7 — SYNTHÈSE GÉNÉRALE DU TRUNNION
──────────────────────────────────────────────
  ⚠ SECTION CONCLUSIVE MAJEURE ⚠
  Tableau comparatif A vs C (même format que 3.3.3.6) :

  | Paramètre               | Axe A    | Axe C    |
  |--------------------------|----------|----------|
  | Rapport i                | 6        | 6        |
  | T_sortie (N·m)           |          |          |
  | R_max admissible (N)     |          |          |
  | Mf (5ax/3ax/ext) (N·m)   |          |          |
  | d_choisi (mm)            |          |          |
  | n_statique (5ax/3ax/ext) |          |          |
  | n_fatigue (5ax/3ax/ext)  |          |          |
  | θ (°/m) / f (mm)         |          |          |
  | Roulement / L10h (h)     |          |          |
  | Liaison                  |          |          |
  | AXE CRITIQUE ?           |          |          |

  CONCLUSION GÉNÉRALE :
  → Architecture GT2 10T→60T validée en mode 5-axes (R ≤ 45,6 N)
  → En mode 3-axes (R = 180 N), A/C sont verrouillés :
    la structure (arbre + roulements) reprend les efforts,
    le couple de maintien assure la stabilité angulaire
  → Le cas extrême n'est pas un régime permanent
  → La limitation logicielle (Forgeron) garantit la sécurité
  → Transition vers section 3.5 (structure et analyse dynamique)

═══════════════════════════════════════════════════════════════════
                  RÈGLES DE RÉDACTION
═══════════════════════════════════════════════════════════════════
■ Français académique (PFE ENI), LaTeX pour les formules
■ Volume : 30–40 pages
■ Triple vérification : cas nominal 5-axes + cas 3-axes + cas extrême
■ Structure systématique : formule → AN → conclusion
■ [Figure 3.XX : ...] pour chaque schéma
■ Tableaux récapitulatifs à chaque fin de sous-section
■ Ne PAS renvoyer vers d'autres sections
■ Ne PAS inventer de nouvelles valeurs d'efforts
■ Ne PAS modifier les données fournies ci-dessus
```
