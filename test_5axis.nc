%
O1000 (TEST MOTEURS 5 AXES SUR BANC)
(Avertissement : S'assurer que les moteurs sont fixes)

(--- INITIALISATION ---)
G21 (Unites en millimetres)
G90 (Programmation en coordonnees absolues)
G94 (Avance en mm par minute)
G17 (Selection du plan XY)
G40 (Annulation de la compensation de rayon)
G49 (Annulation de la compensation de longueur d'outil)
G80 (Annulation des cycles de percage)

(--- RETOUR A ZERO VIRTUEL ---)
G92 X0 Y0 Z0 A0 C0 (Definit la position actuelle comme le zero absolu)
G04 P2000 (Pause de 2 secondes)

(===============================================)
( PHASE 1 : TEST INDIVIDUEL DES AXES A BASSE VITESSE)
(===============================================)
F500 (Vitesse lente : 500 mm/min ou deg/min)

(Test Axe X)
G01 X100
G01 X-100
G01 X0

(Test Axe Y)
G01 Y100
G01 Y-100
G01 Y0

(Test Axe Z)
G01 Z50
G01 Z-50
G01 Z0

(Test Axe A - Rotation)
G01 A180
G01 A-180
G01 A0

(Test Axe C - Rotation)
G01 C360
G01 C-360
G01 C0
G04 P1000 (Pause de 1 seconde)

(===============================================)
( PHASE 2 : INTERPOLATION 3D LINEAIRE - VITESSE MOYENNE)
(===============================================)
F1500 (Vitesse moyenne)

G01 X50 Y50 Z25
G01 X-50 Y-50 Z-25
G01 X50 Y-50 Z25
G01 X-50 Y50 Z-25
G01 X0 Y0 Z0
G04 P1000

(===============================================)
( PHASE 3 : TEST DE CERCLES ET SPIRALES 3 AXES)
(===============================================)
F2000
G02 X50 Y0 I25 J0 (Demi-cercle)
G03 X0 Y0 I-25 J0 (Demi-cercle inverse)
(Spirale ascendante en Z)
G02 X0 Y0 Z20 I30 J0
G02 X0 Y0 Z40 I30 J0
G01 X0 Y0 Z0

(===============================================)
( PHASE 4 : MOUVEMENTS 5 AXES SIMULTANES EXTREMES)
( Simulation d'un usinage de turbine ou d'une pale )
(===============================================)
F2500 (Vitesse rapide)

G01 X10 Y20 Z5 A15 C45
G01 X30 Y-20 Z10 A-30 C90
G01 X-20 Y40 Z15 A45 C135
G01 X-40 Y-10 Z20 A-60 C180
G01 X10 Y-30 Z15 A30 C225
G01 X50 Y10 Z5 A-15 C270
G01 X20 Y50 Z0 A0 C360

(Balayage fluide type "Swarf Machining")
F3000
G01 X100 Y100 Z50 A90 C720
G01 X-100 Y-100 Z-50 A-90 C-720
G01 X100 Y-100 Z50 A90 C720
G01 X-100 Y100 Z-50 A-90 C-720
G01 X0 Y0 Z0 A0 C0

(===============================================)
( PHASE 5 : TEST D'ACCELERATION / DECELERATION RAPIDE)
( Attention aux pertes de pas sur ce bloc )
(===============================================)
F5000 (Vitesse tres rapide - a ajuster selon tes drivers)
G01 X150
G01 X-150
G01 X0 Y150
G01 X0 Y-150
G01 Z100 A360 C360
G01 Z-100 A-360 C-360
G01 X0 Y0 Z0 A0 C0

(--- FIN DU PROGRAMME ---)
G04 P2000 (Pause de 2 secondes avant la fin)
M30 (Fin du programme et retour au debut)
%