import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/forgeron_colors.dart';

/// Mention sous une réponse traduite automatiquement (`LocalTranslator`) :
/// la traduction n'a pas été relue par un locuteur, alors le français
/// d'origine reste à un geste. Fermée par défaut pour ne pas doubler le fil.
class TranslationNote extends StatefulWidget {
  const TranslationNote({super.key, required this.fc, required this.source});

  final ForgeronColorPalette fc;

  /// Réponse d'origine, en français.
  final String source;

  @override
  State<TranslationNote> createState() => _TranslationNoteState();
}

class _TranslationNoteState extends State<TranslationNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, size: 12, color: fc.textSecondary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _open
                        ? tr('Masquer le français')
                        : tr('Traduction automatique, non relue — voir le français'),
                    style: TextStyle(
                      color: fc.textSecondary,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                widget.source,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
