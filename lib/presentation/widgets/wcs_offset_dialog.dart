import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/di_providers.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// `G54` -> `P1` ... `G59` -> `P6`.
///
/// Une erreur d'indice ici ecrirait silencieusement dans un AUTRE systeme de
/// coordonnees que celui affiche : la machine accepterait la commande sans
/// broncher, et le decalage apparaitrait ailleurs.
int wcsPNumber(String wcs) {
  final n = int.tryParse(wcs.replaceAll(RegExp(r'[^0-9]'), ''));
  if (n == null || n < 54 || n > 59) return 1;
  return n - 53;
}

/// Accepte la virgule decimale : c'est ce que produit un clavier francais, et
/// refuser la saisie sans le dire serait incomprehensible.
double? parseOffset(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.'));

/// Construit la commande `G10 L2`.
///
/// A ne pas confondre avec le `L20` du « zero ici » :
///   - **L2**  : « le zero piece est A CETTE POSITION machine »
///   - **L20** : « la position actuelle DEVIENT cette valeur »
String buildWcsOffsetCommand(String wcs, List<double> values, List<String> axes) {
  final buf = StringBuffer('G10 L2 P${wcsPNumber(wcs)}');
  for (var i = 0; i < values.length && i < axes.length; i++) {
    buf.write(' ${axes[i]}${formatOffset(values[i])}');
  }
  return buf.toString();
}

/// Trois decimales suffisent : la resolution mecanique de la machine est bien
/// au-dessus. Les zeros inutiles sont retires pour garder la ligne lisible.
String formatOffset(double v) =>
    v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// Saisie au clavier du décalage d'un système de coordonnées pièce.
///
/// Complète le « zéro ici » : celui-ci pose l'origine à la position courante
/// (`G10 L20`), ce qui suppose d'y avoir amené l'outil. Quand la cote du
/// montage est connue — butée usinée, gabarit, relevé de contrôle — il est plus
/// juste et plus rapide de l'écrire que d'aller la chercher au jog.
///
/// Envoie `G10 L2 P<n>`, à ne pas confondre avec le `L20` du « zéro ici » :
///   - **L2**  : « le zéro pièce est À CETTE POSITION machine »
///   - **L20** : « la position actuelle DEVIENT cette valeur »
///
/// Les champs sont préremplis avec le décalage courant : un axe qu'on ne touche
/// pas est réécrit à l'identique, jamais remis à zéro par omission.
class WcsOffsetDialog extends ConsumerStatefulWidget {
  const WcsOffsetDialog({
    super.key,
    required this.wcs,
    required this.current,
    required this.axisLabels,
    required this.axisColors,
  });

  final String wcs;
  final List<double> current;
  final List<String> axisLabels;
  final List<Color> axisColors;

  @override
  ConsumerState<WcsOffsetDialog> createState() => _WcsOffsetDialogState();
}

class _WcsOffsetDialogState extends ConsumerState<WcsOffsetDialog> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      5,
      (i) => TextEditingController(
        text: (i < widget.current.length ? widget.current[i] : 0.0)
            .toStringAsFixed(3),
      ),
    )..forEach((c) => c.addListener(() => setState(() {})));
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String raw) => parseOffset(raw);

  List<double>? get _values {
    final out = <double>[];
    for (final c in _ctrls) {
      final v = _parse(c.text);
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  String? get _command {
    final v = _values;
    if (v == null) return null;
    return buildWcsOffsetCommand(widget.wcs, v, widget.axisLabels);
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final command = _command;

    return AlertDialog(
      backgroundColor: fc.surface,
      title: Row(children: [
        Icon(Icons.edit_location_alt_outlined, color: fc.primary, size: 20),
        const SizedBox(width: 10),
        Text(tr('Décalage {}', [widget.wcs]),
            style: TextStyle(
                color: fc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Position du zéro pièce, exprimée en coordonnées MACHINE. Sur une machine dont le zéro est aux capteurs, ces valeurs sont normalement négatives.'),
              style:
                  TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 16),

            for (var i = 0; i < 5; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(
                    width: 26,
                    child: Text(widget.axisLabels[i],
                        style: TextStyle(
                            color: widget.axisColors[i],
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'JetBrains Mono')),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrls[i],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: TextStyle(
                          color: fc.textPrimary,
                          fontSize: 15,
                          fontFamily: 'JetBrains Mono'),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: i >= 3 ? '°' : 'mm',
                        suffixStyle:
                            TextStyle(color: fc.textDisabled, fontSize: 11),
                        errorText:
                            _parse(_ctrls[i].text) == null ? 'invalide' : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fc.surfaceBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fc.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 4),
            // La commande exacte est montrée avant l'envoi : c'est une écriture
            // sur l'origine pièce, une erreur de signe se paie en collision.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fc.terminalBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fc.surfaceBorder),
              ),
              child: Text(
                command ?? 'Valeur non numérique — corrige un champ.',
                style: TextStyle(
                  color: command == null ? fc.error : fc.textPrimary,
                  fontSize: 11.5,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Annuler')),
        ),
        ElevatedButton(
          onPressed: command == null
              ? null
              : () {
                  ref.read(machineRepositoryProvider).sendGCode(command);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('Décalage {} enregistré', [widget.wcs])),
                    backgroundColor: fc.primary,
                  ));
                },
          child: Text(tr('Appliquer')),
        ),
      ],
    );
  }
}
