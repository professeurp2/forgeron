%
O1000 (TEST CINEMATIQUE FORGERON 5 AXES)
(ATTENTION: TESTER A VIDE D'ABORD)

(--- INITIALISATION ---)
G21 (Unites en mm)
G90 (Positionnement absolu)
G94 (Avance en mm/min)
G17 (Plan XY)
G40 (Annulation compensation rayon)
G49 (Annulation compensation longueur d'outil)
G54 (Selection origine piece 1)

(--- TEST 1 : MOUVEMENTS LINEAIRES 3 AXES ---)
(Verification des moteurs X, Y, Z et des fins de course)
G0 Z50.0 (Remontee de securite de la broche)
G0 X0.0 Y0.0 (Retour au centre)
G1 X50.0 F1000.0 (Deplacement lent sur X)
G1 Y50.0 (Deplacement lent sur Y)
G1 X-50.0
G1 Y-50.0
G1 X0.0 Y0.0
G1 Z20.0 F500.0 (Descente lente)
G0 Z50.0 (Remontee)

(--- TEST 2 : MOUVEMENTS ROTATIFS INDIVIDUELS ---)
(Verification des axes du Trunnion A et C)
(Assurez-vous que la broche est assez haute pour ne pas heurter le plateau inclinable)
G1 A30.0 F500.0 (Inclinaison positive)
G1 A-30.0 (Inclinaison negative)
G1 A0.0 (Retour a plat)
G1 C90.0 F800.0 (Quart de tour du plateau)
G1 C270.0 (Rotation opposee)
G1 C0.0 (Retour a zero)

(--- TEST 3 : MOUVEMENTS COMBINES 5 AXES ---)
(C'est ici que votre moteur RTCP et le parseur entrent en jeu)
(La pointe de l'outil virtuelle doit rester fluide et coherente)
G0 X0.0 Y0.0 Z50.0 A0.0 C0.0 (Position de depart)
G1 X20.0 Y20.0 Z30.0 A15.0 C45.0 F600.0 (Mouvement simultane complexe)
G1 X-20.0 Y-20.0 Z40.0 A-15.0 C135.0
G1 X0.0 Y0.0 Z50.0 A0.0 C0.0

(--- FIN DU PROGRAMME ---)
M30 (Fin et retour au debut du programme)
%