import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/split_view.dart';
import '../../application/providers/machine_provider.dart';

class ToolTableScreen extends ConsumerStatefulWidget {
  const ToolTableScreen({super.key});
  @override
  ConsumerState<ToolTableScreen> createState() => _ToolTableScreenState();
}

class _ToolTableScreenState extends ConsumerState<ToolTableScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTool = 0;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Données outils statiques (table de référence locale)
  // En production, ces données viendraient d'un fichier tool.tbl ou de la config FluidNC
  static const _tools = [
    ('T1', 'FORET CARBURE Ø12', 120.00, 12.00, AppColors.success, 'OK'),
    ('T2', 'FRAISE 2 TAILLES Ø20', 85.50, 20.00, AppColors.success, 'OK'),
    ('T3', 'FRAISE HÉMISPHÉRIQUE Ø6', 65.02, 6.00, AppColors.success, 'OK'),
    ('T4', 'FORET CENTRE D3', 45.00, 3.00, AppColors.success, 'OK'),
    ('T5', 'TARAUDEUR M8', 70.00, 8.00, AppColors.warning, 'USURE: 85%'),
    ('T6', 'FRAISE EB Ø25', 90.00, 25.00, AppColors.success, 'OK'),
    ('T7', 'ALÉSOIR H7 Ø10', 110.00, 10.00, AppColors.success, 'OK'),
    ('T8', 'GRAVEUR V-BIT 60°', 30.00, 6.00, AppColors.success, 'OK'),
    ('T9', 'FRAISE EB Ø16', 75.00, 16.00, AppColors.error, 'BRIS DÉTECTÉ'),
    ('T10', 'FRAISE RAVAGEUSE Ø12', 80.00, 12.00, AppColors.success, 'OK'),
    ('T11', 'FRAISE TORIQUE R2 Ø8', 60.00, 8.00, AppColors.success, 'OK'),
    ('T12', 'PALPEUR 3D RENISHAW', 50.00, 4.00, AppColors.info, 'CALIBRÉ'),
  ];

  @override
  Widget build(BuildContext context) {
    // Outil actif depuis FluidNC (en temps réel)
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final activeToolNum = machineState?.activeToolNum ?? 0;
    final activeWCS = machineState?.activeWCS ?? 'G54';

    return ResizableSplitView(
      initialRatio: 0.35,
      left: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
          child: Row(children: [
            const Text('MAGASIN D\'OUTILS',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0)),
            const Spacer(),
            // Outil actif depuis la machine
            if (activeToolNum > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.build, color: AppColors.success, size: 10),
                  const SizedBox(width: 4),
                  Text('ACTIF: T$activeToolNum',
                      style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'JetBrains Mono')),
                ]),
              ),
            const SizedBox(width: 8),
            Text('${_tools.length} / 24',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w900)),
          ]),
        ),
        // Recherche
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher T# ou Nom...',
              hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: AppColors.textDisabled),
              border: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surfaceBorder)),
              filled: true,
              fillColor: AppColors.surfaceBright,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Liste des outils
        Expanded(
          child: ListView.builder(
            itemCount: _tools.length,
            itemBuilder: (ctx, i) {
              final t = _tools[i];
              final sel = i == _selectedTool;
              // Outil actif sur machine (via FluidNC T#)
              final toolNum = int.tryParse(t.$1.replaceAll('T', '')) ?? -1;
              final isActiveOnMachine = toolNum == activeToolNum && activeToolNum > 0;

              return InkWell(
                onTap: () => setState(() => _selectedTool = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                    border: Border(
                      bottom: const BorderSide(color: AppColors.surfaceBorder),
                      left: BorderSide(
                          color: sel ? AppColors.primary : Colors.transparent,
                          width: 3),
                    ),
                  ),
                  child: Row(children: [
                    // Badge T#
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActiveOnMachine
                            ? AppColors.success.withValues(alpha: 0.2)
                            : (sel
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.surfaceBright),
                        borderRadius: BorderRadius.circular(4),
                        border: isActiveOnMachine
                            ? Border.all(color: AppColors.success, width: 1.5)
                            : null,
                      ),
                      child: Text(t.$1,
                          style: TextStyle(
                              color: isActiveOnMachine
                                  ? AppColors.success
                                  : (sel
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.$2,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          'L:${t.$3.toStringAsFixed(2)}  D:${t.$4.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: AppColors.textDisabled,
                              fontSize: 9,
                              fontFamily: 'JetBrains Mono'),
                        ),
                      ]),
                    ),
                    // Indicateur état
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.$5,
                            boxShadow: [BoxShadow(color: t.$5, blurRadius: 4)])),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
      // ── Panneau détail ──────────────────────────────────────────────────────
      right: _toolDetail(activeToolNum, activeWCS),
    );
  }

  Widget _toolDetail(int activeToolNum, String activeWCS) {
    final t = _tools[_selectedTool];
    final toolNum = int.tryParse(t.$1.replaceAll('T', '')) ?? -1;
    final isActiveOnMachine = toolNum == activeToolNum && activeToolNum > 0;

    return Column(children: [
      // Header outil
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActiveOnMachine
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: isActiveOnMachine
                  ? Border.all(color: AppColors.success, width: 2)
                  : null,
            ),
            child: Text(t.$1,
                style: TextStyle(
                    color: isActiveOnMachine ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    fontFamily: 'JetBrains Mono')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.$5.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('● ${t.$6}',
                      style: TextStyle(color: t.$5, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                if (isActiveOnMachine) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Text('▶ EN BROCHE',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
            ]),
          ),
          // Commandes rapides
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Appel outil T+M6
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 32)),
              icon: const Icon(Icons.build, size: 12, color: Colors.white),
              label: Text('APPELER ${t.$1}  (M6)',
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
              onPressed: () => _callTool(toolNum),
            ),
            const SizedBox(height: 6),
            // G43 offset longueur
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  minimumSize: const Size(0, 32)),
              icon: const Icon(Icons.straighten, size: 12, color: AppColors.secondary),
              label: Text('G43 H$toolNum  (Offset L)',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary)),
              onPressed: () => _applyLengthOffset(toolNum),
            ),
          ]),
        ]),
      ),
      // Tabs
      Container(
        decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textDisabled,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.straighten, size: 14), text: 'GÉOMÉTRIE'),
            Tab(icon: Icon(Icons.tune, size: 14), text: 'USURE / CORRECTEURS'),
            Tab(icon: Icon(Icons.timer, size: 14), text: 'DURÉE DE VIE'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [_geomTab(t), _usureTab(), _vieTab()],
        ),
      ),
    ]);
  }

  // ── Appel outil (T# M6) ───────────────────────────────────────────────────
  void _callTool(int toolNum) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Appel outil T$toolNum',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.build, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text('Envoyer la commande de changement d\'outil T$toolNum M6 ?',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('⚠ La machine va effectuer un changement d\'outil.',
              style: TextStyle(color: AppColors.warning, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              ref.read(machineRepositoryProvider).sendGCode('T$toolNum M6');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.primary,
                content: Text('▶ T$toolNum M6 envoyé'),
              ));
            },
            child: Text('APPELER T$toolNum',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Appliquer offset longueur G43 H# ─────────────────────────────────────
  void _applyLengthOffset(int toolNum) {
    ref.read(machineRepositoryProvider).sendGCode('G43 H$toolNum');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.secondary,
      content: Text('✓ G43 H$toolNum appliqué (offset longueur outil)'),
    ));
  }

  // ── Onglets détail ────────────────────────────────────────────────────────
  Widget _geomTab((String, String, double, double, Color, String) t) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PARAMÈTRES PHYSIQUES',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _paramCard('LONGUEUR (L)', t.$3.toStringAsFixed(3), 'mm')),
          const SizedBox(width: 16),
          Expanded(child: _paramCard('DIAMÈTRE (D)', t.$4.toStringAsFixed(3), 'mm')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _paramCard('RAYON (R)', (t.$4 / 2).toStringAsFixed(3), 'mm')),
          const SizedBox(width: 16),
          Expanded(child: _paramCard('ANGLE COUPE', '30', '°')),
        ]),
        const SizedBox(height: 24),
        const Text('PARAMÈTRES DE COUPE DÉFAUT',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _paramCard('AVANCE (F)', '1200', 'mm/min')),
          const SizedBox(width: 16),
          Expanded(child: _paramCard('BROCHE (S)', '18000', 'RPM')),
        ]),
      ]),
    );
  }

  Widget _paramCard(String label, String value, String unit) {
    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ),
            ),
            const SizedBox(width: 6),
            Text(unit,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 10)),
          ],
        ),
      ]),
    );
  }

  Widget _usureTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'RTCP ACTIF — Les correcteurs d\'usure impactent directement le calcul RTCP 5 axes.',
                style: TextStyle(color: AppColors.warning, fontSize: 10),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _paramCard('OFFSET Z', '-0.015', 'mm')),
          const SizedBox(width: 16),
          Expanded(child: _paramCard('OFFSET R', '0.008', 'mm')),
        ]),
        const SizedBox(height: 24),
        const Text('COMMANDES G-CODE CORRECTEURS',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2)),
        const SizedBox(height: 12),
        for (final cmd in ['G43.1 Z-0.015', 'G49 (annuler offsets)'])
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.surfaceBright,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.surfaceBorder)),
            child: Row(children: [
              Text(cmd,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontFamily: 'JetBrains Mono')),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary, size: 16),
                tooltip: 'Envoyer',
                onPressed: () =>
                    ref.read(machineRepositoryProvider).sendGCode(cmd.split(' (').first),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _vieTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(alignment: Alignment.center, children: [
              const CircularProgressIndicator(
                  value: 0.68,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceBright,
                  color: AppColors.success),
              const Text('68%',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ]),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in [
                ('TEMPS TOTAL', '04h 22min'),
                ('PIÈCES USINÉES', '47'),
                ('VIE RESTANTE', '~02h 08min'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Text(e.$1,
                        style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text(e.$2,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}
