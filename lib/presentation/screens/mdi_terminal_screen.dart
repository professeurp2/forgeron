import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _sendCommand(String gcode) {
    if (gcode.trim().isEmpty) return;
    ref.read(machineRepositoryProvider).sendGCode(gcode.trim());
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static get _logLines => [
    ('14:02:11.04', 'INFO', 'Système initialisé. Connecté à GRBL v1.1h', AppColors.secondary),
    ('14:02:12.10', '>>>', '\$H', AppColors.primary),
    ('14:02:15.80', 'ok', '', AppColors.success),
    ('14:03:01.00', '>>>', 'G90 G21', AppColors.primary),
    ('14:03:01.00', 'ok', '', AppColors.success),
    ('14:05:22.45', 'MSG', '[MSG: Vitesse broche atteinte]', AppColors.warning),
    ('14:06:10.11', '>>>', 'G0 X100 Y50 Z10', AppColors.primary),
    ('14:06:10.11', 'ok', '', AppColors.success),
    ('14:08:45.90', 'ERR', '[ERR: Limite logicielle Z min dépassée]', AppColors.error),
    ('14:08:50.00', '>>>', 'M5', AppColors.primary),
    ('14:08:50.01', 'ok', '', AppColors.success),
    ('14:09:00.00', '>>>', 'G0 Z50', AppColors.primary),
    ('14:09:00.00', 'ok', '', AppColors.success),
  ];

  static get _macros => [
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
  ];

  static get _history => [
    ('G0 Z50', '14:09:00'),
    ('M5', '14:08:50'),
    ('G0 X100 Y50 Z10', '14:06:10'),
    ('M3 S12000', '14:05:20'),
    ('G90 G21', '14:03:01'),
    ('\$H', '14:02:12'),
  ];

  @override
  Widget build(BuildContext context) {
    final terminalPanel = Column(children: [
      // Terminal header
      Container(height: 36, padding: EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [Icon(Icons.terminal, color: AppColors.textDisabled, size: 14), SizedBox(width: 8), Text('TERMINAL MDI / LOGS', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900)), Spacer(), Text('BUFFER: 127/128', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))])),
      // Log
      Expanded(key: TutorialKeys.mdiHistory, child: Container(color: AppColors.terminalBg, child: ListView.builder(padding: EdgeInsets.all(16), itemCount: _logLines.length, itemBuilder: (ctx, i) {
        final l = _logLines[i];
        return Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          Text(l.$1, style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
          SizedBox(width: 12),
          SizedBox(width: 36, child: Text(l.$2, style: TextStyle(color: l.$4, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono'))),
          SizedBox(width: 8),
          Expanded(child: Text(l.$3, style: TextStyle(color: l.$2 == '>>>' ? AppColors.primary : l.$4, fontSize: 12, fontFamily: 'JetBrains Mono'))),
        ]));
      }))),
      // Input bar
      Container(key: TutorialKeys.mdiInput, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          Text('❯', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(width: 12),
          Expanded(child: Container(height: 44, padding: EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
            child: Align(alignment: Alignment.centerLeft, child: TextField(
              controller: _controller,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontFamily: 'JetBrains Mono'),
              decoration: InputDecoration(border: InputBorder.none, hintText: 'Saisir commande...', hintStyle: TextStyle(color: AppColors.textDisabled)),
              onSubmitted: _sendCommand,
            )))),
          SizedBox(width: 12),
          IconButton(onPressed: () {}, icon: Icon(Icons.history, color: AppColors.textSecondary)),
          SizedBox(width: 8),
          ElevatedButton.icon(onPressed: () => _sendCommand(_controller.text), icon: Icon(Icons.send, size: 14), label: Text('ENVOYER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48))),
        ])),
    ]);

    final sidePanel = SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MACROS RAPIDES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      SizedBox(height: 12),
      GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8,
        children: _macros.map<Widget>((m) => InkWell(onTap: () {
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
            final latestState = ref.read(machineStateProvider).valueOrNull;
            if (latestState?.status == MachineStatus.hold) {
              repo.resume();
            } else {
              final messenger = ScaffoldMessenger.of(context);
              ref.read(streamingProvider.notifier).startStream().then((result) {
                if (!result.isValid) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur Lookahead : ${result.errorMessage} (ligne ${result.errorLine})'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              });
            }
          } else if (label == 'PAUSE') {
            repo.pause();
          } else if (label == 'ANNULER') {
            ref.read(streamingProvider.notifier).stopStream();
          }
        }, child: Container(
          decoration: BoxDecoration(color: m.$3.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: m.$3.withValues(alpha: 0.25))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(m.$1, color: m.$3, size: 22), SizedBox(height: 6), Text(m.$2, style: TextStyle(color: m.$3, fontSize: 9, fontWeight: FontWeight.w900))]),
        ))).toList()),
      SizedBox(height: 24),
      Text('HISTORIQUE COMMANDES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      SizedBox(height: 8),
      for (final h in _history)
        InkWell(onTap: () {
          _controller.text = h.$1;
        }, child: Container(
          margin: EdgeInsets.only(bottom: 4), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 12), SizedBox(width: 6), Expanded(child: Text(h.$1, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono'))), Text(h.$2, style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))]),
        )),
    ]));

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