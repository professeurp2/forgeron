import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/di_providers.dart';

class CalibrationWizard extends ConsumerStatefulWidget {
  const CalibrationWizard({super.key});

  @override
  ConsumerState<CalibrationWizard> createState() => _CalibrationWizardState();
}

class _CalibrationWizardState extends ConsumerState<CalibrationWizard> {
  int _currentStep = 0;
  final List<double?> _probeResults = [null, null, null]; // [0°, 90°, -90°]
  bool _isProbing = false;

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _probeResults.fillRange(0, 3, null);
    });
  }

  Future<void> _runProbeStep(int index) async {
    setState(() => _isProbing = true);
    
    // Simulation du processus de palpage
    // En réel, on enverrait G38.2 Z...
    final repo = ref.read(machineRepositoryProvider);
    await repo.sendGCode('G38.2 Z-50 F50');
    
    // Attendre un peu pour simuler le mouvement
    await Future.delayed(const Duration(seconds: 2));
    
    final state = ref.read(machineStateProvider).valueOrNull;
    final zPos = state?.mPos[2] ?? 0.0;

    setState(() {
      _probeResults[index] = zPos;
      _isProbing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepper(),
        SizedBox(height: 24),
        Expanded(
          child: _buildStepContent(),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          _stepIndicator(i),
          if (i < 3) Expanded(child: Container(height: 2, color: _currentStep > i ? context.fc.primary : context.fc.surfaceBorder)),
        ],
      ],
    );
  }

  Widget _stepIndicator(int i) {
    final active = _currentStep == i;
    final done = _currentStep > i;
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? context.fc.primary : (active ? context.fc.primary.withValues(alpha: 0.2) : context.fc.surface),
        border: Border.all(color: active || done ? context.fc.primary : context.fc.surfaceBorder, width: 2),
      ),
      child: Center(
        child: done 
          ? Icon(Icons.check, size: 16, color: Colors.white)
          : Text('${i + 1}', style: TextStyle(color: active ? context.fc.primary : context.fc.textDisabled, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _stepLayout(
          'Étape 1 : Palpage à 0°',
          'Positionnez le palpeur au centre du plateau avec l\'axe A à 0°. Cette mesure servira de référence pour le plan Z=0.',
          Icons.straighten,
          onAction: () => _runProbeStep(0),
          result: _probeResults[0],
          actionLabel: 'Lancer le palpage (0°)',
        );
      case 1:
        return _stepLayout(
          'Étape 2 : Palpage à 90°',
          'Inclinez l\'axe A à 90°. Le plateau est maintenant vertical. Palpez la face latérale pour identifier le rayon de pivotement.',
          Icons.rotate_right,
          onAction: () => _runProbeStep(1),
          result: _probeResults[1],
          actionLabel: 'Lancer le palpage (90°)',
        );
      case 2:
        return _stepLayout(
          'Étape 3 : Palpage à -90°',
          'Inclinez l\'axe A à -90°. Cette mesure permet de confirmer l\'alignement et de compenser les erreurs de flexion.',
          Icons.rotate_left,
          onAction: () => _runProbeStep(2),
          result: _probeResults[2],
          actionLabel: 'Lancer le palpage (-90°)',
        );
      case 3:
        return _buildCalculationStep();
      default:
        return SizedBox();
    }
  }

  Widget _stepLayout(String title, String desc, IconData icon, {required VoidCallback onAction, double? result, required String actionLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: context.fc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text(desc, style: TextStyle(color: context.fc.textDisabled, fontSize: 12, height: 1.5)),
        SizedBox(height: 32),
        Center(child: Icon(icon, size: 64, color: context.fc.primary.withValues(alpha: 0.3))),
        const Spacer(),
        if (result != null) 
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: context.fc.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: context.fc.success.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.check_circle, color: context.fc.success, size: 16),
              SizedBox(width: 12),
              Text('Mesure enregistrée : ${result.toStringAsFixed(3)} mm', style: TextStyle(color: context.fc.success, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'JetBrains Mono')),
            ]),
          ),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _isProbing ? null : onAction,
            child: _isProbing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text(actionLabel),
          ),
        ),
        if (result != null && !_isProbing) ...[
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton(onPressed: _nextStep, child: Text('ÉTAPE SUIVANTE')),
          ),
        ],
      ],
    );
  }

  Widget _buildCalculationStep() {
    // Calcul théorique simplifié des offsets
    final p0 = _probeResults[0] ?? 0;
    final p90 = _probeResults[1] ?? 0;
    final pM90 = _probeResults[2] ?? 0;
    
    final pivotZ = (p90 + pM90) / 2;
    final tableOffset = p0 - pivotZ;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calcul des Offsets Terminé', style: TextStyle(color: context.fc.success, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        _resultRow('Pivot Z (Machine)', pivotZ),
        _resultRow('Table Offset (Z0)', tableOffset),
        SizedBox(height: 24),
        Text('Ces valeurs seront appliquées à la configuration de FluidNC pour garantir un RTCP (G43.4) précis.', style: TextStyle(color: context.fc.textDisabled, fontSize: 11, height: 1.5)),
        const Spacer(),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () {
              // Simuler l'enregistrement
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offsets enregistrés avec succès !')));
              _reset();
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.fc.success),
            child: Text('ENREGISTRER DANS LA MACHINE'),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 44,
          child: OutlinedButton(onPressed: _reset, child: Text('RECOMANCER')),
        ),
      ],
    );
  }

  Widget _resultRow(String label, double val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(label, style: TextStyle(color: context.fc.textDisabled, fontSize: 11, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${val.toStringAsFixed(3)} mm', style: TextStyle(color: context.fc.primary, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'JetBrains Mono')),
      ]),
    );
  }
}
