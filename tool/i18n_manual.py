# -*- coding: utf-8 -*-
"""Cas que le codemod laisse de cote : pluriels et ternaires interpoles.

Le pluriel passe par deux cles distinctes choisies en Dart plutot que par un
'(s)' fourre-tout : chaque langue fournit ses deux formes.
"""
import io

EDITS = [
    # --- pluriels ---
    ('lib/presentation/screens/ai_assistant_screen.dart',
     "                    '$label · ${lines.length} ligne${lines.length > 1 ? 's' : ''}',\n",
     "                    tr(lines.length > 1 ? '{} · {} lignes' : '{} · {} ligne',\n"
     "                        [label, lines.length]),\n"),

    ('lib/presentation/screens/ai_assistant_screen.dart',
     "                            '${c.messageCount} message${c.messageCount > 1 ? 's' : ''} · '\n"
     "                            '${_fmtDate(c.updatedAt)}',\n",
     "                            tr(\n"
     "                                c.messageCount > 1\n"
     "                                    ? '{} messages · {}'\n"
     "                                    : '{} message · {}',\n"
     "                                [c.messageCount, _fmtDate(c.updatedAt)]),\n"),

    ('lib/presentation/screens/mdi_terminal_screen.dart',
     "                '${_logLines.length} LIGNE${_logLines.length > 1 ? 'S' : ''}',\n",
     "                tr(_logLines.length > 1 ? '{} LIGNES' : '{} LIGNE',\n"
     "                    [_logLines.length]),\n"),

    ('lib/presentation/screens/mobile_screens.dart',
     "            Text('$count outil${count > 1 ? 's' : ''}',\n",
     "            Text(tr(count > 1 ? '{} outils' : '{} outil', [count]),\n"),

    ('lib/presentation/screens/tool_table_screen.dart',
     "        Text('$count outil${count > 1 ? 's' : ''}',\n",
     "        Text(tr(count > 1 ? '{} outils' : '{} outil', [count]),\n"),

    # --- interpolations imbriquees ---
    ('lib/presentation/screens/ai_agent_settings_screen.dart',
     "                                  '${m.label} — ${m.rpd} req/j'\n"
     "                                  '${modelState.exhausted.contains(m.id) ? ' (épuisé)' : ''}',\n",
     "                                  tr('{} — {} req/j', [m.label, m.rpd]) +\n"
     "                                      (modelState.exhausted.contains(m.id)\n"
     "                                          ? tr(' (épuisé)')\n"
     "                                          : ''),\n"),

    ('lib/presentation/screens/connection_settings_screen.dart',
     "          '✅ Connecté à ${device.firmwareInfo ?? \"ESP32\"} @ $ip'),\n",
     "          tr('✅ Connecté à {} @ {}',\n"
     "              [device.firmwareInfo ?? 'ESP32', ip])),\n"),

    ('lib/presentation/screens/limit_recovery_screen.dart',
     "                      Text('Fins de course actives : ${active.join(', ')}',\n",
     "                      Text(tr('Fins de course actives : {}', [active.join(', ')]),\n"),

    ('lib/presentation/screens/limit_switch_test_screen.dart',
     "            '$n fin(s) de course détectée(s) : ${_seen.map((i) => _axes[i]).join(', ')}'\n"
     "            '${_seen.isEmpty ? '—' : ''}',\n",
     "            tr('{} fin(s) de course détectée(s) : {}', [\n"
     "              n,\n"
     "              _seen.isEmpty ? '—' : _seen.map((i) => _axes[i]).join(', '),\n"
     "            ]),\n"),

    ('lib/presentation/screens/setup_wizard_screen.dart',
     "                          'course ${k.maxTravel?.toStringAsFixed(0) ?? '—'} mm · '\n"
     "                          '${k.stepsPerMm?.toStringAsFixed(0) ?? '—'} pas/mm',\n",
     "                          tr('course {} mm · {} pas/mm', [\n"
     "                            k.maxTravel?.toStringAsFixed(0) ?? '—',\n"
     "                            k.stepsPerMm?.toStringAsFixed(0) ?? '—',\n"
     "                          ]),\n"),

    # Message compose : plus lisible monte dans un tampon que par
    # interpolations imbriquees.
    ('lib/presentation/screens/mobile_dashboard_screen.dart',
     "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n"
     "        content: Text(\n"
     "          '${blocked ? '⛔ ' : '✓ '}G-code adapté — '\n"
     "          '${next.adaptWarnings.length} point(s). ${next.adaptWarnings.first}'\n"
     "          '${blocked ? ' Corrige le post CAM avant d\\'exécuter.' : ''}',\n"
     "          style: const TextStyle(fontSize: 12),\n"
     "        ),\n",
     "      final message = StringBuffer(blocked ? '⛔ ' : '✓ ')\n"
     "        ..write(tr('G-code adapté — {} point(s). {}',\n"
     "            [next.adaptWarnings.length, next.adaptWarnings.first]));\n"
     "      if (blocked) {\n"
     "        message.write(' ${tr(\"Corrige le post CAM avant d'exécuter.\")}');\n"
     "      }\n"
     "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(\n"
     "        content: Text(\n"
     "          message.toString(),\n"
     "          style: const TextStyle(fontSize: 12),\n"
     "        ),\n"),
]

NEW_KEYS = [
    '{} · {} lignes', '{} · {} ligne',
    '{} messages · {}', '{} message · {}',
    '{} LIGNES', '{} LIGNE',
    '{} outils', '{} outil',
    '{} — {} req/j', ' (épuisé)',
    '✅ Connecté à {} @ {}',
    'Fins de course actives : {}',
    '{} fin(s) de course détectée(s) : {}',
    'course {} mm · {} pas/mm',
    'G-code adapté — {} point(s). {}',
    "Corrige le post CAM avant d'exécuter.",
]


def main():
    done = 0
    for path, old, new in EDITS:
        src = io.open(path, encoding='utf-8').read()
        if src.count(old) != 1:
            print('  ECHEC %-46s (%d occurrences)' % (path.split('/')[-1],
                                                     src.count(old)))
            continue
        io.open(path, 'w', encoding='utf-8', newline='').write(
            src.replace(old, new))
        done += 1
    print('remplacements appliques :', done, '/', len(EDITS))

    import json
    keys = set(json.load(io.open('tool/i18n_keys.json', encoding='utf-8')))
    keys.update(NEW_KEYS)
    io.open('tool/i18n_keys.json', 'w', encoding='utf-8').write(
        json.dumps(sorted(keys), ensure_ascii=False, indent=1))
    print('cles totales :', len(keys))


main()
