import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/program_tools_provider.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/utils/gcode_tool_extractor.dart';
import '../../domain/models/machine_state.dart';
import '../../core/i18n/app_localizations.dart';

/// Bandeau affiché pendant une **pause de changement d'outil**.
///
/// L'adaptateur G-code insère `M5` puis `M0` avant chaque `T.. M6` : la broche
/// s'arrête et le programme se met en pause. À cet instant, l'opérateur a une
/// seule question — *quel outil je monte ?* — et la réponse était jusqu'ici
/// enfouie dans le G-code.
///
/// Tout ce qui est montré vient du programme chargé. Quand celui-ci ne décrit
/// pas l'outil, le bandeau affiche le numéro et le dit franchement : monter le
/// mauvais outil parce que l'application en a inventé les caractéristiques
/// serait le pire des scénarios.
class ToolChangeBanner extends ConsumerWidget {
  const ToolChangeBanner({super.key, this.dense = false});

  /// Densité desktop : une seule ligne posée au-dessus du visualiseur, au lieu
  /// de la carte pleine hauteur du téléphone. Au poste, l'écran sert d'abord à
  /// suivre la coupe — le bandeau doit informer sans manger la vue.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(machineStateProvider).valueOrNull?.status;

    // `M0` met FluidNC en pause programme, rapportée comme un maintien.
    if (status != MachineStatus.hold) return const SizedBox.shrink();

    final toolNum = ref.watch(activeToolNumberProvider);
    if (toolNum <= 0) return const SizedBox.shrink();

    final tool = ref.watch(activeProgramToolProvider);
    final fc = context.fc;

    if (dense) return _dense(context, fc, toolNum, tool);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fc.warning.withValues(alpha: 0.18), fc.surface],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fc.warning, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pan_tool_outlined, color: fc.warning, size: 16),
          const SizedBox(width: 8),
          Text(tr('CHANGEMENT D\'OUTIL'),
              style: TextStyle(
                  color: fc.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          const Spacer(),
          Text(tr('BROCHE ARRÊTÉE'),
              style: TextStyle(
                  color: fc.textDisabled,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: fc.terminalBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: tool != null && tool.shape != ToolShape.unknown
                ? Image.asset(tool.shape.asset, fit: BoxFit.contain)
                : Icon(Icons.help_outline, color: fc.textDisabled, size: 38),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('MONTER'),
                    style: TextStyle(color: fc.textDisabled, fontSize: 9)),
                Text('T$toolNum',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
                const SizedBox(height: 4),
                if (tool?.description != null)
                  Text(tool!.description!,
                      style: TextStyle(
                          color: fc.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                          fontFamily: 'JetBrains Mono'))
                else
                  Text(tr('Le programme ne décrit pas cet outil.'),
                      style: TextStyle(
                          color: fc.textDisabled,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                if (tool != null && !tool.isBare) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (tool.diameterMm != null)
                      _pill(fc, 'Ø ${_trim(tool.diameterMm!)} mm'),
                    if (tool.flutes != null)
                      _pill(fc, '${tool.flutes} tailles'),
                    if (tool.cuttingLengthMm != null)
                      _pill(fc, 'coupe ${_trim(tool.cuttingLengthMm!)} mm'),
                    if (tool.material != null) _pill(fc, tool.material!),
                  ]),
                ],
              ],
            ),
          ),
        ]),

        if (tool?.operation != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.play_arrow_rounded, color: fc.textDisabled, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(tr('Suite : {}', [tool!.operation!]),
                  style: TextStyle(color: fc.textDisabled, fontSize: 11)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _dense(BuildContext context, ForgeronColorPalette fc, int toolNum,
      ProgramTool? tool) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fc.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: fc.warning, width: 3),
          top: BorderSide(color: fc.surfaceBorder),
          right: BorderSide(color: fc.surfaceBorder),
          bottom: BorderSide(color: fc.surfaceBorder),
        ),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: fc.terminalBg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: fc.surfaceBorder),
          ),
          child: tool != null && tool.shape != ToolShape.unknown
              ? Image.asset(tool.shape.asset, fit: BoxFit.contain)
              : Icon(Icons.help_outline, color: fc.textDisabled, size: 20),
        ),
        const SizedBox(width: 12),
        Text(tr('CHANGEMENT D\'OUTIL'),
            style: TextStyle(
                color: fc.warning,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        const SizedBox(width: 14),
        Text(tr('MONTER T{}', [toolNum]),
            style: TextStyle(
                color: fc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono')),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            tool?.description ?? 'Le programme ne décrit pas cet outil.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: tool?.description == null
                    ? fc.textDisabled
                    : fc.textSecondary,
                fontSize: 11,
                fontStyle: tool?.description == null
                    ? FontStyle.italic
                    : FontStyle.normal,
                fontFamily: 'JetBrains Mono'),
          ),
        ),
        if (tool != null && !tool.isBare) ...[
          const SizedBox(width: 10),
          if (tool.diameterMm != null) _pill(fc, 'Ø ${_trim(tool.diameterMm!)}'),
          if (tool.flutes != null) ...[
            const SizedBox(width: 5),
            _pill(fc, '${tool.flutes} tailles'),
          ],
        ],
        const SizedBox(width: 14),
        Text(tr('BROCHE ARRÊTÉE'),
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _pill(ForgeronColorPalette fc, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: fc.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: fc.primary.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: fc.primary, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
