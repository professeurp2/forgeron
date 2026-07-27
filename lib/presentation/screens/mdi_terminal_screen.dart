import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forgeron/application/services/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../domain/models/machine_state.dart';
import '../../core/widgets/split_view.dart';
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';
import '../../application/providers/di_providers.dart';

class MDITerminalScreen extends ConsumerStatefulWidget {
  const MDITerminalScreen({super.key});

  @override
  ConsumerState<MDITerminalScreen> createState() => _MDITerminalScreenState();
}

class _MDITerminalScreenState extends ConsumerState<MDITerminalScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<(String, String, String, Color)> _logLines = [];
  final List<(String, String)> _history = [];
  StreamSubscription? _trafficSub;

  @override
  void initState() {
    super.initState();
    _logLines.add((
      _formatTime(DateTime.now()),
      'INFO',
      'Terminal prêt. En attente de trafic...',
      AppColors.secondary,
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
    Color color = AppColors.secondary;

    if (msg.startsWith('TX: ')) {
      type = '>>>';
      content = msg.substring(4);
      color = AppColors.primary;
    } else if (msg.startsWith('RX: ')) {
      content = msg.substring(4);
      if (content.startsWith('ok')) {
        type = 'ok';
        color = AppColors.success;
      } else if (content.startsWith('error') || content.startsWith('ALARM')) {
        type = 'ERR';
        color = AppColors.error;
      } else if (content.startsWith('<')) {
        return; // Filtrer les trames de statut pour ne pas polluer
      } else {
        type = 'MSG';
        color = AppColors.warning;
      }
    }

    setState(() {
      _logLines.add((timeStr, type, content, color));
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
    });
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static List<(IconData, String, Color)> get _macros => [
    (Icons.home, 'ORIGINES', AppColors.primary),
    (Icons.gps_fixed, 'ZÉRO PIÈCE', AppColors.primary),
    (Icons.sensors, 'PALPAGE Z', AppColors.secondary),
    (Icons.rotate_right, 'BROCHE H', AppColors.success),
    (Icons.stop_circle, 'ARRÊT B.', AppColors.error),
    (Icons.rotate_left, 'BROCHE AH', AppColors.success),
    (Icons.water_drop, 'ARROSAGE ON', AppColors.primary),
    (Icons.water_drop_outlined, 'ARROSAGE OFF', AppColors.textDisabled),
    (Icons.air, 'SOUFFLAGE', AppColors.secondary),
    (Icons.vertical_align_top, 'Z SÉCU', AppColors.primary),
    (Icons.local_parking, 'PARKING', AppColors.textSecondary),
    (Icons.build, 'CHG OUTIL', AppColors.warning),
    (Icons.play_arrow, 'REPRENDRE', AppColors.success),
    (Icons.pause, 'PAUSE', AppColors.warning),
    (Icons.cancel, 'ANNULER', AppColors.error),
    (Icons.lock_open, 'DÉBLOQUER', AppColors.primary),
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
            color: AppColors.surfaceBright,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.terminal, color: AppColors.textDisabled, size: 14),
              SizedBox(width: 8),
              Text(
                'TERMINAL MDI / LOGS',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Text(
                'BUFFER: 127/128',
                style: TextStyle(
                  color: AppColors.textDisabled,
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
            color: AppColors.terminalBg,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _logLines.length,
              itemBuilder: (ctx, i) {
                final l = _logLines[i];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        l.$1,
                        style: TextStyle(
                          color: AppColors.textDisabled,
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
                            color: l.$4,
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
                            color: l.$2 == '>>>' ? AppColors.primary : l.$4,
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
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Row(
            children: [
              Text(
                '❯',
                style: TextStyle(
                  color: AppColors.primary,
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
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontFamily: 'JetBrains Mono',
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Saisir commande...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                      ),
                      onSubmitted: _sendCommand,
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
                icon: Icon(Icons.history, color: AppColors.textSecondary),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _sendCommand(_controller.text),
                icon: Icon(Icons.send, size: 14),
                label: Text(
                  'ENVOYER',
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
            'MACROS RAPIDES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _macros
                .map<Widget>(
                  (m) => InkWell(
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
                        repo.sendGCode('M3 S5000');
                      } else if (label == 'ARRÊT B.') {
                        repo.sendGCode('M5');
                      } else if (label == 'BROCHE AH') {
                        repo.sendGCode('M4 S5000');
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
                                    'Erreur Lookahead : ${result.errorMessage} (ligne ${result.errorLine})',
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
                      decoration: BoxDecoration(
                        color: m.$3.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: m.$3.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(m.$1, color: m.$3, size: 22),
                          SizedBox(height: 6),
                          Text(
                            m.$2,
                            style: TextStyle(
                              color: m.$3,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 24),
          Text(
            'HISTORIQUE COMMANDES',
            style: TextStyle(
              color: AppColors.textSecondary,
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textDisabled,
                      size: 12,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        h.$1,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                    Text(
                      h.$2,
                      style: TextStyle(
                        color: AppColors.textDisabled,
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
      tablet: ResizableSplitView(
        initialRatio: 0.5,
        left: terminalPanel,
        right: sidePanel,
      ),
      desktop: ResizableSplitView(
        initialRatio: 0.5,
        left: terminalPanel,
        right: sidePanel,
      ),
    );
  }
}
