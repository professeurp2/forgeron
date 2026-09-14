import 'dart:async';
import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, SelectableText;

import '../../../application/providers/ai_agent_provider.dart';
import '../../../core/theme/forgeron_colors.dart';

/// Le fil de la console IA : bulles, étapes d'outils et indicateurs vivants.
///
/// Ce qui distingue ce fil de la première version : une étape n'attend plus sa
/// fin pour exister. Le contrôleur publie chaque appel d'outil dès son
/// démarrage (voir `AiChatMessage.toolStarted`), donc l'écran peut montrer ce
/// que l'agent fait PENDANT qu'il le fait — chrono qui tourne, arguments
/// visibles, résultat qui vient se poser à la place du « en cours… ». La
/// version précédente ne savait afficher que des lignes figées, toutes
/// apparues d'un coup après coup.

// ───────────────────────────── Regroupement ─────────────────────────────────

/// Une suite d'appels d'outils consécutifs, présentée comme UNE activité
/// repliable — comme une session d'outils dans Claude Desktop, pas comme dix
/// messages indiscernables du reste de la conversation.
class ToolRun {
  ToolRun(this.steps);

  final List<AiChatMessage> steps;

  bool get isRunning => steps.any((s) => s.isRunningTool);
  int get failures => steps.where((s) => s.toolFailed).length;
  int get done => steps.where((s) => !s.isRunningTool).length;

  /// Somme des temps d'exécution connus. Une étape en cours n'y compte pas :
  /// son chrono à elle tourne dans sa propre ligne.
  Duration get elapsed => steps.fold(
        Duration.zero,
        (total, s) => total + (s.toolDuration ?? Duration.zero),
      );

  /// Ligne de résumé quand l'activité est repliée. Nomme la première étape et
  /// compte le reste : « Génération du G-code, +2 autres ».
  String get headline {
    if (steps.isEmpty) return 'Aucune étape';
    final running = steps.where((s) => s.isRunningTool).toList();
    final lead = running.isNotEmpty ? running.first : steps.first;
    final label = friendlyToolLabel(lead.toolName ?? lead.text);
    if (steps.length == 1) return label;
    return '$label, +${steps.length - 1} autre${steps.length > 2 ? 's' : ''}';
  }
}

/// Regroupe les messages `tool` consécutifs. Le reste (user/assistant) reste
/// un élément à part, dans le même ordre que le fil.
List<Object> groupConsoleItems(List<AiChatMessage> messages) {
  final out = <Object>[];
  List<AiChatMessage>? current;
  for (final m in messages) {
    if (m.isTool) {
      (current ??= []).add(m);
    } else {
      if (current != null) {
        out.add(ToolRun(current));
        current = null;
      }
      out.add(m);
    }
  }
  if (current != null) out.add(ToolRun(current));
  return out;
}

// ─────────────────────────────── Libellés ───────────────────────────────────

/// Traduit un nom d'outil technique en une phrase compréhensible sans savoir
/// coder ni usiner. Les outils absents de cette liste retombent sur une mise
/// en forme générique (underscores → espaces) — jamais un plantage, juste un
/// libellé moins soigné en attendant de l'ajouter ici.
const _toolLabels = <String, String>{
  'run_step_pipeline': 'Génération du G-code depuis le fichier STEP',
  'preview_step_file': 'Aperçu 3D de la pièce',
  'open_toolpath_window': 'Ouverture du parcours d\'outil en 3D',
  'run_gcode_program': 'Chargement du programme dans l\'espace de travail',
  'analyze_gcode': 'Analyse du programme G-code',
  'get_machine_state': 'Lecture de l\'état de la machine',
  'get_diagnostics': 'Vérification de la machine',
  'home': 'Prise d\'origine (homing)',
  'probe': 'Palpage de la pièce',
  'jog_axis': 'Déplacement manuel d\'un axe',
  'goto_position': 'Déplacement vers une position',
  'set_work_zero': 'Réglage du zéro pièce',
  'send_gcode': 'Envoi d\'une commande à la machine',
  'run_program': 'Lancement de l\'usinage',
  'stop_program': 'Arrêt de l\'usinage',
  'pause': 'Mise en pause',
  'resume': 'Reprise de l\'usinage',
  'emergency_stop': 'Arrêt d\'urgence',
  'unlock_alarm': 'Déblocage de l\'alarme',
  'get_camera_snapshot': 'Photo de la caméra atelier',
  'list_workspace_files': 'Liste des fichiers de l\'espace de travail',
  'read_workspace_file': 'Lecture d\'un fichier',
  'write_workspace_file': 'Écriture d\'un fichier',
  'show_popup': 'Message de l\'agent',
  'open_chart_window': 'Ouverture d\'un graphique',
  'open_gcode_window': 'Ouverture du G-code dans une fenêtre',
};

String friendlyToolLabel(String toolName) =>
    _toolLabels[toolName] ??
    toolName
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp('^.'), (m) => m.group(0)!.toUpperCase());

/// Résumé court d'un résultat, pour la ligne repliée. `run_step_pipeline`
/// répond en JSON : on en tire une phrase plutôt que d'afficher les accolades
/// brutes — le détail complet reste accessible en dépliant.
String resultSummary(String toolName, String result) {
  if (result.startsWith('Erreur')) return result;
  try {
    final data = jsonDecode(result);
    if (data is Map<String, dynamic>) {
      if (toolName == 'run_step_pipeline') {
        // Le nom du pipeline interne (révolution / FreeCAD prismatique) ne
        // regarde pas l'opérateur — seul le résultat compte : ce qui a été
        // usiné et combien de lignes ça fait.
        final parts = <String>[
          if (data['operations'] is List) '${(data['operations'] as List).length} opération(s)',
          if (data['lignes_gcode'] != null) '${data['lignes_gcode']} lignes de G-code',
        ];
        return parts.join(' · ');
      }
      if (toolName == 'preview_step_file') {
        final size = (data['encombrement_mm'] as List?)
            ?.map((e) => (e as num).toStringAsFixed(1))
            .join(' × ');
        return [
          if (size != null) '$size mm',
          if (data['triangles'] != null) '${data['triangles']} triangles',
        ].join(' · ');
      }
    }
  } catch (_) {
    // Pas du JSON (message d'erreur, texte libre) → on laisse tel quel.
  }
  return result.length > 90 ? '${result.substring(0, 90)}…' : result;
}

/// « 12 s », « 1 min 04 s », « 240 ms » — jamais « 0:01:04.123456 ».
String formatDuration(Duration d) {
  if (d.inSeconds < 1) return '${d.inMilliseconds} ms';
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours < 1) return '${d.inMinutes} min $s s';
  return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min';
}

/// « 240.8k » plutôt que « 240812 » : le chiffre exact n'apporte rien, l'ordre
/// de grandeur si.
String formatTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  return '${(tokens / 1000).toStringAsFixed(1)}k';
}

// ──────────────────────────── Chrono en direct ──────────────────────────────

/// Affiche le temps écoulé depuis [since], mis à jour chaque seconde.
///
/// Un `Timer` local plutôt qu'un rebuild de tout l'écran : seule cette ligne
/// change, et la console reste utilisable pendant une génération longue.
class LiveElapsed extends StatefulWidget {
  const LiveElapsed({super.key, required this.since, required this.style});

  final DateTime since;
  final TextStyle style;

  @override
  State<LiveElapsed> createState() => _LiveElapsedState();
}

class _LiveElapsedState extends State<LiveElapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        formatDuration(DateTime.now().difference(widget.since)),
        style: widget.style,
      );
}

/// Ligne d'état de bas de fil : l'astérisque qui pulse, le chrono, les jetons
/// et ce que l'agent est en train de faire. C'est elle qui fait la différence
/// entre « ça travaille » et « c'est figé ».
class LiveStatusLine extends StatefulWidget {
  const LiveStatusLine({
    super.key,
    required this.fc,
    required this.since,
    required this.tokens,
    required this.activity,
  });

  final ForgeronColorPalette fc;
  final DateTime? since;
  final int tokens;

  /// « Réflexion… », « Exécution des outils… » — ce qui se passe maintenant.
  final String activity;

  @override
  State<LiveStatusLine> createState() => _LiveStatusLineState();
}

class _LiveStatusLineState extends State<LiveStatusLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    final style = TextStyle(color: fc.textDisabled, fontSize: 11.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: .25, end: 1).animate(_pulse),
            child: Text('✳', style: TextStyle(color: fc.primary, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          if (widget.since != null) ...[
            LiveElapsed(since: widget.since!, style: style),
            Text(' · ', style: style),
          ],
          if (widget.tokens > 0) ...[
            Text('${formatTokens(widget.tokens)} jetons', style: style),
            Text(' · ', style: style),
          ],
          Flexible(
            child: Text(widget.activity, overflow: TextOverflow.ellipsis, style: style),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Étapes d'outils ───────────────────────────────

/// Une activité d'outils, repliable — la brique qui donne au fil son allure de
/// procédure plutôt que de journal.
///
/// Elle se déplie d'elle-même tant qu'elle tourne (on veut voir l'étape en
/// cours), puis se replie une fois finie — sauf si l'opérateur l'a ouverte à
/// la main, auquel cas son choix prime.
class ToolRunTile extends StatefulWidget {
  const ToolRunTile({super.key, required this.fc, required this.run});

  final ForgeronColorPalette fc;
  final ToolRun run;

  @override
  State<ToolRunTile> createState() => _ToolRunTileState();
}

class _ToolRunTileState extends State<ToolRunTile> {
  /// `null` = pas de choix explicite, l'activité suit son état d'exécution.
  bool? _userExpanded;

  bool get _expanded => _userExpanded ?? widget.run.isRunning;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    final run = widget.run;
    final failed = run.failures > 0;
    final accent = run.isRunning ? fc.primary : (failed ? fc.danger : fc.success);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border.all(
          color: run.isRunning ? accent.withValues(alpha: .35) : fc.surfaceBorder,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(fc, run, accent, failed),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  for (final step in run.steps) StepRow(fc: fc, step: step),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(
    ForgeronColorPalette fc,
    ToolRun run,
    Color accent,
    bool failed,
  ) {
    final counter = run.isRunning
        ? '${run.done}/${run.steps.length}'
        : (failed ? '${run.failures} échec${run.failures > 1 ? 's' : ''}' : '${run.steps.length} étape${run.steps.length > 1 ? 's' : ''}');

    return fluent.HyperlinkButton(
      onPressed: () => setState(() => _userExpanded = !_expanded),
      style: fluent.ButtonStyle(
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      child: Row(
        children: [
          StatusDot(color: accent, running: run.isRunning, failed: failed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              run.headline,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fc.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            counter,
            style: TextStyle(
              color: run.isRunning ? fc.primary : fc.textDisabled,
              fontSize: 10.5,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          if (!run.isRunning && run.elapsed > Duration.zero) ...[
            Text(' · ',
                style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
            Text(
              formatDuration(run.elapsed),
              style: TextStyle(
                  color: fc.textDisabled, fontSize: 10.5, fontFamily: 'JetBrainsMono'),
            ),
          ],
          const SizedBox(width: 6),
          Icon(
            _expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
            size: 15,
            color: fc.textDisabled,
          ),
        ],
      ),
    );
  }
}

/// Pastille d'état : anneau qui tourne pendant l'exécution, coche ou croix
/// ensuite. Toujours au même endroit, pour que l'œil suive la colonne.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.color,
    required this.running,
    required this.failed,
    this.size = 18,
  });

  final Color color;
  final bool running;
  final bool failed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: running
          ? SizedBox(
              width: size / 2,
              height: size / 2,
              child: fluent.ProgressRing(strokeWidth: 1.4, activeColor: color),
            )
          : Icon(
              failed ? fluent.FluentIcons.clear : fluent.FluentIcons.check_mark,
              size: size / 2,
              color: color,
            ),
    );
  }
}

/// Une étape : son libellé en clair, son état, et — dépliée — ce qui a
/// réellement été demandé à l'outil puis ce qu'il a répondu.
///
/// Les arguments sont montrés parce que c'est la seule façon de vérifier que
/// l'agent a bien compris : « déplacer l'axe Z » ne dit pas de combien.
class StepRow extends StatefulWidget {
  const StepRow({super.key, required this.fc, required this.step});

  final ForgeronColorPalette fc;
  final AiChatMessage step;

  @override
  State<StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<StepRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    final step = widget.step;
    final running = step.isRunningTool;
    final failed = step.toolFailed;
    final accent = running ? fc.primary : (failed ? fc.danger : fc.success);
    final label = friendlyToolLabel(step.toolName ?? step.text);
    final args = step.toolArgs;
    final result = step.toolResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fluent.HyperlinkButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: fluent.ButtonStyle(
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 7)),
            backgroundColor: WidgetStatePropertyAll(
                _expanded ? fc.surfaceHigh : Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: Row(
            children: [
              StatusDot(color: accent, running: running, failed: failed, size: 15),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: running
                    ? LiveElapsed(
                        since: step.timestamp,
                        style: TextStyle(
                            color: fc.primary,
                            fontSize: 10.5,
                            fontFamily: 'JetBrainsMono'),
                      )
                    : Text(
                        resultSummary(step.toolName ?? '', result ?? ''),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: failed ? fc.danger : fc.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (step.imageBytes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 2, 10, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                child: Image.memory(step.imageBytes!, fit: BoxFit.cover),
              ),
            ),
          ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 0, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (args != null && args.isNotEmpty)
                  _detailBlock(fc, 'DEMANDÉ', _prettyArgs(args)),
                if (result != null) ...[
                  if (args != null && args.isNotEmpty) const SizedBox(height: 6),
                  _detailBlock(fc, 'RÉPONDU', result, danger: failed),
                ],
                if (step.toolDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'durée : ${formatDuration(step.toolDuration!)}',
                      style: TextStyle(color: fc.textDisabled, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailBlock(
    ForgeronColorPalette fc,
    String title,
    String body, {
    bool danger = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fc.terminalBg,
        border: Border.all(
            color: danger ? fc.danger.withValues(alpha: .35) : fc.surfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: fc.textDisabled,
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            body,
            style: TextStyle(
              color: danger ? fc.danger : fc.textSecondary,
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Les arguments en « clé : valeur », une par ligne — lisible sans savoir
  /// lire du JSON. Une valeur très longue (un programme entier) est tronquée :
  /// elle est de toute façon consultable là où l'outil l'a écrite.
  static String _prettyArgs(Map<String, dynamic> args) {
    return args.entries.map((e) {
      var value = e.value is String ? e.value as String : jsonEncode(e.value);
      if (value.length > 400) value = '${value.substring(0, 400)}…';
      return '${e.key} : $value';
    }).join('\n');
  }
}

// ─────────────────────────────── Streaming ──────────────────────────────────

/// Réponse en cours de génération : le texte arrive mot à mot, suivi d'un
/// curseur qui clignote. Sans le curseur, une pause du modèle ressemble à une
/// réponse terminée.
class StreamingBubble extends StatefulWidget {
  const StreamingBubble({super.key, required this.fc, required this.text});

  final ForgeronColorPalette fc;
  final String text;

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: fc.textPrimary, fontSize: 13.5, height: 1.6),
                children: [
                  TextSpan(text: widget.text),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: FadeTransition(
                      opacity: _blink,
                      child: Container(
                        width: 7,
                        height: 14,
                        margin: const EdgeInsets.only(left: 2),
                        color: fc.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Séparateur de journée dans le fil — une longue discussion reprise le
/// lendemain n'a plus aucun repère sans ça.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.fc, required this.day});

  final ForgeronColorPalette fc;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final diff = today.difference(that).inDays;
    final label = switch (diff) {
      0 => 'Aujourd\'hui',
      1 => 'Hier',
      _ => '${that.day.toString().padLeft(2, '0')}/'
          '${that.month.toString().padLeft(2, '0')}/${that.year}',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: fc.surfaceBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: fc.textDisabled,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .9,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: fc.surfaceBorder)),
        ],
      ),
    );
  }
}
