import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/config_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/firmware_provider.dart';
import '../../application/providers/network_stats_provider.dart';
import '../../application/services/logger_service.dart';
import '../../core/widgets/split_view.dart';
import '../../core/widgets/responsive_layout.dart';
import '../tutorial/tutorial_keys.dart';
import 'mobile_screens.dart' show KinematicsTable;
import '../../core/i18n/app_localizations.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  static List<(String, String, Color)> _endstops(ForgeronColorPalette c) => [
    ('X', 'GPIO 34', c.axisX),
    ('Y', 'GPIO 35', c.axisY),
    ('Z', 'GPIO 32', c.axisZ),
    ('A', 'GPIO 33', c.axisA),
    ('C', 'GPIO 25', c.axisC),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final configAsync = ref.watch(configProvider);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final limSw = machineState?.limitSwitches ?? [false, false, false, false, false];
    final singularityRisk = machineState?.singularityRisk ?? 0.0;
    final temp = machineState?.coreTemp ?? 40.0;
    final fw = ref.watch(firmwareInfoProvider);
    final net = ref.watch(networkStatsProvider);

    // Couleur commune à la latence et à la jauge de qualité : grise tant qu'on
    // n'est pas connecté, pour ne pas afficher un « 0 ms » vert rassurant.
    final latColor = !net.connected
        ? fc.textDisabled
        : (net.latencyMs < 30
            ? fc.success
            : (net.latencyMs < 100 ? fc.warning : fc.error));

    final leftPanel = SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(context, 'GPIO & CAPTEURS (LIVE)'),
        SizedBox(height: 12),
        for (final e in _endstops(fc).asMap().entries)
          _endstopCard(context, e.value.$1, e.value.$2, limSw[e.key], e.value.$3),
        Row(children: [
          Expanded(child: _sensorMini(context, 'PALPEUR', 'GPIO 36',
              machineState?.probeTriggered ?? false, fc.secondary)),
          SizedBox(width: 6),
          Expanded(child: _sensorMini(context, 'E-STOP', 'GPIO 27',
              machineState?.emergencyTriggered ?? false, fc.danger)),
        ]),
        SizedBox(height: 24),
        _label(context, 'TÉLÉMÉTRIE RÉSEAU'),
        SizedBox(height: 12),
        GlassPanel(key: TutorialKeys.networkMonitor, child: Column(children: [
          Center(child: Column(children: [
            Text(tr('LATENCE'), style: TextStyle(color: fc.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(net.connected ? '${net.latencyMs}' : '—',
                style: TextStyle(color: latColor, fontSize: 48, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
            Text('ms', style: TextStyle(color: fc.textDisabled, fontSize: 12)),
          ])),
          SizedBox(height: 12),
          Row(children: [
            Text(tr('QUALITÉ'), style: TextStyle(color: fc.textDisabled, fontSize: 9)),
            SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: net.qualityPct / 100, backgroundColor: fc.surfaceBright, color: latColor, minHeight: 6),
            )),
            SizedBox(width: 8),
            Text('${net.qualityPct}%', style: TextStyle(color: latColor, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900)),
          ]),
          SizedBox(height: 12),
          for (final e in [
            ('PAQUETS TX', '${net.txCount}'),
            ('PAQUETS RX', '${net.rxCount}'),
            ('UPTIME CONN.', formatUptime(net.uptime)),
          ])
            Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Text(e.$1, style: TextStyle(color: fc.textDisabled, fontSize: 9, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(e.$2, style: TextStyle(color: fc.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono')),
            ])),
        ])),
        SizedBox(height: 24),
        _label(context, 'SANTÉ SYSTÈME'),
        SizedBox(height: 12),
        Container(
          key: TutorialKeys.performanceMetrics,
          child: GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6, children: [
            _healthCard(context, 'TEMP CPU', '${temp.toStringAsFixed(0)}°C', Icons.thermostat, fc.warning),
            // RAM / Uptime / RSSI : non rapportés par FluidNC standard → « — »
            // tant que le firmware n'envoie pas de [MSG:] custom. Afficher des
            // valeurs inventées ferait passer l'écran pour du live.
            _healthCard(context, 'USAGE RAM', '—', Icons.memory, fc.textDisabled),
            _healthCard(context, 'UPTIME', '—', Icons.schedule, fc.textDisabled),
            _healthCard(context, 'WiFi RSSI', '—', Icons.wifi, fc.textDisabled),
          ]),
        ),
        SizedBox(height: 24),
        _label(context, 'AMDEC & MAINT. PRÉVENTIVE'),
        SizedBox(height: 12),
        _AmdecRiskPanel(singularityRisk: singularityRisk, temp: temp, latencyMs: net.latencyMs),
        SizedBox(height: 12),
        _MaintenanceForecastCard(),
      ]),
    );

    final yamlPanel = Column(children: [
      Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: fc.surfaceBright, border: Border(bottom: BorderSide(color: fc.surfaceBorder))),
        child: Row(children: [
          Icon(Icons.code, color: fc.warning, size: 16),
          SizedBox(width: 8),
          Text(tr('CONFIG.YAML'), style: TextStyle(color: fc.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(width: 16),
          Flexible(child: Text(tr('Configuration Machine FluidNC'), style: TextStyle(color: fc.textDisabled, fontSize: 10), overflow: TextOverflow.ellipsis)),
          const Spacer(),
          OutlinedButton.icon(
            icon: Icon(Icons.copy_all_rounded, size: 14),
            label: Text(tr('COPIER'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: fc.surfaceBorder), minimumSize: Size(0, 32)),
            onPressed: () => _copyConfig(context, ref),
          ),
        ])),
      Expanded(child: Container(color: fc.terminalBg, child: configAsync.when(
        data: (yamlStr) {
          final lines = yamlStr.split('\n');
          return ListView.builder(padding: EdgeInsets.all(16), itemCount: lines.length, itemBuilder: (ctx, i) {
            final l = lines[i];
            final isComment = l.trimLeft().startsWith('#');
            final parts = l.split(':');
            final rest = parts.length > 1 ? parts.sublist(1).join(':') : '';
            return Padding(padding: EdgeInsets.symmetric(vertical: 1), child: Row(children: [
              SizedBox(width: 30, child: Text('${i + 1}', textAlign: TextAlign.right, style: TextStyle(color: fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono'))),
              Container(width: 1, height: 16, color: fc.surfaceBorder, margin: EdgeInsets.symmetric(horizontal: 10)),
              Expanded(child: isComment
                ? Text(l, style: TextStyle(color: fc.textDisabled, fontSize: 12, fontFamily: 'JetBrains Mono'))
                : parts.length > 1
                  ? RichText(text: TextSpan(children: [
                      TextSpan(text: '${parts[0]}:', style: TextStyle(color: fc.primary, fontSize: 12, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold)),
                      TextSpan(text: rest, style: TextStyle(color: rest.contains('"') ? fc.success : fc.warning, fontSize: 12, fontFamily: 'JetBrains Mono')),
                    ]))
                  : Text(l, style: TextStyle(color: fc.textPrimary, fontSize: 12, fontFamily: 'JetBrains Mono'))),
            ]));
          });
        },
        loading: () => Center(child: CircularProgressIndicator(color: fc.primary)),
        error: (e, st) => Center(child: Text(tr('Erreur de chargement: {}', [e]), style: TextStyle(color: fc.error))),
      ))),
    ]);

    final paramsPanel = SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(context, 'CINÉMATIQUE DES AXES'),
        SizedBox(height: 12),
        // Table éditable branchée sur le config.yaml réel de la carte. Les
        // valeurs étaient auparavant codées en dur ici et avaient dérivé de la
        // machine (160 pas/mm affichés sur X contre 264 réels).
        const KinematicsTable(),
        SizedBox(height: 24),
        _label(context, 'IDENTITÉ FIRMWARE'),
        SizedBox(height: 12),
        GlassPanel(
          titleTrailing: fw.isKnown
              ? null
              : InkWell(
                  onTap: () => ref.read(firmwareInfoProvider.notifier).requestInfo(),
                  child: Icon(Icons.refresh_rounded, size: 14, color: fc.textSecondary),
                ),
          child: Column(children: [
            for (final e in [
              ('Version', fw.version ?? (fw.isKnown ? '—' : 'en attente (\$I)…')),
              ('GRBL', fw.grblVersion ?? '—'),
              ('Carte', fw.board ?? '—'),
              ('Options', fw.options ?? '—'),
            ])
              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                Text(e.$1, style: TextStyle(color: fc.textDisabled, fontSize: 10)),
                const SizedBox(width: 12),
                Expanded(child: Text(e.$2, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fc.textPrimary, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold))),
              ])),
          ]),
        ),
        SizedBox(height: 24),
        _label(context, 'ACTIONS SYSTÈME'),
        SizedBox(height: 12),
        _actionRow(context, 'COPIER CONFIG.YAML', Icons.copy_all_rounded, fc.primary,
            () => _copyConfig(context, ref)),
        _actionRow(context, 'REDÉMARRER ESP32', Icons.power_settings_new, fc.error,
            () => _rebootEsp(context, ref)),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            icon: Icon(Icons.analytics),
            label: Text(tr('GÉNÉRER DUMP DIAGNOSTIC (JSON)'), style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(backgroundColor: fc.primary, foregroundColor: Colors.white),
            onPressed: () {
              final dump = ref.read(loggerServiceProvider.notifier).generateDiagnosticDump();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Dump diagnostic généré en console'))));
              debugPrint(dump);
            },
          ),
        ),
      ]),
    );

    final split = ResizableSplitView(
      initialRatio: 0.3,
      left: leftPanel,
      right: ResizableSplitView(
        initialRatio: 0.6,
        left: yamlPanel,
        right: paramsPanel,
      ),
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
      tablet: split,
      desktop: split,
    );
  }

  void _copyConfig(BuildContext context, WidgetRef ref) {
    final cfg = ref.read(configResultProvider).valueOrNull;
    final m = ScaffoldMessenger.of(context);
    if (cfg == null) {
      m.showSnackBar(SnackBar(content: Text(tr('Config non chargée.'))));
      return;
    }
    Clipboard.setData(ClipboardData(text: cfg.yaml));
    m.showSnackBar(SnackBar(content: Text(tr('config.yaml copié dans le presse-papiers'))));
  }

  Future<void> _rebootEsp(BuildContext context, WidgetRef ref) async {
    final fc = context.fc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text(tr('Redémarrer l\'ESP32 ?'), style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: fc.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('La liaison va être coupée : l\'app se déconnectera quelques secondes, le temps du reboot. La reconnexion est automatique.'),
              style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Annuler'), style: TextStyle(color: fc.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: fc.error, foregroundColor: Colors.white),
            child: Text(tr('Redémarrer')),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(machineRepositoryProvider).sendRaw('\$Bye\n');
    }
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: TextStyle(color: context.fc.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0));

  Widget _actionRow(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 52, padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            const Spacer(),
            Icon(Icons.chevron_right, color: context.fc.textDisabled, size: 16),
          ]),
        ),
      ),
    );
  }

  Widget _endstopCard(BuildContext context, String axis, String gpio, bool triggered, Color axisColor) {
    final fc = context.fc;
    final stateColor = triggered ? fc.error : fc.success;
    return Container(
      height: 48, margin: EdgeInsets.only(bottom: 6), padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fc.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: fc.surfaceBorder)),
      child: Row(children: [
        Container(width: 4, height: 28, decoration: BoxDecoration(color: axisColor, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: 12),
        Text(axis, style: TextStyle(color: axisColor, fontSize: 14, fontWeight: FontWeight.w900)),
        SizedBox(width: 8),
        Text(gpio, style: TextStyle(color: fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
        const Spacer(),
        Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: stateColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: stateColor.withValues(alpha: 0.3))),
          child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor, boxShadow: [BoxShadow(color: stateColor, blurRadius: 4)])), SizedBox(width: 6), Text(triggered ? 'DÉCL.' : 'OUVERT', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900))])),
      ]),
    );
  }

  Widget _sensorMini(BuildContext context, String label, String gpio, bool triggered, Color color) {
    final fc = context.fc;
    final stateColor = triggered ? fc.error : fc.success;
    return Container(
      height: 48, margin: EdgeInsets.only(bottom: 6), padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: fc.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: fc.surfaceBorder)),
      child: Row(children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(triggered ? 'DÉCL.' : 'OUVERT', style: TextStyle(color: stateColor, fontSize: 8, fontWeight: FontWeight.w900)),
        SizedBox(width: 6),
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor)),
      ]),
    );
  }

  Widget _healthCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final fc = context.fc;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: fc.surfaceBright, borderRadius: BorderRadius.circular(6), border: Border.all(color: fc.surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const Spacer(),
        Text(value, style: TextStyle(color: fc.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
        Text(label, style: TextStyle(color: fc.textDisabled, fontSize: 8, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _AmdecRiskPanel extends StatelessWidget {
  final double singularityRisk;
  final double temp;
  final int latencyMs;

  const _AmdecRiskPanel({
    required this.singularityRisk,
    required this.temp,
    required this.latencyMs,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final risks = [
      ('Gimbal Lock (A≈0°)', singularityRisk, 'Critique'),
      ('Surchauffe ESP32', (temp - 30) / 40, 'Moyen'),
      ('Latence UDP', (latencyMs / 200).clamp(0.0, 1.0), 'Faible'),
      ('Perte de Pas (Open Loop)', 0.05, 'Faible'),
    ];

    return GlassPanel(
      padding: EdgeInsets.all(12),
      child: Column(children: [
        for (final r in risks)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$1, style: TextStyle(color: fc.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(tr('Gravité : {}', [r.$3]), style: TextStyle(color: fc.textDisabled, fontSize: 8)),
                ]),
              ),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: r.$2.clamp(0.0, 1.0),
                    backgroundColor: fc.surfaceBright,
                    color: r.$2 > 0.8 ? fc.error : (r.$2 > 0.5 ? fc.warning : fc.success),
                    minHeight: 4,
                  ),
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
    final fc = context.fc;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: fc.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: fc.surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.engineering, color: fc.primary, size: 14),
          SizedBox(width: 8),
          Text(tr('PRÉVISION MAINTENANCE'), style: TextStyle(color: fc.primary, fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
        SizedBox(height: 12),
        _maintRow(context, 'Graissage Vis à Billes', 85, '12j'),
        _maintRow(context, 'Tension Courroies', 42, '45j'),
        _maintRow(context, 'Calibration Trunnion', 95, '2j'),
      ]),
    );
  }

  Widget _maintRow(BuildContext context, String label, double health, String timeLeft) {
    final fc = context.fc;
    final color = health < 20 ? fc.error : (health < 60 ? fc.warning : fc.success);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: fc.textDisabled, fontSize: 9))),
        Text(timeLeft, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        SizedBox(width: 8),
        SizedBox(width: 40, child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: LinearProgressIndicator(value: health / 100, backgroundColor: fc.surfaceBright, color: color, minHeight: 2),
        )),
      ]),
    );
  }
}
