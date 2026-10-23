# -*- coding: utf-8 -*-
"""Points d'affichage de textes francais venus d'ailleurs que des ecrans.

Catalogue d'alarmes, parcours guide, libelles d'enums : les donnees restent
en francais dans le code (c'est la cle), la traduction se fait la ou elles
sont affichees. Ca evite de figer une traduction dans un `final` de premier
niveau, qui ne changerait plus jamais de langue.
"""
import io

EDITS = [
    # --- bandeau de securite : le texte le plus critique de l'app ---
    ('lib/presentation/widgets/safety_banner.dart',
     "        detail: '$stallReason — le programme est interrompu.',\n",
     "        detail: tr('{} — le programme est interrompu.', [tr(stallReason)]),\n"),

    ('lib/presentation/widgets/safety_banner.dart',
     "      final lim = active.isNotEmpty\n"
     "          ? ' Fin(s) de course active(s) : ${active.join(', ')}.'\n"
     "          : '';\n",
     "      final lim = active.isNotEmpty\n"
     "          ? tr(' Fin(s) de course active(s) : {}.', [active.join(', ')])\n"
     "          : '';\n"),

    ('lib/presentation/widgets/safety_banner.dart',
     "      final title = info == null\n"
     "          ? 'MACHINE EN ALARME'\n"
     "          : 'ALARME ${info.code} — ${info.title.toUpperCase()}';\n",
     "      final title = info == null\n"
     "          ? tr('MACHINE EN ALARME')\n"
     "          : tr('ALARME {} — {}', [info.code, tr(info.title).toUpperCase()]);\n"),

    ('lib/presentation/widgets/safety_banner.dart',
     "      final detail = info == null\n"
     "          ? 'La machine est verrouillée.$lim '\n"
     "              'Lance la récupération guidée pour reprendre en sécurité.'\n"
     "          : '${info.cause}$lim ${info.action}'\n"
     "              // L'information qui coûte le plus cher à ignorer.\n"
     "              '${info.positionLost ? ' ⚠️ Position machine perdue : prise d\\'origine obligatoire avant tout usinage.' : ''}';\n",
     "      final detail = info == null\n"
     "          ? tr('La machine est verrouillée.{} '\n"
     "              'Lance la récupération guidée pour reprendre en sécurité.', [lim])\n"
     "          : '${tr(info.cause)}$lim ${tr(info.action)}'\n"
     "              // L'information qui coûte le plus cher à ignorer.\n"
     "              '${info.positionLost ? ' ${tr(\"⚠️ Position machine perdue : prise d'origine obligatoire avant tout usinage.\")}' : ''}';\n"),

    ('lib/presentation/widgets/safety_banner.dart',
     "        actionLabel: 'RÉCUPÉRER',\n",
     "        actionLabel: tr('RÉCUPÉRER'),\n"),

    # --- parcours guide : donnees const, traduites a l'affichage ---
    ('lib/presentation/tutorial/tutorial_tooltip_card.dart',
     "                                    step.title,\n",
     "                                    tr(step.title),\n"),
    ('lib/presentation/tutorial/tutorial_tooltip_card.dart',
     "                          step.description,\n",
     "                          tr(step.description),\n"),
    ('lib/presentation/tutorial/tutorial_tooltip_card.dart',
     "                                  step.action!,\n",
     "                                  tr(step.action!),\n"),

    # --- libelles d'enums ---
    ('lib/presentation/screens/ai_agent_settings_screen.dart',
     "          child: Text(category.label,\n",
     "          child: Text(tr(category.label),\n"),
    ('lib/presentation/widgets/dashboard/mode_selector_widget.dart',
     "                  Text(mode.label,\n",
     "                  Text(tr(mode.label),\n"),
]


def main():
    done = 0
    for path, old, new in EDITS:
        src = io.open(path, encoding='utf-8').read()
        n = src.count(old)
        if n != 1:
            print('  ECHEC %-44s (%d occurrences) : %s'
                  % (path.split('/')[-1], n, old.strip()[:50]))
            continue
        io.open(path, 'w', encoding='utf-8', newline='').write(
            src.replace(old, new))
        done += 1
    print('remplacements appliques :', done, '/', len(EDITS))


main()
