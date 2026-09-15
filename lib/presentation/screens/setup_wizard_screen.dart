import 'package:flutter/material.dart';
import '../../core/widgets/readable_width.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/machine_params_provider.dart';
import '../../domain/models/machine_state.dart';
import '../widgets/dashboard/jog_control_panel.dart';
import 'machine_calibration_screen.dart';
import '../../core/i18n/app_localizations.dart';

/// Assistant de mise en route : guide l'opérateur, étape par étape, pour
/// préparer la machine — zéro machine (homing), vérification cinématique et
/// pose de l'origine pièce (WCS).
class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _step = 0;
  bool _homingLaunched = false;
  bool _homingDone = false;

  static const _titles = [
    'Sécurité',
    'Zéro machine',
    'Cinématique',
    'Origine pièce',
    'Terminé',
  ];

  void _next() {
    if (_step < _titles.length - 1) {
      setState(() => _step++);
      HapticFeedback.selectionClick();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;

    // Détection de la fin du homing (transition Home → Idle).
    ref.listen(machineStateProvider, (prev, next) {
      final s = next.valueOrNull?.status;
      final ps = prev?.valueOrNull?.status;
      if (_homingLaunched &&
          ps == MachineStatus.home &&
          s == MachineStatus.idle) {
        setState(() => _homingDone = true);
      }
    });

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: Text(tr('MISE EN ROUTE'),
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: Column(
        children: [
          _progressBar(fc),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              // Le contenu de l'etape reste dans une colonne lisible ; la
              // barre de progression et le pied, eux, gardent la largeur.
              child: ReadableWidth(child: _stepContent(fc, state)),
            ),
          ),
          _footer(fc),
        ],
      ),
    );
  }

  // ── Barre de progression (points par étape) ────────────────────────────────
  Widget _progressBar(ForgeronColorPalette fc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _titles.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _step ? fc.primary : fc.surfaceBorder,
                ),
              ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _step
                      ? fc.primary
                      : (i == _step
                          ? fc.primary.withValues(alpha: 0.2)
                          : fc.surfaceBright),
                  border: Border.all(
                      color: i <= _step ? fc.primary : fc.surfaceBorder,
                      width: 1.5),
                ),
                child: i < _step
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : Text('${i + 1}',
                        style: TextStyle(
                            color: i == _step ? fc.primary : fc.textDisabled,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _stepContent(ForgeronColorPalette fc, MachineState? state) {
    switch (_step) {
      case 0:
        return _safetyStep(fc, state);
      case 1:
        return _homingStep(fc, state);
      case 2:
        return _kinematicsStep(fc);
      case 3:
        return _originStep(fc, state);
      default:
        return _doneStep(fc);
    }
  }

  Widget _heading(ForgeronColorPalette fc, IconData icon, String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: fc.primary, size: 24),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Text(sub,
            style: TextStyle(color: fc.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Étape 0 : Sécurité / pré-requis ────────────────────────────────────────
  Widget _safetyStep(ForgeronColorPalette fc, MachineState? state) {
    final online = state != null && state.status != MachineStatus.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(fc, Icons.shield_outlined, 'Avant de commencer',
            'Cet assistant prépare la machine en 3 temps : zéro machine, cinématique, origine pièce. Vérifie ces points :'),
        _checkItem(fc, online, 'Machine connectée (ESP32 en ligne)',
            online ? null : 'Hors ligne — vérifie la connexion.'),
        _checkItem(fc, true, 'Zone de travail dégagée (pas d\'obstacle)', null),
        _checkItem(fc, true, 'Arrêt d\'urgence accessible', null),
      ],
    );
  }

  Widget _checkItem(ForgeronColorPalette fc, bool ok, String label, String? warn) {
    final color = ok ? fc.success : fc.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: fc.textPrimary, fontSize: 13)),
            if (warn != null)
              Text(warn, style: TextStyle(color: fc.warning, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── Étape 1 : Homing (zéro machine) ─────────────────────────────────────────
  Widget _homingStep(ForgeronColorPalette fc, MachineState? state) {
    final homing = _homingLaunched && state?.status == MachineStatus.home;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(fc, Icons.home_rounded, 'Zéro machine (homing)',
            'La machine va toucher ses fins de course pour établir sa référence absolue. Étape indispensable avant de poser une origine pièce.'),
        if (_homingDone)
          _statusBox(fc, fc.success, Icons.check_circle_rounded,
              'Homing terminé — le zéro machine est établi.')
        else if (homing)
          _statusBox(fc, fc.primary, null, 'Homing en cours…', spinner: true)
        else
          _bigButton(fc, fc.axisZ, Icons.play_arrow_rounded,
              'LANCER LE HOMING (\$H)', () {
            ref.read(machineRepositoryProvider).home();
            setState(() {
              _homingLaunched = true;
              _homingDone = false;
            });
            HapticFeedback.mediumImpact();
          }),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _homingDone = true),
          child: Text(tr('Ma machine n\'a pas de fins de course — ignorer'),
              style: TextStyle(color: fc.textDisabled, fontSize: 12)),
        ),
      ],
    );
  }

  // ── Étape 2 : Cinématique ───────────────────────────────────────────────────
  Widget _kinematicsStep(ForgeronColorPalette fc) {
    final kin = ref.watch(axisKinematicsProvider).valueOrNull ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(fc, Icons.tune_rounded, 'Cinématique des axes',
            'Vérifie que les dimensions/pas correspondent à ta machine. Sinon, ouvre la calibration pour les ajuster (et les enregistrer dans FluidNC).'),
        if (kin.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fc.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: Column(
              children: [
                for (final k in kin)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 24,
                          child: Text(k.axis,
                              style: TextStyle(
                                  color: fc.primary,
                                  fontWeight: FontWeight.w900))),
                      Expanded(
                        child: Text(
                          tr('course {} mm · {} pas/mm', [
                            k.maxTravel?.toStringAsFixed(0) ?? '—',
                            k.stepsPerMm?.toStringAsFixed(0) ?? '—',
                          ]),
                          style: TextStyle(
                              color: fc.textSecondary,
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono'),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          )
        else
          Text(tr('Cinématique indisponible (machine hors ligne ?).'),
              style: TextStyle(color: fc.textDisabled, fontSize: 12)),
        const SizedBox(height: 16),
        _bigButton(fc, fc.primary, Icons.edit_rounded, 'OUVRIR LA CALIBRATION',
            () {
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const MachineCalibrationScreen()));
        }),
      ],
    );
  }

  // ── Étape 3 : Origine pièce ─────────────────────────────────────────────────
  Widget _originStep(ForgeronColorPalette fc, MachineState? state) {
    final wcs = state?.activeWCS ?? 'G54';
    final wPos = state?.wPos ?? const [0.0, 0.0, 0.0, 0.0, 0.0];
    const wcsList = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59'];
    const labels = ['X', 'Y', 'Z', 'A', 'C'];
    final colors = [fc.axisX, fc.axisY, fc.axisZ, fc.axisA, fc.axisC];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(fc, Icons.gps_fixed_rounded, 'Origine pièce (WCS)',
            'Choisis un système, amène l\'outil au point d\'origine avec le jog, puis pose le zéro (G10 L20).'),
        // Sélecteur WCS
        Wrap(
          spacing: 6,
          children: [
            for (final w in wcsList)
              ChoiceChip(
                label: Text(w),
                selected: w == wcs,
                onSelected: (_) {
                  ref.read(machineRepositoryProvider).sendGCode(w);
                  HapticFeedback.selectionClick();
                },
                selectedColor: fc.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                    color: w == wcs ? fc.primary : fc.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                backgroundColor: fc.surface,
              ),
          ],
        ),
        const SizedBox(height: 16),
        JogControlPanel(wPos: wPos),
        const SizedBox(height: 16),
        Text(tr('DÉFINIR L\'ORIGINE ({}) À LA POSITION ACTUELLE', [wcs]),
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          for (int i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(machineRepositoryProvider)
                      .sendGCode('G10 L20 P0 ${labels[i]}0');
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors[i].withValues(alpha: 0.5)),
                  ),
                  child: Text('${labels[i]}=0',
                      style: TextStyle(
                          color: colors[i],
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          fontFamily: 'JetBrains Mono')),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        _bigButton(fc, fc.primary, Icons.adjust_rounded, 'TOUT METTRE À ZÉRO',
            () {
          ref
              .read(machineRepositoryProvider)
              .sendGCode('G10 L20 P0 X0 Y0 Z0 A0 C0');
          HapticFeedback.mediumImpact();
        }),
      ],
    );
  }

  // ── Étape 4 : Terminé ───────────────────────────────────────────────────────
  Widget _doneStep(ForgeronColorPalette fc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Icon(Icons.check_circle_rounded, color: fc.success, size: 72),
        const SizedBox(height: 16),
        Text(tr('Machine prête'),
            style: TextStyle(
                color: fc.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(
          tr('Zéro machine établi, cinématique vérifiée et origine pièce posée. Tu peux charger un programme et lancer le cycle.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: fc.textSecondary, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  // ── Widgets utilitaires ─────────────────────────────────────────────────────
  Widget _statusBox(ForgeronColorPalette fc, Color color, IconData? icon,
      String text,
      {bool spinner = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        if (spinner)
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color))
        else if (icon != null)
          Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _bigButton(ForgeronColorPalette fc, Color color, IconData icon,
      String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _footer(ForgeronColorPalette fc) {
    final isLast = _step == _titles.length - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: Text(tr('Précédent'),
                  style: TextStyle(color: fc.textSecondary)),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                size: 18),
            label: Text(isLast ? 'TERMINER' : 'SUIVANT',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }
}
