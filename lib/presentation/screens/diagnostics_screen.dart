import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/config_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/services/logger_service.dart';
import '../../core/widgets/split_view.dart';
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';

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

    final leftPanel = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('GPIO & CAPTEURS (LIVE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        for (int i = 0; i < _endstops.length; i++)
          _endstopCard(_endstops[i].$1, _endstops[i].$2, limSw[i], _endstops[i].$4),
        Row(children: [
          Expanded(child: _sensorMini('PALPEUR', 'GPIO 36', false, AppColors.secondary)),
          const SizedBox(width: 6),
          Expanded(child: _sensorMini('E-STOP', 'GPIO 27', false, AppColors.danger)),
        ]),
        const SizedBox(height: 24),
        const Text('TÉLÉMÉTRIE RÉSEAU', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        GlassPanel(key: TutorialKeys.networkMonitor, child: Column(children: [
          const Center(child: Column(children: [
            Text('LATENCE', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
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
          for (final e in [('PAQUETS TX', '145,892'), ('PAQUETS RX', '145,890'), ('UPTIME CONN.', '14h 22min')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Text(e.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono')),
            ])),
        ])),
        const SizedBox(height: 24),
        const Text('SANTÉ SYSTÈME', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Container(
          key: TutorialKeys.performanceMetrics,
          child: GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6, children: [
            _healthCard('TEMP CPU', '58°C', Icons.thermostat, AppColors.warning),
            _healthCard('USAGE RAM', '42%', Icons.memory, AppColors.success),
            _healthCard('UPTIME', '14h 22m', Icons.schedule, AppColors.primary),
            _healthCard('WiFi RSSI', '-64 dBm', Icons.wifi, AppColors.success),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('AMDEC & MAINT. PRÉVENTIVE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        _AmdecRiskPanel(),
        const SizedBox(height: 12),
        _MaintenanceForecastCard(),
      ]),
    );

    final yamlPanel = Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: const BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          const Icon(Icons.code, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          const Text('CONFIG.YAML', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          const Flexible(child: Text('Configuration Machine FluidNC', style: TextStyle(color: AppColors.textDisabled, fontSize: 10), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.surfaceBorder), minimumSize: const Size(0, 32)), child: const Text('EDITER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)), child: const Text('SAUVER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
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
        error: (e, st) => Center(child: Text('Erreur de chargement: $e', style: const TextStyle(color: AppColors.error))),
      ))),
    ]);

    final paramsPanel = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CINÉMATIQUE DES AXES', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        GlassPanel(padding: EdgeInsets.zero, child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(color: AppColors.surfaceBright, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: const Row(children: [SizedBox(width: 36, child: Text('AXE', style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('PAS/mm', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('AVANCE MAX', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('ACCEL', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900))), Expanded(child: Text('COURSE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled, fontSize: 8, fontWeight: FontWeight.w900)))])),
          for (final a in _axisParams)
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
              child: Row(children: [SizedBox(width: 36, child: Text(a.$1, style: TextStyle(color: a.$2, fontSize: 12, fontWeight: FontWeight.w900))), for (final v in [a.$3, a.$4, a.$5, a.$6]) Expanded(child: Text(v, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontFamily: 'JetBrains Mono')))])),
        ])),
        const SizedBox(height: 24),
        const Text('IDENTITÉ FIRMWARE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        GlassPanel(child: Column(children: [
          for (final e in [('Version', 'FluidNC v3.7.8'), ('Carte', 'ESP32_WROOM_32D'), ('Taille Flash', '4MB (1.2MB Libre)'), ('SDK ESP-IDF', 'v4.4.4'), ('Date Compilation', 'Oct 24 2023')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Text(e.$1, style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)), const Spacer(), Text(e.$2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold))])),
        ])),
        const SizedBox(height: 24),
        for (final b in [('SAUVEGARDE', Icons.download, AppColors.primary), ('RESTAURER', Icons.upload, AppColors.warning), ('FLASH FIRMWARE', Icons.system_update, AppColors.danger), ('REDÉMARRER', Icons.power_settings_new, AppColors.error)])
          Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () {}, child: Container(
            height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: b.$3.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: b.$3.withValues(alpha: 0.2))),
            child: Row(children: [Icon(b.$2, color: b.$3, size: 18), const SizedBox(width: 12), Text(b.$1, style: TextStyle(color: b.$3, fontSize: 10, fontWeight: FontWeight.w900)), const Spacer(), Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 16)]),
          ))),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.analytics),
            label: const Text('GÉNÉRER DUMP DIAGNOSTIC (JSON)', style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final dump = ref.read(loggerServiceProvider.notifier).generateDiagnosticDump();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dump diagnostic généré en console')));
              debugPrint(dump);
            },
          ),
        ),
      ]),
    );

    return ResponsiveLayout(
      mobile: SingleChildScrollView(
        child: Column(
          children: [
            leftPanel,
            const Divider(),
            SizedBox(height: 400, child: yamlPanel),
            const Divider(),
            paramsPanel,
          ],
        ),
      ),
      tablet: ResizableSplitView(
        initialRatio: 0.3,
        left: leftPanel,
        right: ResizableSplitView(
          initialRatio: 0.6,
          left: yamlPanel,
          right: paramsPanel,
        ),
      ),
      desktop: ResizableSplitView(
        initialRatio: 0.3,
        left: leftPanel,
        right: ResizableSplitView(
          initialRatio: 0.6,
          left: yamlPanel,
          right: paramsPanel,
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
          child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor, boxShadow: [BoxShadow(color: stateColor, blurRadius: 4)])), const SizedBox(width: 6), Text(triggered ? 'DÉCL.' : 'OUVERT', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900))])),
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
        Text(triggered ? 'DÉCL.' : 'OUVERT', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900)),
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

class _AmdecRiskPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final singularityRisk = state?.singularityRisk ?? 0.0;
    final temp = state?.coreTemp ?? 40.0;
    
    final risks = [
      ('Gimbal Lock (A≈0°)', singularityRisk, 'Critique'),
      ('Surchauffe ESP32', (temp - 30) / 40, 'Moyen'),
      ('Latence UDP', 0.15, 'Faible'),
      ('Perte de Pas (Open Loop)', 0.05, 'Faible'),
    ];

    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        for (final r in risks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('Gravité : ${r.$3}', style: const TextStyle(color: AppColors.textDisabled, fontSize: 8)),
                ]),
              ),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: r.$2.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceBright,
                  color: r.$2 > 0.8 ? AppColors.error : (r.$2 > 0.5 ? AppColors.warning : AppColors.success),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _MaintenanceForecastCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.engineering, color: AppColors.primary, size: 14),
          SizedBox(width: 8),
          Text('PRÉVISION MAINTENANCE', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        _maintRow('Graissage Vis à Billes', 85, '12j'),
        _maintRow('Tension Courroies', 42, '45j'),
        _maintRow('Calibration Trunnion', 95, '2j'),
      ]),
    );
  }

  Widget _maintRow(String label, double health, String timeLeft) {
    final color = health < 20 ? AppColors.error : (health < 60 ? AppColors.warning : AppColors.success);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9))),
        Text(timeLeft, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: LinearProgressIndicator(value: health / 100, backgroundColor: AppColors.surfaceBright, color: color, minHeight: 2)),
      ]),
    );
  }
}
