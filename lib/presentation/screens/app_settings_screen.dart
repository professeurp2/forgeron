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
import '../../core/i18n/app_language.dart';

/// Écran Paramètres — centralise tous les réglages de l'app, jusqu'ici
/// éparpillés : apparence, calibration machine, connexion ESP32, agent IA.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final mode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);

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
          const SizedBox(height: 12),
          // La langue vit ici, à côté du thème : c'est le premier endroit où
          // on la cherche. Enfouie dans les réglages de l'agent IA, elle
          // était introuvable — rien ne laissait deviner qu'elle pilotait
          // aussi toute l'interface.
          _card(
            fc,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.translate_rounded, color: fc.secondary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Langue'),
                            style: TextStyle(
                                color: fc.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(tr('Interface, agent IA, dictée et voix'),
                            style: TextStyle(
                                color: fc.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: language.id,
                  isExpanded: true,
                  dropdownColor: fc.surface,
                  style: TextStyle(color: fc.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fc.background.withValues(alpha: 0.4),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: fc.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: fc.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  items: [
                    for (final l in kAppLanguages)
                      DropdownMenuItem(
                        value: l.id,
                        child:
                            Text(l.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    ref
                        .read(appLanguageProvider.notifier)
                        .select(appLanguageById(id));
                    HapticFeedback.lightImpact();
                  },
                ),
                if (language.lowResource) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fc.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: fc.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.translate, color: fc.warning, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('Langue peu dotée : contrôle la qualité des '
                                'réponses avant de t\'y fier en atelier, et '
                                'préfère Gemini Flash à Flash Lite. La dictée '
                                'et la voix peuvent être absentes de '
                                'l\'appareil — le chat écrit, lui, fonctionne '
                                'toujours.'),
                            style:
                                TextStyle(color: fc.warning, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
