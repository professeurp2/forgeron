import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/providers/ai_agent_settings_provider.dart';
import '../../application/providers/ai_model_provider.dart';
import '../../application/providers/ai_usage_provider.dart';
import '../../application/providers/backoffice_provider.dart';
import '../../application/providers/firmware_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/network_stats_provider.dart';
import '../../application/services/chat_relay.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/machine_state.dart';

/// Backoffice : la supervision de l'ensemble du logiciel en un écran.
///
/// Trois questions, trois panneaux :
/// - **Journal** — que s'est-il passé, dans l'ordre, et qui l'a fait ? Tous
///   les événements du bus (agent IA, relais PC ↔ téléphone, carte FluidNC,
///   garde-fous, veilleur), filtrables par source, gravité et texte.
/// - **Chaînes IA → carte** — pour chaque appel d'outil : ce que le modèle a
///   demandé, qui a confirmé (PC ou téléphone), ce qui est réellement parti
///   vers la carte, et ce que la carte a répondu, avec les latences.
/// - **Santé** — quel modèle sert, avec quels réglages, le bilan du journal
///   des tours (toutes sessions), l'état du relais et de la liaison machine.
///
/// Rien ici n'est estimé : chaque chiffre vient d'un événement enregistré, et
/// une valeur absente s'affiche « — ».
class BackofficeScreen extends ConsumerStatefulWidget {
  const BackofficeScreen({super.key, this.standalone = false});

  /// Vrai quand l'écran est poussé seul (mobile) : il porte alors sa barre.
  final bool standalone;

  @override
  ConsumerState<BackofficeScreen> createState() => _BackofficeScreenState();
}

class _BackofficeScreenState extends ConsumerState<BackofficeScreen> {
  final Set<BackofficeSource> _sources = {};
  bool _problemsOnly = false;
  String _query = '';
  int? _expandedSeq;
  String? _selectedCall;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<BackofficeEvent> _filtered(List<BackofficeEvent> all) {
    final q = _query.trim().toLowerCase();
    return [
      for (final e in all.reversed)
        if ((_sources.isEmpty || _sources.contains(e.source)) &&
            (!_problemsOnly || e.isProblem) &&
            (_selectedCall == null || e.callId == _selectedCall) &&
            (q.isEmpty ||
                e.summary.toLowerCase().contains(q) ||
                e.kind.contains(q) ||
                (e.callId?.toLowerCase().contains(q) ?? false)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final body = LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1100;
      // Poussé seul (mobile), la barre de l'écran porte déjà le titre et
      // les actions : pas de second en-tête.
      final header = widget.standalone
          ? const SizedBox(height: 12)
          : _Header(onExport: _export, onClear: _clear);
      final kpis = const _KpiStrip();
      final journal = _JournalPanel(
        sources: _sources,
        problemsOnly: _problemsOnly,
        search: _search,
        selectedCall: _selectedCall,
        expandedSeq: _expandedSeq,
        filter: _filtered,
        onSourceToggle: (s) => setState(() => _sources.contains(s) ? _sources.remove(s) : _sources.add(s)),
        onProblemsToggle: () => setState(() => _problemsOnly = !_problemsOnly),
        onQuery: (q) => setState(() => _query = q),
        onExpand: (seq) => setState(() => _expandedSeq = _expandedSeq == seq ? null : seq),
        onSelectCall: (id) => setState(() => _selectedCall = _selectedCall == id ? null : id),
      );
      final chains = _ChainsPanel(
        selectedCall: _selectedCall,
        onSelectCall: (id) => setState(() => _selectedCall = _selectedCall == id ? null : id),
      );
      const health = _HealthPanel();

      if (wide) {
        return Column(children: [
          header,
          kpis,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 5, child: journal),
                const SizedBox(width: 16),
                SizedBox(
                  width: 440,
                  child: Column(children: [
                    Expanded(flex: 3, child: chains),
                    const SizedBox(height: 16),
                    const Expanded(flex: 2, child: health),
                  ]),
                ),
              ]),
            ),
          ),
        ]);
      }
      return DefaultTabController(
        length: 3,
        child: Column(children: [
          header,
          kpis,
          TabBar(
            labelColor: fc.primary,
            unselectedLabelColor: fc.textSecondary,
            indicatorColor: fc.primary,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
            tabs: [
              Tab(text: tr('JOURNAL')),
              Tab(text: tr('IA → CARTE')),
              Tab(text: tr('SANTÉ')),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TabBarView(children: [journal, chains, health]),
            ),
          ),
        ]),
      );
    });

    if (!widget.standalone) return Container(color: fc.background, child: body);
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        foregroundColor: fc.textPrimary,
        elevation: 0,
        title: Text(tr('BACKOFFICE'),
            style: TextStyle(color: fc.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: tr('Exporter le journal'),
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: tr('Vider le journal'),
            onPressed: _clear,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bus = ref.read(backofficeBusProvider.notifier);
    final stats = ref.read(backofficeStatsProvider);
    final json = const JsonEncoder.withIndent('  ')
        .convert(bus.exportJson(extra: {'statistiques': stats.toJson()}));
    String? path;
    try {
      final dir = await getApplicationSupportDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final f = File('${dir.path}${Platform.pathSeparator}backoffice_export_$stamp.json');
      await f.writeAsString(json, flush: true);
      path = f.path;
    } catch (_) {
      path = null; // le presse-papiers reste
    }
    await Clipboard.setData(ClipboardData(text: json));
    bus.emit(
      source: BackofficeSource.systeme,
      kind: 'systeme.export',
      summary: path == null
          ? 'Journal copié dans le presse-papiers (écriture sur disque impossible)'
          : 'Journal exporté : $path',
      details: {'fichier': ?path, 'evenements': stats.evenements},
    );
    messenger?.showSnackBar(SnackBar(
      content: Text(path == null
          ? tr('Journal copié dans le presse-papiers.')
          : tr('Journal exporté dans {} (et copié dans le presse-papiers).', [path])),
    ));
  }

  Future<void> _clear() async {
    final fc = context.fc;
    final wipe = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text(tr('Vider le journal du backoffice ?'), style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Text(
          tr('La mémoire est vidée dans tous les cas. Faut-il aussi effacer les fichiers sur le disque ? Cette suppression est définitive.'),
          style: TextStyle(color: fc.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Mémoire seulement'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: fc.danger, foregroundColor: Colors.white),
            child: Text(tr('Mémoire et disque')),
          ),
        ],
      ),
    );
    if (wipe == null) return;
    await ref.read(backofficeBusProvider.notifier).clear(wipeDisk: wipe);
    if (mounted) setState(() => _selectedCall = null);
  }
}

// ───────────────────────────── En-tête & KPI ──────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.onExport, required this.onClear});
  final Future<void> Function() onExport;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final count = ref.watch(backofficeBusProvider.select((l) => l.length));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Icon(Icons.admin_panel_settings_outlined, color: fc.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('BACKOFFICE'),
                style: TextStyle(color: fc.textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text(tr('Supervision : agent IA · relais PC ↔ téléphone · carte FluidNC — {} événement(s)', [count]),
                style: TextStyle(color: fc.textDisabled, fontSize: 10), overflow: TextOverflow.ellipsis),
          ]),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share_rounded, size: 14),
          label: Text(tr('EXPORTER'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: fc.surfaceBorder), minimumSize: const Size(0, 32)),
          onPressed: onExport,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep_outlined, size: 14),
          label: Text(tr('VIDER'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: fc.surfaceBorder), minimumSize: const Size(0, 32)),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _KpiStrip extends ConsumerWidget {
  const _KpiStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final s = ref.watch(backofficeStatsProvider);
    final relay = ref.watch(chatRelayHostProvider);
    final machine = ref.watch(machineStateProvider).valueOrNull;
    String ms(int? v) => v == null ? '—' : '$v ms';

    final cards = <Widget>[
      _Kpi(
        label: tr('TOURS IA'),
        value: '${s.toursIa}',
        sub: tr('ok {} · erreurs {} · vides {} · images {} · p50 {}',
            [s.toursOk, s.toursErreur, s.toursVides, s.toursImages, ms(s.latenceIaP50Ms)]),
        color: fc.primary,
        icon: Icons.smart_toy_outlined,
      ),
      _Kpi(
        label: tr('APPELS D\'OUTILS'),
        value: '${s.appelsOutils}',
        sub: tr('échecs {} · garde-fous {}', [s.outilsEchoues, s.gardes]),
        color: s.gardes > 0 ? fc.warning : fc.primary,
        icon: Icons.build_circle_outlined,
      ),
      _Kpi(
        label: tr('IA → CARTE'),
        value: '${s.commandesIa}',
        sub: tr('ok {} · erreurs {} · p50 {} · opérateur {}', [s.reponsesOk, s.reponsesErreur, ms(s.latenceCarteP50Ms), s.commandesOperateur]),
        color: s.reponsesErreur > 0 ? fc.warning : fc.info,
        icon: Icons.memory_outlined,
      ),
      _Kpi(
        label: tr('CONFIRMATIONS'),
        value: '${s.confirmationsLocal + s.confirmationsRelais}',
        sub: tr('ici {} · téléphone {} · refus {} · en attente {}', [s.confirmationsLocal, s.confirmationsRelais, s.refus, s.confirmationsAttendues]),
        color: fc.secondary,
        icon: Icons.how_to_reg_outlined,
      ),
      _Kpi(
        label: tr('RELAIS'),
        value: relay.running ? '${relay.clients}' : '—',
        sub: relay.running
            ? tr('actif · liaisons {} · refus {} · messages {}', [s.relaisLiaisons, s.relaisRefus, s.relaisMessages])
            : tr('arrêté · liaisons {} · refus {}', [s.relaisLiaisons, s.relaisRefus]),
        color: relay.running ? fc.success : fc.textDisabled,
        icon: Icons.phonelink_ring_outlined,
      ),
      _Kpi(
        label: tr('MACHINE'),
        value: machine == null ? '—' : machine.status.name.toUpperCase(),
        sub: tr('alarmes {} · blocages {} · urgences {}{}', [
          s.alarmes,
          s.blocages,
          s.urgences,
          s.urgencesNonTransmises > 0 ? ' · NON TRANSMISES ${s.urgencesNonTransmises}' : '',
        ]),
        color: machine == null || machine.status == MachineStatus.offline
            ? fc.textDisabled
            : machine.status == MachineStatus.alarm
                ? fc.danger
                : fc.success,
        icon: Icons.precision_manufacturing_outlined,
      ),
      _Kpi(
        label: tr('PROBLÈMES'),
        value: '${s.problemes}',
        sub: tr('veilleur {} · diagnostics IA {}', [s.veilleurAlertes, s.veilleurReponsesIa]),
        color: s.problemes > 0 ? fc.danger : fc.success,
        icon: Icons.report_gmailerrorred_outlined,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(builder: (context, c) {
        // Étroit (téléphone) : une seule rangée qui défile, sinon quatre
        // rangées de cartes mangeaient l'écran et le journal débordait.
        if (c.maxWidth < 1100) {
          return SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => SizedBox(width: 180, child: cards[i]),
            ),
          );
        }
        // Rangées équilibrées : 7 cartes sur 1 600 px donnaient six cartes
        // et une orpheline ; on répartit (4 + 3) plutôt que (6 + 1).
        var perRow = (c.maxWidth / 190).floor().clamp(2, cards.length);
        final rows = (cards.length / perRow).ceil();
        perRow = (cards.length / rows).ceil();
        final w = (c.maxWidth - (perRow - 1) * 8) / perRow;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in cards) SizedBox(width: w, child: k),
        ]);
      }),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.sub, required this.color, required this.icon});
  final String label, value, sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fc.textDisabled, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ),
        ]),
        const SizedBox(height: 4),
        AnimatedSwapText(value,
            maxLines: 1,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono', height: 1.1)),
        const SizedBox(height: 2),
        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fc.textSecondary, fontSize: 9)),
      ]),
    );
  }
}

// ───────────────────────────────── Journal ────────────────────────────────────

Color sourceColor(ForgeronColorPalette fc, BackofficeSource s) => switch (s) {
      BackofficeSource.ia => fc.primary,
      BackofficeSource.relais => fc.secondary,
      BackofficeSource.firmware => fc.info,
      BackofficeSource.garde => fc.warning,
      BackofficeSource.veilleur => fc.danger,
      BackofficeSource.systeme => fc.textDisabled,
    };

String sourceLabel(BackofficeSource s) => switch (s) {
      BackofficeSource.ia => 'IA',
      BackofficeSource.relais => 'RELAIS',
      BackofficeSource.firmware => 'CARTE',
      BackofficeSource.garde => 'GARDE',
      BackofficeSource.veilleur => 'VEILLE',
      BackofficeSource.systeme => 'SYS',
    };

Color severityColor(ForgeronColorPalette fc, BackofficeSeverity s) => switch (s) {
      BackofficeSeverity.info => fc.textDisabled,
      BackofficeSeverity.notice => fc.info,
      BackofficeSeverity.warning => fc.warning,
      BackofficeSeverity.critical => fc.danger,
    };

String originLabel(String? o) => switch (o) {
      BackofficeOrigin.local => 'ici',
      BackofficeOrigin.relais => 'téléphone',
      BackofficeOrigin.lexique => 'lexique',
      BackofficeOrigin.modele => 'modèle',
      BackofficeOrigin.operateur => 'opérateur',
      BackofficeOrigin.veilleur => 'veilleur',
      _ => o ?? '',
    };

String _clock(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
}

class _JournalPanel extends ConsumerWidget {
  const _JournalPanel({
    required this.sources,
    required this.problemsOnly,
    required this.search,
    required this.selectedCall,
    required this.expandedSeq,
    required this.filter,
    required this.onSourceToggle,
    required this.onProblemsToggle,
    required this.onQuery,
    required this.onExpand,
    required this.onSelectCall,
  });

  final Set<BackofficeSource> sources;
  final bool problemsOnly;
  final TextEditingController search;
  final String? selectedCall;
  final int? expandedSeq;
  final List<BackofficeEvent> Function(List<BackofficeEvent>) filter;
  final void Function(BackofficeSource) onSourceToggle;
  final VoidCallback onProblemsToggle;
  final ValueChanged<String> onQuery;
  final ValueChanged<int> onExpand;
  final ValueChanged<String> onSelectCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final all = ref.watch(backofficeBusProvider);
    final counts = <BackofficeSource, int>{};
    for (final e in all) {
      counts[e.source] = (counts[e.source] ?? 0) + 1;
    }
    final shown = filter(all);

    return GlassPanel(
      padding: EdgeInsets.zero,
      expand: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: LayoutBuilder(builder: (context, c) {
            final chips = <Widget>[
              for (final s in BackofficeSource.values)
                _Chip(
                  label: '${sourceLabel(s)} ${counts[s] ?? 0}',
                  color: sourceColor(fc, s),
                  selected: sources.contains(s),
                  onTap: () => onSourceToggle(s),
                ),
              _Chip(
                label: tr('PROBLÈMES'),
                color: fc.danger,
                selected: problemsOnly,
                onTap: onProblemsToggle,
              ),
              if (selectedCall != null)
                _Chip(
                  label: tr('chaîne {} ✕', [selectedCall]),
                  color: fc.primary,
                  selected: true,
                  onTap: () => onSelectCall(selectedCall!),
                ),
              SizedBox(
                width: 200,
                height: 30,
                child: TextField(
                  controller: search,
                  onChanged: onQuery,
                  style: TextStyle(color: fc.textPrimary, fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: tr('filtrer…'),
                    hintStyle: TextStyle(color: fc.textDisabled, fontSize: 11),
                    prefixIcon: Icon(Icons.search, size: 14, color: fc.textDisabled),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: fc.surfaceBorder), borderRadius: BorderRadius.circular(6)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: fc.primary), borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ];
            // Étroit : une seule ligne de filtres qui défile, pour laisser
            // la hauteur au journal (téléphone en paysage : 360 px de haut).
            if (c.maxWidth < 760) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final w in chips) ...[w, const SizedBox(width: 6)],
                ]),
              );
            }
            return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: chips);
          }),
        ),
        Container(height: 1, color: fc.surfaceBorder),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    all.isEmpty
                        ? tr('Aucun événement pour l\'instant : parle à l\'agent, relie le téléphone ou connecte la carte.')
                        : tr('Aucun événement ne correspond au filtre.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fc.textDisabled, fontSize: 11),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: shown.length,
                  // Chaque ligne entre en fondu une fois (clé = numéro) :
                  // un nouvel événement se voit arriver.
                  itemBuilder: (ctx, i) => AppearIn(
                    key: ValueKey(shown[i].seq),
                    child: _EventRow(
                      event: shown[i],
                      expanded: expandedSeq == shown[i].seq,
                      onTap: () => onExpand(shown[i].seq),
                      onSelectCall: onSelectCall,
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.selected, required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : fc.surfaceBright,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : fc.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? color : fc.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.expanded, required this.onTap, required this.onSelectCall});
  final BackofficeEvent event;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<String> onSelectCall;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final e = event;
    final sc = sourceColor(fc, e.source);
    final sev = severityColor(fc, e.severity);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: expanded ? fc.surfaceBright : null,
          border: Border(bottom: BorderSide(color: fc.surfaceBorderDim)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_clock(e.time),
                style: TextStyle(color: fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: sev, shape: BoxShape.circle, boxShadow: [
                if (e.isProblem) BoxShadow(color: sev, blurRadius: 5),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(sourceLabel(e.source),
                  style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
            Expanded(
              child: Text(e.summary,
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                      color: e.isProblem ? sev : fc.textPrimary,
                      fontSize: 11,
                      fontWeight: e.severity == BackofficeSeverity.critical ? FontWeight.w800 : FontWeight.w500)),
            ),
            if (e.origin != null) ...[
              const SizedBox(width: 8),
              Text(originLabel(e.origin),
                  style: TextStyle(color: fc.textDisabled, fontSize: 9, fontStyle: FontStyle.italic)),
            ],
          ]),
          if (expanded) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 86),
              child: _Details(event: e, onSelectCall: onSelectCall),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.event, required this.onSelectCall});
  final BackofficeEvent event;
  final ValueChanged<String> onSelectCall;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final e = event;
    TextStyle k = TextStyle(color: fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono');
    TextStyle v = TextStyle(color: fc.textPrimary, fontSize: 10, fontFamily: 'JetBrains Mono');
    final rows = <(String, String)>[
      ('type', e.kind),
      ('seq', '#${e.seq}'),
      if (e.turnId != null) ('tour', e.turnId!),
      for (final d in e.details.entries) (d.key, _fmt(d.value)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(r.$1, style: k)),
            Expanded(child: SelectableText(r.$2, style: v)),
          ]),
        ),
      if (e.callId != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            onTap: () => onSelectCall(e.callId!),
            child: Text(tr('→ voir toute la chaîne {}', [e.callId]),
                style: TextStyle(color: fc.primary, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }

  static String _fmt(Object? v) {
    if (v is Map || v is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(v);
      } catch (_) {
        return '$v';
      }
    }
    return '$v';
  }
}

// ──────────────────────────── Chaînes IA → carte ──────────────────────────────

class _ChainsPanel extends ConsumerWidget {
  const _ChainsPanel({required this.selectedCall, required this.onSelectCall});
  final String? selectedCall;
  final ValueChanged<String> onSelectCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final chains = ref.watch(backofficeChainsProvider);
    return GlassPanel(
      padding: EdgeInsets.zero,
      expand: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Icon(Icons.timeline_rounded, size: 14, color: fc.primary),
            const SizedBox(width: 8),
            Text(tr('CHAÎNES IA → CARTE'),
                style: TextStyle(color: fc.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Spacer(),
            Text('${chains.length}', style: TextStyle(color: fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
          ]),
        ),
        Container(height: 1, color: fc.surfaceBorder),
        Expanded(
          child: chains.isEmpty
              ? Center(
                  child: Text(tr('Aucun appel d\'outil enregistré.'),
                      style: TextStyle(color: fc.textDisabled, fontSize: 11)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: chains.length > 80 ? 80 : chains.length,
                  itemBuilder: (ctx, i) => _ChainCard(
                    chain: chains[i],
                    selected: chains[i].callId == selectedCall,
                    onTap: () => onSelectCall(chains[i].callId),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _ChainCard extends StatelessWidget {
  const _ChainCard({required this.chain, required this.selected, required this.onTap});
  final BackofficeChain chain;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final c = chain;
    final (color, label) = switch (c.status) {
      BackofficeChainStatus.attente => (fc.warning, tr('EN ATTENTE')),
      BackofficeChainStatus.refusee => (fc.textDisabled, tr('REFUSÉE')),
      BackofficeChainStatus.enCours => (fc.info, tr('EN COURS')),
      BackofficeChainStatus.ok => (fc.success, 'OK'),
      BackofficeChainStatus.echec => (fc.danger, tr('ÉCHEC')),
    };
    final ex = c.execution;
    final conf = c.confirmation;
    final steps = <(IconData, String, Color)>[
      (Icons.psychology_outlined, tr('demandé par {}', [originLabel(c.origin)]), fc.textSecondary),
      if (c.attente != null && conf == null && c.refus == null)
        (Icons.hourglass_top_rounded, tr('attend l\'opérateur'), fc.warning),
      if (conf != null) (Icons.check_circle_outline, tr('confirmé : {}', [originLabel(conf.origin)]), fc.success),
      if (c.refus != null) (Icons.block_outlined, tr('refusé : {}', [originLabel(c.refus!.origin)]), fc.textDisabled),
      for (final g in c.gardes) (Icons.shield_outlined, g.summary, fc.warning),
      if (ex != null)
        (
          ex.details['echec'] == true ? Icons.error_outline : Icons.done_all_rounded,
          '${ex.details['echec'] == true ? tr('échec') : tr('exécuté')} ${tr('en {} ms', [ex.details['duree_ms']])}',
          ex.details['echec'] == true ? fc.danger : fc.textSecondary,
        ),
      for (final tx in c.commandes)
        (
          tx.kind == 'firmware.tx_echec' ? Icons.wifi_off_rounded : Icons.arrow_forward_rounded,
          '${tx.details['commande'] ?? tx.summary}',
          tx.kind == 'firmware.tx_echec' ? fc.danger : fc.info,
        ),
      for (final rx in c.reponses)
        (
          Icons.arrow_back_rounded,
          '${rx.details['reponse']}${rx.details['latence_ms'] != null ? ' · ${rx.details['latence_ms']} ms' : ''}',
          rx.details['reponse'] == 'ok' ? fc.success : fc.warning,
        ),
      if (c.events.any((e) => e.kind == 'firmware.programme.debut'))
        (Icons.play_circle_outline, tr('programme lancé'), fc.info),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : fc.surfaceBright,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : fc.surfaceBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.tool,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fc.textPrimary, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'JetBrains Mono')),
            ),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(width: 8),
            Text(_clock(c.start), style: TextStyle(color: fc.textDisabled, fontSize: 9, fontFamily: 'JetBrains Mono')),
          ]),
          if (c.args.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(jsonEncode(c.args),
                maxLines: selected ? null : 1,
                overflow: selected ? null : TextOverflow.ellipsis,
                style: TextStyle(color: fc.textSecondary, fontSize: 9, fontFamily: 'JetBrains Mono')),
          ],
          const SizedBox(height: 6),
          for (final s in steps.take(selected ? steps.length : 5))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(s.$1, size: 11, color: s.$3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.$2,
                      maxLines: selected ? null : 1,
                      overflow: selected ? null : TextOverflow.ellipsis,
                      style: TextStyle(color: s.$3, fontSize: 10)),
                ),
              ]),
            ),
          if (!selected && steps.length > 5)
            Text(tr('+{} étape(s)…', [steps.length - 5]), style: TextStyle(color: fc.textDisabled, fontSize: 9)),
        ]),
      ),
    );
  }
}

// ──────────────────────────────── Santé ───────────────────────────────────────

class _HealthPanel extends ConsumerWidget {
  const _HealthPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final settings = ref.watch(aiAgentSettingsProvider);
    final model = ref.watch(aiModelProvider);
    final usage = ref.watch(aiUsageProvider);
    final journal = ref.watch(aiJournalSummaryProvider);
    final relay = ref.watch(chatRelayHostProvider);
    final net = ref.watch(networkStatsProvider);
    final fw = ref.watch(firmwareInfoProvider);
    final machine = ref.watch(machineStateProvider).valueOrNull;
    final stats = ref.watch(backofficeStatsProvider);

    final local = settings.localBaseUrl.isNotEmpty;
    final gated = settings.autonomy.values.where((l) => l == AiAutonomyLevel.requireConfirmation).length;

    Widget section(String title, List<(String, String)> rows, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(color: fc.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 4),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 118, child: Text(r.$1, style: TextStyle(color: fc.textDisabled, fontSize: 10))),
                  Expanded(
                    child: SelectableText(r.$2,
                        style: TextStyle(color: fc.textPrimary, fontSize: 10, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ]),
        );

    String pct(double v) => '${(v * 100).round()} %';
    String ms(int? v) => v == null ? '—' : '$v ms';

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      expand: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.monitor_heart_outlined, size: 14, color: fc.primary),
          const SizedBox(width: 8),
          Text(tr('SANTÉ'), style: TextStyle(color: fc.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              section(tr('MODÈLE'), [
                (tr('Agent'), settings.enabled ? tr('activé') : tr('désactivé')),
                (tr('Fournisseur'), local ? tr('local — {}', [settings.localBaseUrl]) : 'Gemini (4G)'),
                (tr('Modèle'), local ? settings.localModel : model.active.id),
                if (local) (tr('Modèle images'), settings.localVisionModel.isEmpty ? '—' : settings.localVisionModel),
                (tr('Lexique fermé'), settings.lexiconEnabled ? tr('activé') : tr('désactivé')),
                (tr('Confirmations'), tr('{} / {} catégories', [gated, AiActionCategory.values.length])),
                (tr('Aujourd\'hui'), tr('{} requêtes · {} images · {} tokens', [usage.requests, usage.images, usage.tokens])),
                if (stats.toursParModele.isNotEmpty)
                  (tr('Tours / modèle'), _top(stats.toursParModele)),
                if (stats.relaisVision > 0 || stats.imagesSansModele > 0)
                  (tr('Images'), tr('{} relais images → pilote · {} sans modèle d\'images', [stats.relaisVision, stats.imagesSansModele])),
              ]),
              const _LocalModelsSection(),
              section(
                tr('JOURNAL DES TOURS (TOUTES SESSIONS)'),
                journal.when(
                  data: (s) => s == null || s.turns == 0
                      ? [(tr('Tours'), tr('aucun journal'))]
                      : [
                          (tr('Tours'), '${s.turns}'),
                          (tr('Réussite'), pct(s.successRate)),
                          (tr('Latence'), tr('p50 {} · p95 {}', [ms(s.latencyP50Ms), ms(s.latencyP95Ms)])),
                          (tr('Tokens / tour'), s.meanTokens.toStringAsFixed(0)),
                          (tr('Garde-fous'), s.guards.isEmpty ? '—' : _top(s.guards)),
                          (tr('Outils'), s.toolCalls.isEmpty ? '—' : _top(s.toolCalls)),
                        ],
                  loading: () => [(tr('Tours'), '…')],
                  error: (_, _) => [(tr('Tours'), tr('journal illisible'))],
                ),
                trailing: InkWell(
                  onTap: () => ref.invalidate(aiJournalSummaryProvider),
                  child: Icon(Icons.refresh_rounded, size: 14, color: fc.textSecondary),
                ),
              ),
              section(tr('RELAIS PC ↔ TÉLÉPHONE'), [
                (tr('État'), relay.running ? tr('actif, {} appareil(s)', [relay.clients]) : tr('arrêté')),
                if (relay.error != null) (tr('Erreur'), relay.error!),
                (tr('Port'), '${ChatRelayProtocol.port}'),
              ]),
              section(tr('CARTE FLUIDNC'), [
                (tr('Statut'), machine?.status.name ?? '—'),
                (tr('Liaison'), net.connected ? tr('{} ms · qualité {} %', [net.latencyMs, net.qualityPct]) : tr('hors ligne')),
                (tr('Trames'), tr('TX {} · RX {}', [net.txCount, net.rxCount])),
                (tr('Firmware'), fw.version ?? '—'),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  static String _top(Map<String, int> m) {
    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(4).map((e) => '${e.key} ×${e.value}').join(', ');
  }
}

/// Les modèles installés sur le serveur local (Ollama), leur rôle et leur
/// état. Un modèle qui voit (gemma) et ne sert à rien se branche d'un geste.
class _LocalModelsSection extends ConsumerWidget {
  const _LocalModelsSection();

  static String _gib(int bytes) => bytes <= 0 ? '—' : '${(bytes / (1 << 30)).toStringAsFixed(1)} Go';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final report = ref.watch(localModelsReportProvider);
    final title = Row(children: [
      Expanded(
        child: Text(tr('MODÈLES LOCAUX (OLLAMA)'),
            style: TextStyle(color: fc.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
      ),
      InkWell(
        onTap: () => ref.invalidate(localModelsReportProvider),
        child: Icon(Icons.refresh_rounded, size: 14, color: fc.textSecondary),
      ),
    ]);
    final small = TextStyle(color: fc.textDisabled, fontSize: 10);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title,
        const SizedBox(height: 4),
        report.when(
          loading: () => Text(tr('interrogation du serveur…'), style: small),
          error: (_, _) => Text(tr('serveur illisible'), style: TextStyle(color: fc.warning, fontSize: 10)),
          data: (r) {
            if (r.url.isEmpty) return Text(tr('aucun serveur local'), style: small);
            if (!r.reachable) {
              return Text(
                  r.configured
                      ? tr('{} injoignable', [r.url])
                      : tr('aucun serveur réglé, et rien ne répond sur {}', [r.url]),
                  style: TextStyle(color: r.configured ? fc.warning : fc.textDisabled, fontSize: 10));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  r.configured
                      ? tr('{} · {} modèle(s)', [r.url, r.models.length])
                      : tr('{} répond ({} modèle(s)) mais n\'est pas réglé comme serveur de l\'agent', [r.url, r.models.length]),
                  style: TextStyle(color: r.configured ? fc.textDisabled : fc.warning, fontSize: 10)),
              if (r.pilotMissing)
                Text(tr('⚠ pilote « {} » non installé sur ce serveur', [r.pilot]),
                    style: TextStyle(color: fc.danger, fontSize: 10)),
              if (r.visionMissing)
                Text(tr('⚠ modèle d\'images « {} » non installé sur ce serveur', [r.vision]),
                    style: TextStyle(color: fc.danger, fontSize: 10)),
              for (final m in r.models) _LocalModelRow(status: m, report: r),
              if (r.models.isEmpty) Text(tr('aucun modèle installé'), style: small),
            ]);
          },
        ),
      ]),
    );
  }
}

class _LocalModelRow extends ConsumerWidget {
  const _LocalModelRow({required this.status, required this.report});
  final LocalModelStatus status;
  final LocalModelsReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final m = status.model;
    final (roleColor, roleLabel) = switch (status.role) {
      'pilote' => (fc.primary, tr('PILOTE')),
      'images' => (fc.secondary, tr('IMAGES')),
      _ => (fc.textDisabled, '—'),
    };
    final caps = <String>[
      if (m.supportsTools == true) tr('outils'),
      if (m.supportsVision) tr('vision'),
      if (m.contextTokens != null) tr('ctx {}', [m.contextTokens]),
    ];
    final loaded = status.loaded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: status.isLoaded ? fc.success : fc.textDisabled,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(m.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fc.textPrimary, fontSize: 10, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(roleLabel, style: TextStyle(color: roleColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
            Text(
              [
                if (caps.isNotEmpty) caps.join(' · '),
                status.isLoaded
                    ? tr('chargé, {} en VRAM{}', [
                        _LocalModelsSection._gib(loaded!.sizeVram),
                        loaded.gpuShare == null ? '' : ' (${(loaded.gpuShare! * 100).round()} % GPU)',
                      ])
                    : tr('installé, pas en mémoire'),
                if (m.unusableReason == 'tools' && status.role == 'pilote') tr('⚠ ne sait pas appeler d\'outils'),
              ].join(' · '),
              style: TextStyle(color: fc.textDisabled, fontSize: 9),
            ),
          ]),
        ),
        if (status.canWireForImages)
          TextButton(
            onPressed: () => ref.read(localModelsWiringProvider).wireForImages(report, status),
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: fc.secondary),
            child: Text(tr('BRANCHER'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
          ),
      ]),
    );
  }
}
