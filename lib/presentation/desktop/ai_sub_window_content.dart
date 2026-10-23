import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

/// Contenu d'une fenêtre « graphique » ouverte par l'agent IA. [payload]
/// vient tel quel de `AiWindowLauncher.openChart` (labels/values/unit).
class ChartWindow extends StatelessWidget {
  const ChartWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
        content: Center(child: Text('Aucune donnée.', style: theme.typography.body)),
      );
    }

    final maxY = values.reduce((a, b) => a > b ? a : b);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(0.5, double.infinity);

    return ScaffoldPage(
      padding: const EdgeInsets.all(20),
      header: PageHeader(title: Text(title)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unit.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('unité : $unit', style: theme.typography.caption),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY - pad,
                maxY: maxY + pad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.resources.dividerStrokeColorDefault,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: theme.typography.caption,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i], style: theme.typography.caption),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
                    ],
                    isCurved: true,
                    color: theme.accentColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.accentColor.withValues(alpha: .12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final theme = FluentTheme.of(context);
    final title = payload['title'] as String? ?? 'G-code';
    final content = payload['content'] as String? ?? '';
    final lineCount = content.isEmpty ? 0 : content.trimRight().split('\n').length;

    return ScaffoldPage(
      padding: const EdgeInsets.all(20),
      header: PageHeader(
        title: Text(title),
        commandBar: CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.copy),
              label: const Text('Copier'),
              onPressed: () => Clipboard.setData(ClipboardData(text: content)),
            ),
          ],
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$lineCount lignes', style: theme.typography.caption),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.micaBackgroundColor,
                border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.5, height: 1.6),
                ),
              ),
            ),
          ),
        ],
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
    final theme = FluentTheme.of(context);
    final title = payload['title'] as String? ?? 'Rapport';
    final fields = ((payload['fields'] as Map?) ?? const {}).cast<String, dynamic>();

    return ScaffoldPage(
      padding: const EdgeInsets.all(20),
      header: PageHeader(title: Text(title)),
      content: ListView.separated(
        itemCount: fields.length,
        separatorBuilder: (_, _) => Divider(style: DividerThemeData(
          decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
        )),
        itemBuilder: (context, i) {
          final key = fields.keys.elementAt(i);
          final value = fields[key];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(key, style: theme.typography.body)),
                Text(
                  '$value',
                  style: theme.typography.bodyStrong?.copyWith(color: theme.accentColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
