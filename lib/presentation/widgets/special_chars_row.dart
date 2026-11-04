import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';

/// Un jeu de lettres que les claviers de téléphone n'offrent pas toujours.
class SpecialCharSet {
  const SpecialCharSet({required this.id, required this.label, required this.chars});

  final String id;

  /// Nom de la langue, tel qu'on le montre à l'opérateur.
  final String label;

  /// Lettres en minuscule ; les majuscules en sont déduites.
  final List<String> chars;
}

/// Bambara (bamanankan) : les quatre lettres de l'alphabet phonétique que ni le
/// clavier français ni l'anglais n'ont — ɛ, ɔ, ɲ, ŋ.
///
/// Pour en ajouter un autre jeu (fula : ɓ ɗ ƴ ; haoussa : ɓ ɗ ƙ ƴ ; yoruba :
/// ẹ ọ ṣ), il suffit de l'ajouter à [kSpecialCharSets] : le composant n'a rien
/// de propre au bambara.
const kBambaraChars = SpecialCharSet(
  id: 'bm',
  // Donnee const : la traduction se fait a l'affichage (`tr(set.label)`
  // plus bas), sinon elle serait figee au premier acces et ne suivrait
  // jamais un changement de langue.
  label: 'Bambara',
  chars: ['ɛ', 'ɔ', 'ɲ', 'ŋ'],
);

const kSpecialCharSets = <SpecialCharSet>[kBambaraChars];

/// Rangée de touches qui insère une lettre à la position du curseur.
///
/// **Pourquoi dans l'application.** Le lexique plie « ɛ »→e, « ɔ »→o, « ɲ »→ny,
/// « ŋ »→ng : écrire sans ces lettres marche. Mais ceux qui écrivent le
/// bambara correctement n'ont pas à s'en priver, et installer un clavier tiers
/// (Gboard, Keyman…) ne doit pas être un prérequis pour parler à la machine.
///
/// Les touches ne prennent pas le focus : le champ de saisie le garde, donc le
/// clavier du téléphone reste ouvert.
class SpecialCharsRow extends StatefulWidget {
  const SpecialCharsRow({
    super.key,
    required this.controller,
    this.sets = kSpecialCharSets,
    this.onChanged,
  });

  final TextEditingController controller;
  final List<SpecialCharSet> sets;

  /// Appelé après chaque insertion (pour rafraîchir un compteur, par exemple).
  final VoidCallback? onChanged;

  @override
  State<SpecialCharsRow> createState() => _SpecialCharsRowState();
}

class _SpecialCharsRowState extends State<SpecialCharsRow> {
  bool _upper = false;

  /// Insère [char] à la place de la sélection (ou au curseur). Si le champ n'a
  /// jamais eu le focus, la sélection est invalide : on ajoute à la fin.
  void _insert(String char) {
    final c = widget.controller;
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    c.value = TextEditingValue(
      text: text.replaceRange(start, end, char),
      selection: TextSelection.collapsed(offset: start + char.length),
    );
    widget.onChanged?.call();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return ExcludeFocus(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: fc.surface,
          border: Border(top: BorderSide(color: fc.surfaceBorder)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final set in widget.sets) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(tr(set.label),
                      style: TextStyle(
                          color: fc.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                for (final ch in set.chars)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Key(
                      label: _upper ? ch.toUpperCase() : ch,
                      semantics: tr('Insérer la lettre {}', [_upper ? ch.toUpperCase() : ch]),
                      onTap: () => _insert(_upper ? ch.toUpperCase() : ch),
                    ),
                  ),
              ],
              const SizedBox(width: 6),
              Tooltip(
                message: tr('Majuscule'),
                child: _Key(
                  label: '⇧',
                  selected: _upper,
                  semantics: tr('Majuscule'),
                  onTap: () => setState(() => _upper = !_upper),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tr('ou écris e, o, ny, ng : c\'est compris aussi'),
                style: TextStyle(color: fc.textDisabled, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    required this.semantics,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final String semantics;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: selected ? fc.primary.withValues(alpha: 0.18) : fc.surfaceBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? fc.primary : fc.surfaceBorder),
        ),
        child: InkWell(
          onTap: onTap,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 36,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
