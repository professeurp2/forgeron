import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/forge_kinetic_fx.dart';

class _SubWindowHeader extends StatelessWidget {
  const _SubWindowHeader({
    required this.title,
    required this.badgeLabel,
    this.trailing,
  });

  final String title;
  final String badgeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: fc.cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.rimHighlight, width: 1.1),
      ),
      child: Row(
        children: [
          const ForgeAiGyroOrb(size: 26, active: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: fc.textPrimary,
              ),
            ),
          ),
          if (badgeLabel.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fc.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fc.primary.withValues(alpha: 0.45)),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fc.primaryLight,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ChartKpiCard extends StatelessWidget {
  const _ChartKpiCard({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: fc.cardGradient,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fc.rimHighlight),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: fc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fc.lcdText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu d'une fenêtre « graphique » ouverte par l'agent IA. [payload]
/// vient tel quel de `AiWindowLauncher.openChart` (labels/values/unit).
class ChartWindow extends StatelessWidget {
  const ChartWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final labels = ((payload['labels'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final values = ((payload['values'] as List?) ?? const [])
        .map((e) => (e as num).toDouble())
        .toList();
    final unit = payload['unit'] as String? ?? '';
    final title = payload['title'] as String? ?? 'Graphique';

    if (values.isEmpty) {
      return ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          color: fc.background,
          child: Center(
            child: Text(
              tr('Aucune donnée.'),
              style: TextStyle(fontFamily: 'JetBrains Mono', color: fc.textSecondary),
            ),
          ),
        ),
      );
    }

    final maxY = values.reduce((a, b) => a > b ? a : b);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final avgY = values.reduce((a, b) => a + b) / values.length;
    final pad = ((maxY - minY).abs() * 0.15).clamp(0.5, double.infinity);
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Container(
        color: fc.background,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubWindowHeader(
              title: title,
              badgeLabel: unit.isNotEmpty ? unit.toUpperCase() : '${values.length} PTS',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ChartKpiCard(
                  label: tr('MINIMUM'),
                  value: '${minY.toStringAsFixed(1)}$unitSuffix',
                  accentColor: fc.secondary,
                ),
                const SizedBox(width: 10),
                _ChartKpiCard(
                  label: tr('MOYENNE'),
                  value: '${avgY.toStringAsFixed(1)}$unitSuffix',
                  accentColor: fc.warning,
                ),
                const SizedBox(width: 10),
                _ChartKpiCard(
                  label: tr('MAXIMUM'),
                  value: '${maxY.toStringAsFixed(1)}$unitSuffix',
                  accentColor: fc.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BentoCascadeEntry(
                index: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: fc.cardGradient,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: fc.rimHighlight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TacticalGridBackground(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 20, 14),
                      child: LineChart(
                        LineChartData(
                          minY: minY - pad,
                          maxY: maxY + pad,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: fc.surfaceBorder.withValues(alpha: 0.7),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                getTitlesWidget: (v, meta) => Text(
                                  v.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10.5,
                                    color: fc.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (v != i.toDouble() || i < 0 || i >= labels.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[i],
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 10.5,
                                        color: fc.textSecondary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < values.length; i++)
                                  FlSpot(i.toDouble(), values[i]),
                              ],
                              isCurved: true,
                              color: fc.primary,
                              barWidth: 2.8,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                  radius: 3.5,
                                  color: fc.primaryLight,
                                  strokeWidth: 1.5,
                                  strokeColor: fc.background,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    fc.primary.withValues(alpha: 0.24),
                                    fc.primary.withValues(alpha: 0.02),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fenêtre « G-code » : le programme complet, détaché du fil de discussion —
/// utile pour le garder ouvert à côté du visualiseur 3D pendant que l'agent
/// continue à répondre dans la fenêtre principale.
class GcodeWindow extends StatelessWidget {
  const GcodeWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final title = payload['title'] as String? ?? 'G-code';
    final content = payload['content'] as String? ?? '';
    final lines = content.isEmpty ? const <String>[] : content.trimRight().split('\n');

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Container(
        color: fc.background,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubWindowHeader(
              title: title,
              badgeLabel: tr('{} lignes', [lines.length]).toUpperCase(),
              trailing: Button(
                onPressed: () => Clipboard.setData(ClipboardData(text: content)),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(fc.surfaceBright),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    side: BorderSide(color: fc.rimHighlight),
                    borderRadius: BorderRadius.circular(6),
                  )),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: fc.primary),
                    const SizedBox(width: 6),
                    Text(
                      tr('Copier'),
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: fc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BentoCascadeEntry(
                index: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: fc.terminalBg,
                    border: Border.all(color: fc.rimHighlight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TacticalGridBackground(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: lines.length,
                      itemBuilder: (context, i) {
                        final lineNum = 'N${(i + 1).toString().padLeft(3, '0')}';
                        final rawLine = lines[i];
                        final isComment = rawLine.trimLeft().startsWith('(') ||
                            rawLine.trimLeft().startsWith(';');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 48,
                                child: Text(
                                  lineNum,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12,
                                    color: fc.primary.withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  rawLine,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: isComment ? fc.textSecondary : fc.lcdText,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fenêtre « rapport » : une grille clé/valeur — ce que `gen_revolution.generate`
/// (et demain le critique) retourne déjà en JSON, sans qu'il faille l'inventer
/// pour l'affichage.
class ReportWindow extends StatelessWidget {
  const ReportWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final title = payload['title'] as String? ?? 'Rapport';
    final fields = ((payload['fields'] as Map?) ?? const {}).cast<String, dynamic>();

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Container(
        color: fc.background,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubWindowHeader(
              title: title,
              badgeLabel: '${fields.length} ${tr('PARAMÈTRES')}',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: fields.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final key = fields.keys.elementAt(i);
                  final value = fields[key];
                  return BentoCascadeEntry(
                    index: i,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: fc.cardGradient,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: fc.rimHighlight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: fc.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              key.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                                color: fc.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: fc.terminalBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: fc.surfaceBorder),
                            ),
                            child: Text(
                              '$value',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: fc.lcdText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
