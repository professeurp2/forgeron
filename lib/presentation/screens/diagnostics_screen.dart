import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/config_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../core/widgets/split_view.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  static const _endstops = [
    ('X', 'GPIO 34', false, AppColors.axisX),
    ('Y', 'GPIO 35', false, AppColors.axisY),
    ('Z', 'GPIO 32', true, AppColors.axisZ),
    ('A', 'GPIO 33', false, AppColors.axisA),
    ('C', 'GPIO 25', false, AppColors.axisC),
  ];

  static const _axisParams = [
    ('X', AppColors.axisX, '160', '5000', '250', '600'),
    ('Y', AppColors.axisY, '160', '5000', '250', '800'),
    ('Z', AppColors.axisZ, '320', '2000', '150', '200'),
    ('A', AppColors.axisA, '88.8', '3600', '100', '120'),
    ('C', AppColors.axisC, '88.8', '7200', '150', '360'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configProvider);
    final limSw = ref.watch(machineStateProvider).valueOrNull?.limitSwitches
        ?? [false, false, false, false, false];

    return ResizableSplitView(
      initialRatio: 0.3,
      // Zone A — Sensors & Health
      left: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('GPIO & SENSORS (LIVE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          for (int i = 0; i < _endstops.length; i++)
            _endstopCard(_endstops[i].$1, _endstops[i].$2, limSw[i], _endstops[i].$4),
          Row(children: [
            Expanded(child: _sensorMini('PROBE', 'GPIO 36', false, AppColors.secondary)),
            const SizedBox(width: 6),
            Expanded(child: _sensorMini('E-STOP', 'GPIO 27', false, AppColors.danger)),
          ]),
          const SizedBox(height: 24),
          const Text('NETWORK TELEMETRY', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          GlassPanel(child: Column(children: [
            const Center(child: Column(children: [
              Text('PING', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('12', style: TextStyle(color: AppColors.success, fontSize: 48, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
              Text('ms', style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
            ])),
            const SizedBox(height: 12),
            Row(children: [
              const Text('QUALITÉ', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
              const SizedBox(width: 8),
              Expanded(child: LinearProgressIndicator(value: 0.92, backgroundColor: AppColors.surfaceBright, color: AppColors.success, minHeight: 6, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              const Text('92%', style: TextStyle(color: AppColors.success, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            for (final e in [('PACKETS TX', '145,892'), ('PACKETS RX', '145,890'), ('UPTIME CONN.', '14h 22min')])
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                Text(e.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono')),
              ])),
          ])),
          const SizedBox(height: 24),
          const Text('SYSTEM HEALTH', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6, children: [
            _healthCard('CPU TEMP', '58°C', Icons.thermostat, AppColors.warning),
            _healthCard('RAM USAGE', '42%', Icons.memory, AppColors.success),
            _healthCard('UPTIME', '14h 22m', Icons.schedule, AppColors.primary),
            _healthCard('WiFi RSSI', '-64 dBm', Icons.wifi, AppColors.success),
          ]),
        ]),
      ),
      // Zone B+C — config.yaml + Axis params
      right: ResizableSplitView(
        initialRatio: 0.6,
        // Zone B — config.yaml
        left: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: const BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: Row(children: [
              const Icon(Icons.code, color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              const Text('CONFIG.YAML', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const Flexible(child: Text('FluidNC Machine Configuration', style: TextStyle(color: AppColors.textDisabled, fontSize: 10), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.surfaceBorder), minimumSize: const Size(0, 32)), child: const Text('EDIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)), child: const Text('SAVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
            ])),
          Expanded(child: Container(color: AppColors.terminalBg, child: configAsync.when(
            data: (yamlStr) {
              final lines = yamlStr.split('\n');
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: lines.length, itemBuilder: (ctx, i) {
                final l = lines[i];
                final c = l.trimLeft().startsWith('#') ? AppColors.textDisabled : AppColors.textPrimary;
                final parts = l.split(':');
                return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(children: [
                  SizedBox(width: 30, child: Text('${i + 1}', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono'))),
                  Container(width: 1, height: 16, color: AppColors.surfaceBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
                  Expanded(child: l.trimLeft().startsWith('#')
                    ? Text(l, style: const TextStyle(color: AppColors.textDisabled, fontSize: 12, fontFamily: 'JetBrains Mono'))
                    : parts.length > 1
                      ? RichText(text: TextSpan(children: [
                          TextSpan(text: '${parts[0]}:', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
                          TextSpan(text: parts.sublist(1).join(':'), style: TextStyle(color: parts.sublist(1).join(':').contains('"') ? AppColors.success : AppColors.warning, fontSize: 12, fontFamily: 'JetBrains Mono')),
                        ]))
                      : Text(l, style: TextStyle(color: c, fontSize: 12, fontFamily: 'JetBrains Mono'))),
                ]));
              });
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, st) => Center(child: Text('Error loading config: $e', style: const TextStyle(color: AppColors.error))),
          ))),
        ]),
        // Zone C — Axis params + Firmware
        right: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AXIS KINEMATICS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            GlassPanel(padding: EdgeInsets.zero, child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
                child: const Row(children: [SizedBox(width: 36, child: Text('AXIS', style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('STP/mm', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('MAX F', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('ACCEL', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('TRVL', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900)))])),
              for (final a in _axisParams)
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
                  child: Row(children: [SizedBox(width: 36, child: Text(a.$1, style: TextStyle(color: a.$2, fontSize: 12, fontWeight: FontWeight.w900))), for (final v in [a.$3, a.$4, a.$5, a.$6]) Expanded(child: Text(v, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontFamily: 'JetBrains Mono')))])),
            ])),
            const SizedBox(height: 24),
            const Text('FIRMWARE IDENTITY', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            GlassPanel(child: Column(children: [
              for (final e in [('Version', 'FluidNC v3.7.8'), ('Board', 'ESP32_WROOM_32D'), ('Flash Size', '4MB (1.2MB Free)'), ('ESP-IDF SDK', 'v4.4.4'), ('Compile Date', 'Oct 24 2023')])
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Text(e.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)), const Spacer(), Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold))])),
            ])),
            const SizedBox(height: 24),
            for (final b in [('BACKUP', Icons.download, AppColors.primary), ('RESTORE', Icons.upload, AppColors.warning), ('FLASH FIRMWARE', Icons.system_update, AppColors.danger), ('REBOOT CONTROLLER', Icons.power_settings_new, AppColors.error)])
              Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () {}, child: Container(
                height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: b.$3.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: b.$3.withValues(alpha: 0.2))),
                child: Row(children: [Icon(b.$2, color: b.$3, size: 18), const SizedBox(width: 12), Text(b.$1, style: TextStyle(color: b.$3, fontSize: 10, fontWeight: FontWeight.w900)), const Spacer(), Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 16)]),
              ))),
          ]),
        ),
      ),
    );
  }

  Widget _endstopCard(String axis, String gpio, bool triggered, Color axisColor) {
    final stateColor = triggered ? AppColors.error : AppColors.success;
    return Container(
      height: 48, margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
      child: Row(children: [
        Container(width: 4, height: 28, decoration: BoxDecoration(color: axisColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(axis, style: TextStyle(color: axisColor, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text(gpio, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stateColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: stateColor.withValues(alpha: 0.3))),
          child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor, boxShadow: [BoxShadow(color: stateColor, blurRadius: 4)])), const SizedBox(width: 6), Text(triggered ? 'TRIG' : 'OPEN', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900))])),
      ]),
    );
  }

  Widget _sensorMini(String label, String gpio, bool triggered, Color color) {
    final stateColor = triggered ? AppColors.error : AppColors.success;
    return Container(
      height: 48, margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
      child: Row(children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(triggered ? 'TRIG' : 'OPEN', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor)),
      ]),
    );
  }

  Widget _healthCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
