# -*- coding: utf-8 -*-
"""Annule les tr() tombes dans des collections `const` de donnees.

Ces libellés sont des DONNEES (barre de navigation, onglets, table de
correspondance), pas des widgets : `tr()` y est interdit par le langage, et
retirer le `const` casserait en cascade. Ils se traduisent au point
d'affichage.
"""
import io
import re

APOS = chr(92) + "'"   # \' tel qu'ecrit dans le source Dart

CIBLES = {
    'lib/presentation/screens/main_scaffold.dart': [
        "PALPAGE & ORIGINES",
        "MAGASIN D" + APOS + "OUTILS",
        "TERMINAL MDI",
        "AGENT IA",
    ],
    'lib/presentation/screens/mobile_dashboard_screen.dart': [
        "JOG",
        "PROGRAMME",
    ],
    'lib/presentation/screens/desktop/ai_console_timeline.dart': [
        "Arrêt d" + APOS + "urgence",
    ],
}


def main():
    for p, textes in CIBLES.items():
        s = io.open(p, encoding='utf-8').read()
        n = 0
        for t in textes:
            vieux = "tr('" + t + "')"
            if s.count(vieux) >= 1:
                s = s.replace(vieux, "'" + t + "'")
                n += 1
            else:
                print('  ! introuvable : %s' % vieux[:60])
        io.open(p, 'w', encoding='utf-8', newline='').write(s)
        print('%-46s %d annule(s)' % (p.split('/')[-1], n))


main()
