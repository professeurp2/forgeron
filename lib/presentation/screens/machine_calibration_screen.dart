import 'package:flutter/material.dart';
import '../../core/widgets/readable_width.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/di_providers.dart';
import 'mobile_screens.dart' show KinematicsTable;
import '../../core/i18n/app_localizations.dart';

/// Écran de calibration machine, regroupé dans les Paramètres :
/// cinématique des axes (éditable + enregistrable dans FluidNC), homing
/// (zéro machine) et redémarrage de l'ESP32.
class MachineCalibrationScreen extends ConsumerWidget {
  const MachineCalibrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: Text(tr('CALIBRATION MACHINE'),
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(fc, 'CINÉMATIQUE DES AXES'),
              const SizedBox(height: 8),
              const KinematicsTable(),
              const SizedBox(height: 24),
              _label(fc, 'ZÉRO MACHINE'),
              const SizedBox(height: 8),
              Text(
                tr('Le homing amène la machine sur ses fins de course pour établir la référence absolue (zéro machine). À faire au démarrage, avant de poser une origine pièce.'),
                style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              _bigButton(
                fc,
                color: fc.axisZ,
                icon: Icons.home_rounded,
                label: tr('LANCER LE HOMING (\$H)'),
                onTap: () {
                  ref.read(machineRepositoryProvider).home();
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('Homing lancé — la machine référence ses axes…'))));
                },
              ),
              const SizedBox(height: 24),
              _label(fc, 'CONTRÔLEUR'),
              const SizedBox(height: 8),
              _bigButton(
                fc,
                color: fc.error,
                icon: Icons.power_settings_new_rounded,
                label: tr('REDÉMARRER L\'ESP32'),
                onTap: () => _confirmReboot(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(ForgeronColorPalette fc, String text) => Text(text,
      style: TextStyle(
          color: fc.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5));

  Widget _bigButton(ForgeronColorPalette fc,
      {required Color color,
      required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5)),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmReboot(BuildContext context, WidgetRef ref) async {
    final fc = context.fc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text(tr('Redémarrer l\'ESP32 ?'),
            style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: fc.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('La liaison va être coupée : l\'app se déconnectera quelques secondes, le temps du reboot. La reconnexion est automatique.'),
              style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Annuler'), style: TextStyle(color: fc.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: fc.error, foregroundColor: Colors.white),
            child: Text(tr('Redémarrer')),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(machineRepositoryProvider).sendRaw('\$Bye\n');
      HapticFeedback.heavyImpact();
    }
  }
}
