import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/split_view.dart';
import '../../core/utils/gcode_tool_extractor.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/program_tools_provider.dart';
import '../tutorial/tutorial_keys.dart';
import '../widgets/tool_photo.dart';
import '../../core/i18n/app_localizations.dart';

/// Magasin d'outils — **lu dans le programme chargé**, jamais saisi.
///
/// Il n'existe pas de table d'outils dans l'application : ni fichier `tool.tbl`,
/// ni suivi de durée de vie, ni mesure d'usure. Cet écran affichait jusqu'ici
/// douze outils écrits en dur, avec des états inventés (« USURE : 85 % »,
/// « BRIS DÉTECTÉ ») et un bouton qui envoyait `T.. M6` pour des outils que la
/// machine n'a jamais eus. Tout vient désormais de [programToolsProvider],
/// c'est-à-dire du G-code lui-même — comme sur mobile.
class ToolTableScreen extends ConsumerStatefulWidget {
  const ToolTableScreen({super.key});

  @override
  ConsumerState<ToolTableScreen> createState() => _ToolTableScreenState();
}

class _ToolTableScreenState extends ConsumerState<ToolTableScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Sélection mémorisée par **numéro** d'outil, pas par index : la liste
  /// change à chaque programme chargé, un index survivrait mal au changement.
  int? _selectedNumber;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final tools = ref.watch(programToolsProvider);
    final activeToolNum = ref.watch(activeToolNumberProvider);

    final filtered = tools.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return 'T${t.number}'.contains(q) ||
          (t.description ?? '').toLowerCase().contains(q) ||
          (t.operation ?? '').toLowerCase().contains(q);
    }).toList();

    final selected = _resolveSelection(tools);

    // Sans programme, rien à mettre de part et d'autre : le partage en deux
    // colonnes n'affichait que deux moitiés vides. Un seul message, centré
    // sur toute la largeur.
    if (tools.isEmpty) {
      return Container(
        color: fc.background,
        child: Column(children: [
          _header(fc, 0, activeToolNum),
          Expanded(child: _emptyState(fc)),
        ]),
      );
    }

    return ResizableSplitView(
      initialRatio: 0.35,
      left: Column(children: [
        _header(fc, tools.length, activeToolNum),
        _searchField(fc),
        Expanded(
          key: TutorialKeys.toolTable,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final t = filtered[i];
              return _ToolRow(
                tool: t,
                isSelected: t.number == selected?.number,
                isActive: t.number == activeToolNum && activeToolNum > 0,
                onTap: () => setState(() => _selectedNumber = t.number),
              );
            },
          ),
        ),
      ]),
      right: selected == null
          ? _noSelection(fc)
          : _ToolDetailPanel(
              key: ValueKey(selected.number),
              tool: selected,
              isActive: selected.number == activeToolNum && activeToolNum > 0,
            ),
    );
  }

  /// L'outil affiché à droite : celui que l'opérateur a cliqué s'il existe
  /// encore dans le programme courant, sinon le premier de la liste.
  ProgramTool? _resolveSelection(List<ProgramTool> tools) {
    if (tools.isEmpty) return null;
    for (final t in tools) {
      if (t.number == _selectedNumber) return t;
    }
    return tools.first;
  }

  Widget _header(ForgeronColorPalette fc, int count, int activeToolNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('OUTILS DU PROGRAMME'),
                style: TextStyle(
                    color: fc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0)),
            const SizedBox(height: 2),
            Text(tr('lus dans le G-code chargé'),
                style: TextStyle(color: fc.textDisabled, fontSize: 9)),
          ],
        ),
        const Spacer(),
        if (activeToolNum > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: fc.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: fc.success.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.build, color: fc.success, size: 10),
              const SizedBox(width: 4),
              Text(tr('ACTIF : T{}', [activeToolNum]),
                  style: TextStyle(
                      color: fc.success,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ]),
          ),
          const SizedBox(width: 8),
        ],
        Text(tr(count > 1 ? '{} outils' : '{} outil', [count]),
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _searchField(ForgeronColorPalette fc) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: fc.surface,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(color: fc.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: tr('Filtrer par T# ou descriptif…'),
          hintStyle: TextStyle(color: fc.textDisabled, fontSize: 12),
          prefixIcon: Icon(Icons.search, color: fc.textDisabled, size: 18),
          border: OutlineInputBorder(
              borderSide: BorderSide(color: fc.surfaceBorder)),
          filled: true,
          fillColor: fc.surfaceBright,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _emptyState(ForgeronColorPalette fc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handyman_outlined, color: fc.textDisabled, size: 48),
            const SizedBox(height: 14),
            Text(tr('AUCUN PROGRAMME CHARGÉ'),
                style: TextStyle(
                    color: fc.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              tr('Les outils sont lus dans le G-code. Charge un programme depuis l\'espace de travail pour voir ceux qu\'il utilise.'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: fc.textDisabled, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noSelection(ForgeronColorPalette fc) {
    return Container(
      color: fc.background,
      alignment: Alignment.center,
      child: Text(tr('Sélectionne un outil dans la liste'),
          style: TextStyle(color: fc.textDisabled, fontSize: 12)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne de la liste
// ─────────────────────────────────────────────────────────────────────────────

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  final ProgramTool tool;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final accent = isActive ? fc.success : fc.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? fc.primary.withValues(alpha: 0.08)
              : fc.surface,
          border: Border(
            bottom: BorderSide(color: fc.surfaceBorder),
            left: BorderSide(
                color: isSelected ? fc.primary : Colors.transparent, width: 3),
          ),
        ),
        child: Row(children: [
          ToolPhoto(shape: tool.shape, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('T${tool.number}',
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono')),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.play_arrow_rounded, color: fc.success, size: 12),
                  ],
                ]),
                const SizedBox(height: 2),
                // Le descriptif brut du post quand il existe. Sinon on le dit,
                // au lieu d'afficher un nom d'outil plausible.
                Text(
                  tool.description ?? 'descriptif absent du programme',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tool.description == null
                        ? fc.textDisabled
                        : fc.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontStyle: tool.description == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                if (tool.operation != null)
                  Text(tool.operation!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fc.textDisabled, fontSize: 9)),
              ],
            ),
          ),
          Text('×${tool.changeLines.length}',
              style: TextStyle(
                  color: fc.textDisabled,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono')),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panneau de détail
// ─────────────────────────────────────────────────────────────────────────────

class _ToolDetailPanel extends ConsumerWidget {
  const _ToolDetailPanel({
    super.key,
    required this.tool,
    required this.isActive,
  });

  final ProgramTool tool;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;

    return Column(
      key: TutorialKeys.calibrationWizard,
      children: [
        // ── En-tête : identité + commandes ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: fc.surface,
            border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
          ),
          child: Row(children: [
            ToolPhoto(shape: tool.shape, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('T${tool.number}',
                      style: TextStyle(
                          color: fc.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'JetBrains Mono')),
                  Text(tool.shape.label,
                      style: TextStyle(color: fc.primary, fontSize: 11)),
                  if (isActive) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: fc.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: fc.success.withValues(alpha: 0.4)),
                      ),
                      child: Text(tr('▶ EN BROCHE'),
                          style: TextStyle(
                              color: fc.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: fc.primary,
                    minimumSize: const Size(0, 32)),
                icon: const Icon(Icons.build, size: 12, color: Colors.white),
                label: Text(tr('APPELER T{}  (M6)', [tool.number]),
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                onPressed: () => _confirmCall(context, ref),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: fc.info),
                    minimumSize: const Size(0, 32)),
                icon: Icon(Icons.straighten, size: 12, color: fc.info),
                label: Text(tr('G43 H{}  (décalage L)', [tool.number]),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: fc.info)),
                onPressed: () {
                  ref
                      .read(machineRepositoryProvider)
                      .sendGCode('G43 H${tool.number}');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('✓ G43 H{} appliqué', [tool.number])),
                  ));
                },
              ),
            ]),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(fc, 'CE QUE DIT LE PROGRAMME'),
                const SizedBox(height: 12),
                if (tool.description != null)
                  _rawLine(fc, tool.description!)
                else
                  _notice(
                    fc,
                    fc.warning,
                    Icons.info_outline,
                    'Le programme ne décrit pas cet outil : il n\'indique que '
                    'son numéro. Aucune caractéristique n\'est affichée plutôt '
                    'que d\'en inventer.',
                  ),
                if (tool.operation != null) ...[
                  const SizedBox(height: 10),
                  _rawLine(fc, tool.operation!),
                ],

                // ── Caractéristiques réellement présentes ──────────────────
                if (!tool.isBare) ...[
                  const SizedBox(height: 28),
                  _sectionTitle(fc, 'CARACTÉRISTIQUES'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      if (tool.diameterMm != null)
                        _paramCard(context, 'DIAMÈTRE (D)',
                            _trim(tool.diameterMm!), 'mm'),
                      if (tool.diameterMm != null)
                        _paramCard(context, 'RAYON (R)',
                            _trim(tool.diameterMm! / 2), 'mm'),
                      if (tool.cuttingLengthMm != null)
                        _paramCard(context, 'LONGUEUR DE COUPE',
                            _trim(tool.cuttingLengthMm!), 'mm'),
                      if (tool.flutes != null)
                        _paramCard(context, 'TAILLES', '${tool.flutes}', ''),
                      if (tool.material != null)
                        _paramCard(context, 'MATIÈRE', tool.material!, ''),
                    ],
                  ),
                ],

                const SizedBox(height: 28),
                _sectionTitle(fc, 'DANS LE PROGRAMME'),
                const SizedBox(height: 12),
                _row(fc, 'Appelé', '${tool.changeLines.length} fois'),
                // Numérotation du FICHIER SOURCE, pas du programme affiché
                // dans l'espace de travail : celui-ci est la version adaptée,
                // dont les lignes ont été renumérotées.
                _row(fc, 'Ligne (fichier d\'origine)',
                    '${tool.firstChangeLine + 1}'),

                if (tool.spindleSpeed != null) ...[
                  const SizedBox(height: 12),
                  // Sans cette mise en garde, l'opérateur croirait que la
                  // broche tourne au régime annoncé. Sur une broche pilotée en
                  // tout-ou-rien, le mot S est reçu puis ignoré.
                  _notice(
                    fc,
                    fc.info,
                    Icons.speed,
                    'Le programme demande S${tool.spindleSpeed}. Cette valeur '
                    'n\'est appliquée que si la broche est pilotée en vitesse ; '
                    'en tout-ou-rien elle est ignorée.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmCall(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: context.fc.surface,
        title: Text(tr('Appel outil T{}', [tool.number]),
            style: TextStyle(color: context.fc.textPrimary, fontSize: 16)),
        content: Text(
          tr('Envoyer T{} M6 ?\n\nLa broche s\'arrête et le programme se met en pause pour le changement.', [tool.number]),
          style: TextStyle(color: context.fc.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(tr('Annuler')),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(machineRepositoryProvider)
                  .sendGCode('T${tool.number} M6');
              Navigator.pop(dctx);
            },
            child: Text(tr('Envoyer')),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ForgeronColorPalette fc, String label) => Text(
        label,
        style: TextStyle(
            color: fc.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0),
      );

  Widget _rawLine(ForgeronColorPalette fc, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fc.terminalBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: Text(text,
            style: TextStyle(
                color: fc.textPrimary,
                fontSize: 12,
                fontFamily: 'JetBrains Mono')),
      );

  Widget _notice(
          ForgeronColorPalette fc, Color color, IconData icon, String text) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: fc.textSecondary, fontSize: 11, height: 1.4)),
          ),
        ]),
      );

  Widget _row(ForgeronColorPalette fc, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label, style: TextStyle(color: fc.textDisabled, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'JetBrains Mono')),
        ]),
      );

  Widget _paramCard(
      BuildContext context, String label, String value, String unit) {
    final fc = context.fc;
    return SizedBox(
      width: 180,
      child: GlassPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: fc.textDisabled,
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
                      style: TextStyle(
                          color: fc.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'JetBrains Mono')),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(unit,
                    style: TextStyle(color: fc.textDisabled, fontSize: 10)),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
