import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../core/widgets/split_view.dart';

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

  static const _logLines = [
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

  static const _macros = [
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

  static const _history = [
    ('G0 Z50', '14:09:00'),
    ('M5', '14:08:50'),
    ('G0 X100 Y50 Z10', '14:06:10'),
    ('M3 S12000', '14:05:20'),
    ('G90 G21', '14:03:01'),
    ('\$H', '14:02:12'),
  ];

  @override
  Widget build(BuildContext context) {
    return ResizableSplitView(
      initialRatio: 0.5,
      left: Column(children: [
        // Terminal header
        Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: const BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
          child: const Row(children: [Icon(Icons.terminal, color: AppColors.textDisabled, size: 14), SizedBox(width: 8), Text('TERMINAL MDI / LOGS', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w900)), Spacer(), Text('BUFFER: 127/128', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))])),
        // Log
        Expanded(child: Container(color: AppColors.terminalBg, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _logLines.length, itemBuilder: (ctx, i) {
          final l = _logLines[i];
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Text(l.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
            const SizedBox(width: 12),
            SizedBox(width: 36, child: Text(l.$2, style: TextStyle(color: l.$4, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono'))),
            const SizedBox(width: 8),
            Expanded(child: Text(l.$3, style: TextStyle(color: l.$2 == '>>>' ? AppColors.primary : l.$4, fontSize: 12, fontFamily: 'JetBrains Mono'))),
          ]));
        }))),
        // Input bar
        Container(height: 64, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.surfaceBorder))),
          child: Row(children: [
            const Text('❯', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
              child: Align(alignment: Alignment.centerLeft, child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontFamily: 'JetBrains Mono'),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Saisir commande G-Code...', hintStyle: TextStyle(color: AppColors.textDisabled)),
                onSubmitted: _sendCommand,
              )))),
            const SizedBox(width: 12),
            IconButton(onPressed: () {}, icon: const Icon(Icons.history, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: () => _sendCommand(_controller.text), icon: const Icon(Icons.send, size: 14), label: const Text('ENVOYER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(minimumSize: const Size(100, 48))),
          ])),
      ]),
      right: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MACROS RAPIDES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8,
          children: _macros.map((m) => InkWell(onTap: () {
            // Very simple mapping to simulate macro sending
            if (m.$2 == 'ORIGINES') ref.read(machineRepositoryProvider).home([]);
            if (m.$2 == 'PAUSE') ref.read(machineRepositoryProvider).pause();
            if (m.$2 == 'REPRENDRE') ref.read(machineRepositoryProvider).resume();
            if (m.$2 == 'ANNULER') ref.read(machineRepositoryProvider).emergencyStop();
          }, child: Container(
            decoration: BoxDecoration(color: m.$3.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: m.$3.withValues(alpha: 0.25))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(m.$1, color: m.$3, size: 22), const SizedBox(height: 6), Text(m.$2, style: TextStyle(color: m.$3, fontSize: 9, fontWeight: FontWeight.w900))]),
          ))).toList()),
        const SizedBox(height: 24),
        const Text('HISTORIQUE COMMANDES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 8),
        for (final h in _history)
          InkWell(onTap: () {
            _controller.text = h.$1;
          }, child: Container(
            margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(4)),
            child: Row(children: [const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 12), const SizedBox(width: 6), Expanded(child: Text(h.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono'))), Text(h.$2, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono'))]),
          )),
      ])),
    );
  }
}
