import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forgeron/application/services/audio_service.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../core/widgets/split_view.dart';
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';
import '../../application/providers/di_providers.dart';
import '../../core/i18n/app_localizations.dart';

class MDITerminalScreen extends ConsumerStatefulWidget {
  const MDITerminalScreen({super.key});

  @override
  ConsumerState<MDITerminalScreen> createState() => _MDITerminalScreenState();
}

class _MDITerminalScreenState extends ConsumerState<MDITerminalScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  /// (heure, type, contenu). Le type suffit : la couleur en est déduite au
  /// moment de peindre.
  ///
  /// Elle y était stockée, ce qui obligeait `initState` à lire le thème avant
  /// d'être initialisé — Flutter refuse, et TOUTE la page se remplaçait par
  /// l'écran d'erreur rouge à chaque ouverture du terminal. Au passage, une
  /// couleur figée à la réception ne suivait pas un changement de thème : les
  /// anciennes lignes restaient peintes avec l'ancienne palette.
  final List<(String, String, String)> _logLines = [];
  final List<(String, String)> _history = [];
  StreamSubscription? _trafficSub;

  /// Position dans l'historique pendant un rappel à la flèche. -1 = on est sur
  /// la ligne en cours de saisie.
  int _historyCursor = -1;

  @override
  void initState() {
    super.initState();
    _logLines.add((
      _formatTime(DateTime.now()),
      'INFO',
      'Terminal prêt. En attente de trafic...',
    ));

    Future.microtask(() {
      final repo = ref.read(machineRepositoryProvider);
      _trafficSub = repo.trafficStream.listen(_handleTraffic);
    });
  }

  void _handleTraffic(String msg) {
    if (!mounted) return;
    final timeStr = _formatTime(DateTime.now());

    String type = 'MSG';
    String content = msg;

    if (msg.startsWith('TX: ')) {
      type = '>>>';
      content = msg.substring(4);
    } else if (msg.startsWith('RX: ')) {
      content = msg.substring(4);
      if (content.startsWith('ok')) {
        type = 'ok';
      } else if (content.startsWith('error') || content.startsWith('ALARM')) {
        type = 'ERR';
      } else if (content.startsWith('<')) {
        return; // Filtrer les trames de statut pour ne pas polluer
      } else {
        type = 'MSG';
      }
    }

    setState(() {
      _logLines.add((timeStr, type, content));
      if (_logLines.length > 200) _logLines.removeAt(0);
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Couleur d'une ligne de journal, d'apres son type. Même table que le
  /// terminal mobile.
  Color _colorFor(String type) => switch (type) {
        '>>>' => context.fc.primary,
        'ok' => context.fc.success,
        'ERR' => context.fc.error,
        'MSG' => context.fc.warning,
        _ => context.fc.secondary,
      };

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}.${(d.millisecond / 10).round().toString().padLeft(2, '0')}';
  }

  void _sendCommand(String gcode) {
    if (gcode.trim().isEmpty) return;

    final cmd = gcode.trim();
    ref.read(machineRepositoryProvider).sendRaw('$cmd\n');
    ref.read(audioServiceProvider).play(SoundEffect.click);
    HapticFeedback.mediumImpact();

    final timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    setState(() {
      _history.insert(0, (cmd, timeStr));
      if (_history.length > 50) _history.removeLast();
      _controller.clear();
      _historyCursor = -1;
    });
  }

  /// Rappelle une commande précédente. [delta] = +1 pour remonter (flèche
  /// haut), -1 pour redescendre.
  ///
  /// C'est le geste d'un terminal : au poste, on renvoie une commande en
  /// remontant, pas en allant chercher une icône à la souris.
  void _recallHistory(int delta) {
    if (_history.isEmpty) return;
    final next = (_historyCursor + delta).clamp(-1, _history.length - 1);
    if (next == _historyCursor) return;
    setState(() {
      _historyCursor = next;
      _controller.text = next < 0 ? '' : _history[next].$1;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<(IconData, String, Color)> get _macros => [
    (Icons.home, 'ORIGINES', context.fc.primary),
    (Icons.gps_fixed, 'ZÉRO PIÈCE', context.fc.primary),
    (Icons.sensors, 'PALPAGE Z', context.fc.secondary),
    (Icons.rotate_right, 'BROCHE H', context.fc.success),
    (Icons.stop_circle, 'ARRÊT B.', context.fc.error),
    (Icons.rotate_left, 'BROCHE AH', context.fc.success),
    (Icons.water_drop, 'ARROSAGE ON', context.fc.primary),
    (Icons.water_drop_outlined, 'ARROSAGE OFF', context.fc.textDisabled),
    (Icons.air, 'SOUFFLAGE', context.fc.secondary),
    (Icons.vertical_align_top, 'Z SÉCU', context.fc.primary),
    (Icons.local_parking, 'PARKING', context.fc.textSecondary),
    (Icons.build, 'CHG OUTIL', context.fc.warning),
    (Icons.play_arrow, 'REPRENDRE', context.fc.success),
    (Icons.pause, 'PAUSE', context.fc.warning),
    (Icons.cancel, 'ANNULER', context.fc.error),
    (Icons.lock_open, 'DÉBLOQUER', context.fc.primary),
  ];

  @override
  Widget build(BuildContext context) {
    final terminalPanel = Column(
      children: [
        // Terminal header
        Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.fc.surfaceBright,
            border: Border(bottom: BorderSide(color: context.fc.surfaceBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.terminal, color: context.fc.textDisabled, size: 14),
              SizedBox(width: 8),
              Text(
                tr('TERMINAL MDI / LOGS'),
                style: TextStyle(
                  color: context.fc.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              // Le compteur « BUFFER: 127/128 » était écrit en dur : il
              // n'a jamais rien mesuré. À la place, la seule quantité que
              // cet écran connaisse vraiment — le nombre de lignes gardées.
              Text(
                tr(_logLines.length > 1 ? '{} LIGNES' : '{} LIGNE',
                    [_logLines.length]),
                style: TextStyle(
                  color: context.fc.textDisabled,
                  fontSize: 9,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
        // Log
        Expanded(
          key: TutorialKeys.mdiHistory,
          child: Container(
            color: context.fc.terminalBg,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _logLines.length,
              itemBuilder: (ctx, i) {
                final l = _logLines[i];
                final color = _colorFor(l.$2);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        l.$1,
                        style: TextStyle(
                          color: context.fc.textDisabled,
                          fontSize: 10,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 36,
                        child: Text(
                          l.$2,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.$3,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        // Input bar
        Container(
          key: TutorialKeys.mdiInput,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.fc.surface,
            border: Border(top: BorderSide(color: context.fc.surfaceBorder)),
          ),
          child: Row(
            children: [
              Text(
                '❯',
                style: TextStyle(
                  color: context.fc.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 44,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.fc.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.fc.surfaceBorder),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    // Entrée envoie, ↑ / ↓ rappellent l'historique. Sans ça il
                    // fallait cliquer « ENVOYER » à chaque commande, et passer
                    // par l'icône d'historique pour en rejouer une.
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        if (key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter) {
                          _sendCommand(_controller.text);
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowUp) {
                          _recallHistory(1);
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowDown) {
                          _recallHistory(-1);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: TextStyle(
                          color: context.fc.textPrimary,
                          fontSize: 14,
                          fontFamily: 'JetBrains Mono',
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: tr('Saisir commande…   ( ↑ rappelle )'),
                          hintStyle: TextStyle(color: context.fc.textDisabled),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendCommand,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  if (_history.isNotEmpty) {
                    _controller.text = _history.first.$1;
                  }
                },
                icon: Icon(Icons.history, color: context.fc.textSecondary),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _sendCommand(_controller.text),
                icon: Icon(Icons.send, size: 14),
                label: Text(
                  tr('ENVOYER'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ),
      ],
    );

    final sidePanel = SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('MACROS RAPIDES'),
            style: TextStyle(
              color: context.fc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: 12),
          // Boutons de largeur fixe, disposés en flux : le panneau faisait
          // 3 colonnes de tuiles carrées, soit des pavés de 200 dp de côté qui
          // occupaient la moitié de l'écran pour douze raccourcis. Ici la
          // rangée se remplit selon la largeur disponible et le terminal — la
          // raison d'être de la page — garde la place.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _macros
                .map<Widget>(
                  (m) => SizedBox(
                    width: 132,
                    height: 34,
                    child: InkWell(
                    onTap: () {
                      final label = m.$2;
                      final repo = ref.read(machineRepositoryProvider);

                      if (label == 'ORIGINES') {
                        repo.home([]);
                      } else if (label == 'ZÉRO PIÈCE') {
                        repo.sendGCode('G92 X0 Y0 Z0 A0 C0');
                      } else if (label == 'PALPAGE Z') {
                        repo.sendGCode('G38.2 Z-50 F100');
                      } else if (label == 'BROCHE H') {
                        // S1000 = 100 % de la speed_map FluidNC : la broche
                        // est un relais tout-ou-rien, pas une broche à régime
                        // variable. S5000 affichait un régime imaginaire.
                        repo.sendGCode('M3 S1000');
                      } else if (label == 'ARRÊT B.') {
                        repo.sendGCode('M5');
                      } else if (label == 'BROCHE AH') {
                        repo.sendGCode('M4 S1000');
                      } else if (label == 'ARROSAGE ON') {
                        repo.sendGCode('M8');
                      } else if (label == 'ARROSAGE OFF') {
                        repo.sendGCode('M9');
                      } else if (label == 'SOUFFLAGE') {
                        repo.sendGCode('M7');
                      } else if (label == 'Z SÉCU') {
                        repo.sendGCode('G0 Z50');
                      } else if (label == 'PARKING') {
                        repo.sendGCode('G28');
                      } else if (label == 'CHG OUTIL') {
                        repo.sendGCode('M6 T1');
                      } else if (label == 'REPRENDRE') {
                        final latestState = ref
                            .read(machineStateProvider)
                            .valueOrNull;
                        final audio = ref.read(audioServiceProvider);
                        if (latestState?.status == MachineStatus.hold) {
                          repo.resume();
                          audio.play(SoundEffect.click);
                        } else {
                          final messenger = ScaffoldMessenger.of(context);
                          ref.read(streamingProvider.notifier).startStream().then((
                            result,
                          ) {
                            if (!result.isValid) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr('Erreur Lookahead : {} (ligne {})', [result.errorMessage, result.errorLine]),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              audio.play(SoundEffect.alert);
                            } else {
                              audio.play(SoundEffect.click);
                            }
                          });
                        }
                      } else if (label == 'PAUSE') {
                        repo.pause();
                      } else if (label == 'ANNULER') {
                        ref.read(streamingProvider.notifier).stopStream();
                      } else if (label == 'DÉBLOQUER') {
                        repo.sendRaw('\$X\n');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: m.$3.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: m.$3.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(m.$1, color: m.$3, size: 14),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              m.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: m.$3,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 24),
          Text(
            tr('HISTORIQUE COMMANDES'),
            style: TextStyle(
              color: context.fc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: 8),
          for (final h in _history)
            InkWell(
              onTap: () {
                _controller.text = h.$1;
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.fc.surfaceBright,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      color: context.fc.textDisabled,
                      size: 12,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        h.$1,
                        style: TextStyle(
                          color: context.fc.textPrimary,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                    Text(
                      h.$2,
                      style: TextStyle(
                        color: context.fc.textDisabled,
                        fontSize: 9,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return ResponsiveLayout(
      mobile: Column(
        children: [
          Expanded(flex: 3, child: terminalPanel),
          Divider(height: 1),
          Expanded(flex: 2, child: sidePanel),
        ],
      ),
      // Le terminal est la page ; les macros l'accompagnent. À 50 / 50 elles
      // lui prenaient autant de place qu'à lui, alors qu'elles n'ont besoin
      // que de la largeur de deux boutons.
      tablet: ResizableSplitView(
        initialRatio: 0.62,
        left: terminalPanel,
        right: sidePanel,
      ),
      desktop: ResizableSplitView(
        initialRatio: 0.68,
        left: terminalPanel,
        right: sidePanel,
      ),
    );
  }
}
