import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/machine_provider.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// Corrections d'avance et de rapides, réglables **pendant** l'usinage.
///
/// C'est le seul levier qui permet de ralentir une passe en cours sans toucher
/// au fichier ni arrêter le programme. Partagé mobile / desktop : le tableau
/// de bord desktop n'affichait les corrections qu'en lecture seule, et le seul
/// panneau réglable vivait dans le mode atelier.
///
/// La valeur affichée est celle **renvoyée par le contrôleur** (champ `Ov:` du
/// rapport d'état), jamais un compteur local. Deux raisons :
///  - le contrôleur peut refuser ou plafonner une correction ; un compteur
///    local afficherait alors une valeur que la machine n'applique pas ;
///  - les commandes temps réel partent en trame texte, donc encodées UTF-8.
///    Si un octet n'arrivait pas correctement, le nombre affiché ne bougerait
///    pas — le défaut se voit tout de suite au lieu de passer inaperçu.
class OverridePanel extends ConsumerWidget {
  const OverridePanel({super.key, this.dense = false});

  /// Densité desktop : pas de carte ni de titre — le bandeau droit fournit
  /// déjà sa surface et son en-tête de section —, contrôles compacts et
  /// empilés pour tenir dans un rail de 320 dp sans ressembler à une
  /// application de téléphone posée là.
  final bool dense;

  // Commandes temps réel GRBL/FluidNC.
  static const _feedReset = '\x90'; // 100 %
  static const _feedPlus10 = '\x91';
  static const _feedMinus10 = '\x92';
  static const _feedPlus1 = '\x93';
  static const _feedMinus1 = '\x94';
  static const _rapid100 = '\x95';
  static const _rapid50 = '\x96';
  static const _rapid25 = '\x97';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final overrides =
        ref.watch(machineStateProvider).valueOrNull?.overrides ??
            const [100, 100, 100];
    final feed = overrides.isNotEmpty ? overrides[0] : 100;
    final rapid = overrides.length > 1 ? overrides[1] : 100;

    void send(String cmd) {
      HapticFeedback.selectionClick();
      ref.read(machineRepositoryProvider).sendRaw(cmd);
    }

    if (dense) return _dense(context, fc, feed, rapid, send);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.speed_rounded, size: 16, color: fc.primary),
          const SizedBox(width: 8),
          Text(tr('CORRECTIONS'),
              style: TextStyle(
                  color: fc.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 12),

        // ── Avance ────────────────────────────────────────────────────────
        Row(children: [
          SizedBox(
            width: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('AVANCE'),
                    style: TextStyle(
                        color: fc.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                Text('$feed %',
                    style: TextStyle(
                        color: feed == 100 ? fc.textPrimary : fc.warning,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ],
            ),
          ),
          Expanded(
            child: Row(children: [
              _btn(fc, '−10', () => send(_feedMinus10), wide: true),
              const SizedBox(width: 5),
              _btn(fc, '−1', () => send(_feedMinus1)),
              const SizedBox(width: 5),
              _btn(fc, '+1', () => send(_feedPlus1)),
              const SizedBox(width: 5),
              _btn(fc, '+10', () => send(_feedPlus10), wide: true),
            ]),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.restart_alt_rounded,
                size: 20,
                color: feed == 100 ? fc.textDisabled : fc.primary),
            tooltip: tr('Revenir à 100 %'),
            visualDensity: VisualDensity.compact,
            onPressed: feed == 100 ? null : () => send(_feedReset),
          ),
        ]),

        const SizedBox(height: 10),
        Divider(color: fc.surfaceBorderDim, height: 1),
        const SizedBox(height: 10),

        // ── Rapides ───────────────────────────────────────────────────────
        // Trois crans seulement : c'est ce que GRBL expose pour les G0.
        // Utile pour un premier passage en l'air, où l'on veut voir venir.
        Row(children: [
          SizedBox(
            width: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('RAPIDES'),
                    style: TextStyle(
                        color: fc.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                Text('$rapid %',
                    style: TextStyle(
                        color: rapid == 100 ? fc.textPrimary : fc.warning,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'JetBrains Mono')),
              ],
            ),
          ),
          Expanded(
            child: Row(children: [
              _seg(fc, '25 %', rapid == 25, () => send(_rapid25)),
              const SizedBox(width: 5),
              _seg(fc, '50 %', rapid == 50, () => send(_rapid50)),
              const SizedBox(width: 5),
              _seg(fc, '100 %', rapid == 100, () => send(_rapid100)),
            ]),
          ),
        ]),
      ]),
    );
  }

  /// Version desktop : deux lignes « libellé + valeur », les commandes
  /// dessous. Verticale plutôt que côte à côte — dans un rail étroit, la
  /// disposition mobile écrasait les boutons à 30 dp de large.
  Widget _dense(BuildContext context, ForgeronColorPalette fc, int feed,
      int rapid, void Function(String) send) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _denseLabel(fc, 'AVANCE', '$feed %', feed != 100,
          onReset: feed == 100 ? null : () => send(_feedReset)),
      const SizedBox(height: 5),
      Row(children: [
        _denseBtn(fc, '−10', () => send(_feedMinus10)),
        const SizedBox(width: 4),
        _denseBtn(fc, '−1', () => send(_feedMinus1)),
        const SizedBox(width: 4),
        _denseBtn(fc, '+1', () => send(_feedPlus1)),
        const SizedBox(width: 4),
        _denseBtn(fc, '+10', () => send(_feedPlus10)),
      ]),
      const SizedBox(height: 10),
      _denseLabel(fc, 'RAPIDES', '$rapid %', rapid != 100),
      const SizedBox(height: 5),
      Row(children: [
        _denseBtn(fc, '25', () => send(_rapid25), selected: rapid == 25),
        const SizedBox(width: 4),
        _denseBtn(fc, '50', () => send(_rapid50), selected: rapid == 50),
        const SizedBox(width: 4),
        _denseBtn(fc, '100', () => send(_rapid100), selected: rapid == 100),
      ]),
    ]);
  }

  Widget _denseLabel(
      ForgeronColorPalette fc, String label, String value, bool modified,
      {VoidCallback? onReset}) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              color: fc.textDisabled,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              color: modified ? fc.warning : fc.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'JetBrains Mono')),
      if (onReset != null)
        SizedBox(
          width: 22,
          height: 18,
          child: IconButton(
            icon: Icon(Icons.restart_alt_rounded, size: 14, color: fc.primary),
            tooltip: tr('Revenir à 100 %'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onReset,
          ),
        )
      else
        const SizedBox(width: 22),
    ]);
  }

  Widget _denseBtn(ForgeronColorPalette fc, String label, VoidCallback onTap,
      {bool selected = false}) {
    return Expanded(
      child: Material(
        color: selected ? fc.primary.withValues(alpha: 0.18) : fc.surfaceBright,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: selected ? fc.primary : fc.surfaceBorder),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? fc.primary : fc.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'JetBrains Mono')),
          ),
        ),
      ),
    );
  }

  Widget _btn(ForgeronColorPalette fc, String label, VoidCallback onTap,
      {bool wide = false}) {
    return Expanded(
      flex: wide ? 5 : 4,
      child: Material(
        color: fc.surfaceBright,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: Text(label,
                style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  Widget _seg(
      ForgeronColorPalette fc, String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: selected ? fc.primary.withValues(alpha: 0.18) : fc.surfaceBright,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: selected ? fc.primary : fc.surfaceBorder),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? fc.primary : fc.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
