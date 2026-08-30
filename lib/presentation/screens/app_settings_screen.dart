import 'package:flutter/material.dart';
import '../../core/widgets/readable_width.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/theme_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import 'machine_calibration_screen.dart';
import 'setup_wizard_screen.dart';
import 'limit_switch_test_screen.dart';
import 'limit_config_screen.dart';
import 'connection_settings_screen.dart';
import 'ai_agent_settings_screen.dart';
import '../../core/i18n/app_localizations.dart';

/// Écran Paramètres — centralise tous les réglages de l'app, jusqu'ici
/// éparpillés : apparence, calibration machine, connexion ESP32, agent IA.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: Text(tr('PARAMÈTRES'),
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      // Les réglages restent dans une colonne de largeur lisible. Étirée sur
      // 1280 dp, chaque ligne mettait son libellé à un bout et son chevron à
      // l'autre : une liste de téléphone tirée à la largeur d'un écran.
      body: ReadableWidth(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(fc, 'APPARENCE'),
          _card(
            fc,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(themeModeIcon(mode), color: fc.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Thème'),
                          style: TextStyle(
                              color: fc.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        mode == ThemeMode.system
                            ? 'Suit le réglage clair/sombre du système.'
                            : 'Forcé en ${themeModeLabel(mode).toLowerCase()}, '
                                'quel que soit l\'appareil.',
                        style: TextStyle(color: fc.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Trois choix et non un interrupteur : « Système » est un état à
              // part entière, pas un entre-deux entre clair et sombre.
              Row(
                children: [
                  for (final m in ThemeMode.values) ...[
                    Expanded(
                      child: Material(
                        color: m == mode
                            ? fc.primary.withValues(alpha: 0.18)
                            : fc.surfaceBright,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ref.read(themeModeProvider.notifier).set(m);
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: m == mode
                                      ? fc.primary
                                      : fc.surfaceBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(themeModeIcon(m),
                                    size: 15,
                                    color: m == mode
                                        ? fc.primary
                                        : fc.textDisabled),
                                const SizedBox(width: 6),
                                Text(themeModeLabel(m),
                                    style: TextStyle(
                                        color: m == mode
                                            ? fc.primary
                                            : fc.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (m != ThemeMode.values.last) const SizedBox(width: 6),
                  ],
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _sectionLabel(fc, 'MACHINE'),
          _navTile(
            context,
            fc,
            icon: Icons.auto_fix_high_rounded,
            color: fc.warning,
            title: tr('Assistant de mise en route'),
            subtitle: 'Homing → cinématique → origine pièce, guidé',
            screen: const SetupWizardScreen(),
          ),
          _navTile(
            context,
            fc,
            icon: Icons.tune_rounded,
            color: fc.primary,
            title: tr('Calibration machine'),
            subtitle: 'Cinématique des axes, homing, redémarrage ESP32',
            screen: const MachineCalibrationScreen(),
          ),
          _navTile(
            context,
            fc,
            icon: Icons.sensors_rounded,
            color: fc.axisZ,
            title: tr('Test des fins de course'),
            subtitle: 'Vérifie le câblage : presse chaque switch, vois l\'axe',
            screen: const LimitSwitchTestScreen(),
          ),
          _navTile(
            context,
            fc,
            icon: Icons.settings_input_component_rounded,
            color: fc.danger,
            title: tr('Fins de course — config'),
            subtitle: 'Pins, hard limits, soft limits (écrit dans FluidNC)',
            screen: const LimitConfigScreen(),
          ),
          _navTile(
            context,
            fc,
            icon: Icons.wifi_rounded,
            color: fc.success,
            title: tr('Connexion ESP32'),
            subtitle: 'Adresse de la carte, mode simulation, reconnexion',
            screen: const ConnectionSettingsScreen(),
          ),

          // Le mode atelier n'est pas une route mais un basculement de tout
          // l'affichage : on lève le drapeau puis on referme les paramètres
          // pour laisser voir le tableau de bord qui vient de changer de forme.
          _actionTile(
            context,
            fc,
            icon: Icons.factory_rounded,
            color: fc.primary,
            title: tr('Mode atelier'),
            subtitle: 'Affichage plein écran pour le poste de travail',
            onTap: () {
              ref.read(isWorkshopModeProvider.notifier).state = true;
              Navigator.of(context).pop();
            },
          ),

          const SizedBox(height: 20),
          _sectionLabel(fc, 'ASSISTANT'),
          _navTile(
            context,
            fc,
            icon: Icons.smart_toy_outlined,
            color: fc.secondary,
            title: tr('Agent IA'),
            subtitle: 'Clé API, modèle, permissions, voix',
            screen: const AiAgentSettingsScreen(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ForgeronColorPalette fc, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
      );

  Widget _card(ForgeronColorPalette fc, {required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: child,
      );

  /// Meme presentation que [_navTile], mais pour une action qui n'ouvre pas
  /// d'ecran. Deleguer a un rappel evite de faire passer un faux ecran juste
  /// pour reutiliser la mise en forme.
  Widget _actionTile(
    BuildContext context,
    ForgeronColorPalette fc, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      _tile(fc,
          icon: icon,
          color: color,
          title: title,
          subtitle: subtitle,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          });

  Widget _navTile(
    BuildContext context,
    ForgeronColorPalette fc, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) =>
      _tile(fc,
          icon: icon,
          color: color,
          title: title,
          subtitle: subtitle,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => screen));
          });

  Widget _tile(
    ForgeronColorPalette fc, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: fc.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(color: fc.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fc.textDisabled, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
