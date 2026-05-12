; DEBUT DU PROGRAMME DE FINITION "PIECE EN S"
N10 ; DATE : 2026-05-12 - POST-PROCESSEUR SIEMENS 840D
N20 ; USINAGE DE LA SURFACE REGLEE DE LA PIECE EN S (ISO 10791-7)

; Initialisation standard
N30 G54 G90 G17 G71 G94 G64 ; Unites metriques, avance en mm/min
N40 G0 SUPA Z0 D0 ; Retour a la position de changement d'outil
N50 T="FRAISE_BOULE_D10" M6 ; Appel outil de finition

; Activation des fonctions de transformation 5 axes
N60 G54 G90 G17
N70 TRAORI(1) ; ACTIVER TRANSFORMATION ORIENTATION 5 AXES
N80 M128 ; Activer le deplacement 5 axes simultane

; Compensation d'outil et approche rapide
N90 G0 X10.5 Y-25.4 Z150. A0 C0 D1
N100 FGROUP(X,Y,Z,A,C)
N110 G1 Z50. F5000

; --- DEBUT DES TRAJECTOIRES DE FINITION ---
; Chaque bloc ci-dessous definit un mouvement simultane
; sur les 5 axes : X, Y, Z, A (autour de X) et C (autour de Z).

N120 G1 X11.51 Y-24.32 Z-10.79 A3.511 C45.98 F1800
N130 X12.55 Y-23.15 Z-11.05 A3.422 C46.30
N140 X13.61 Y-21.89 Z-11.23 A3.317 C46.56
...
; (Cette séquence se poursuit sur des centaines de blocs
; pour décrire précisément la surface gauche en S.)
...
N1850 X-14.2 Y22.61 Z-12.11 A-3.550 C138.65
N1860 X-13.2 Y23.82 Z-11.98 A-3.462 C138.96
...
; Fin de la surface
N5200 G1 Z50. F5000

; Arret des fonctions 5 axes et fin de programme
N5210 M129 ; Desactiver le deplacement 5 axes simultane
N5220 TRAFOOF ; DESACTIVER TRANSFORMATION ORIENTATION
N5230 G0 SUPA Z0 D0
N5240 M30 ; FIN DE PROGRAMME