import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/discovery_provider.dart';
import '../../application/services/auto_discovery_service.dart';
import '../tutorial/tutorial_keys.dart';

/// Écran de configuration de la connexion à l'ESP32/FluidNC
/// avec découverte automatique du réseau local.
class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});
  @override
  ConsumerState<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState
    extends ConsumerState<ConnectionSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _ipCtrl;
  late TextEditingController _wsPortCtrl;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: ref.read(espIpProvider));
    _wsPortCtrl =
        TextEditingController(text: ref.read(wsPortProvider).toString());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Lancer le scan automatiquement à l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).scan();
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _wsPortCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_wsPortCtrl.text.trim()) ?? 81;

    try {
      final uri = Uri.parse('http://$ip/');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 500) {
        setState(() {
          _testSuccess = true;
          _testResult =
              '✅ ESP32 FluidNC détecté à $ip:$port (HTTP ${response.statusCode})';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = '❌ Erreur serveur HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '❌ Non joignable: $e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  void _save() {
    final ip = _ipCtrl.text.trim();
    final wsPort = int.tryParse(_wsPortCtrl.text.trim()) ?? 81;
    saveNetworkPreferences(ref, ip, wsPort);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Connexion configurée: ws://$ip:$wsPort'),
      backgroundColor: AppColors.success,
    ));
    Navigator.of(context).pop();
  }

  void _selectDevice(DiscoveredDevice device) {
    _ipCtrl.text = device.ip;
    _wsPortCtrl.text = device.wsPort.toString();
    setState(() {
      _testSuccess = true;
      _testResult =
          '✅ ${device.firmwareInfo ?? "ESP32"} détecté à ${device.ip} (${device.responseTime.inMilliseconds}ms)';
    });
  }

  void _connectDevice(DiscoveredDevice device) {
    _ipCtrl.text = device.ip;
    _wsPortCtrl.text = device.wsPort.toString();

    // Sauvegarder et basculer en mode production
    final ip = device.ip;
    final wsPort = device.wsPort;
    ref.read(espIpProvider.notifier).state = ip;
    ref.read(wsPortProvider.notifier).state = wsPort;
    ref.read(isSimulationModeProvider.notifier).state = false;
    saveNetworkPreferences(ref, ip, wsPort);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '✅ Connecté à ${device.firmwareInfo ?? "ESP32"} @ $ip — Mode Production activé'),
      backgroundColor: AppColors.success,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'CONNEXION FORGERON — ESP32/FluidNC',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('SAUVEGARDER'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
            ),
            onPressed: _save,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badge mode ─────────────────────────────────────
                _buildModeBadge(ref),
                const SizedBox(height: 24),

                // ══════════════════════════════════════════════════
                // SECTION DÉCOUVERTE AUTOMATIQUE
                // ══════════════════════════════════════════════════
                _buildDiscoverySection(discovery),
                const SizedBox(height: 32),

                // ── Paramètres réseau manuels ─────────────────────
                _SectionTitle('CONFIGURATION MANUELLE'),
                const SizedBox(height: 12),
                _SettingsCard(
                  key: TutorialKeys.networkConfig,
                  children: [
                  _Field(
                    label: 'Adresse IP de l\'ESP32',
                    hint: '192.168.1.100',
                    controller: _ipCtrl,
                    icon: Icons.router,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Port WebSocket (défaut: 80)',
                    hint: '80',
                    controller: _wsPortCtrl,
                    icon: Icons.cable,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // URLs déduites
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Connexions déduites',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        _InfoRow('WebSocket',
                            'ws://${_ipCtrl.text}:${_wsPortCtrl.text}',
                            AppColors.primary),
                        const SizedBox(height: 4),
                        _InfoRow('HTTP REST',
                            'http://${_ipCtrl.text}:80', AppColors.axisZ),
                        const SizedBox(height: 4),
                        _InfoRow('Fichiers',
                            'http://${_ipCtrl.text}/files', AppColors.axisY),
                        const SizedBox(height: 4),
                        _InfoRow('Config',
                            'http://${_ipCtrl.text}/config', AppColors.axisA),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // ── Test de connexion ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background))
                        : const Icon(Icons.wifi_tethering, size: 16),
                    label: Text(_testing
                        ? 'Test en cours...'
                        : 'TESTER LA CONNEXION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                    onPressed: _testing ? null : _testConnection,
                  ),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            _testSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color:
                            _testSuccess ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                // ── Axes machine ──────────────────────────────────
                _SectionTitle('MACHINE CNC 5-AXES — TRUNNION'),
                const SizedBox(height: 12),
                _SettingsCard(children: [
                  for (final row in [
                    ('Axe X', 'Linéaire', 'mm'),
                    ('Axe Y', 'Linéaire', 'mm'),
                    ('Axe Z', 'Linéaire', 'mm'),
                    ('Axe A', 'Rotatif — Basculement broche', '°'),
                    ('Axe C', 'Rotatif — Rotation plateau', '°'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                _axisColor(row.$1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              row.$1.replaceAll('Axe ', ''),
                              style: TextStyle(
                                color: _axisColor(row.$1),
                                fontWeight: FontWeight.w900,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(row.$2,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBright,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(row.$3,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontFamily: 'JetBrains Mono')),
                        ),
                      ]),
                    ),
                ]),

                const SizedBox(height: 32),
                // ── Protocole FluidNC ─────────────────────────────
                _SectionTitle('PROTOCOLE FLUIDNC'),
                const SizedBox(height: 12),
                _SettingsCard(children: [
                  for (final e in [
                    ('Firmware', 'FluidNC v3.7+', AppColors.primary),
                    ('État', 'Interrogation toutes les 200ms', AppColors.axisZ),
                    ('URGENCE', '0x18 (Ctrl+X) via WS', AppColors.danger),
                    ('Jog annuler', '0x85 via WS', AppColors.axisA),
                    ('G-Code SD', '\$SD/Run=filename', AppColors.success),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Text(e.$1,
                            style: const TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                        const Spacer(),
                        Text(e.$2,
                            style: TextStyle(
                                color: e.$3,
                                fontSize: 10,
                                fontFamily: 'JetBrains Mono',
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET DÉCOUVERTE AUTOMATIQUE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDiscoverySection(DiscoveryState discovery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre avec bouton scan
        Row(
          children: [
            const Icon(Icons.radar, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            const _SectionTitle('DÉCOUVERTE AUTOMATIQUE'),
            const Spacer(),
            if (discovery.isScanning)
              TextButton.icon(
                icon: const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.danger,
                  ),
                ),
                label: const Text('ARRÊTER'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  textStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900),
                ),
                onPressed: () => ref.read(discoveryProvider.notifier).stop(),
              )
            else
              TextButton.icon(
                key: TutorialKeys.scannerBtn,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('SCANNER'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900),
                ),
                onPressed: () => ref.read(discoveryProvider.notifier).scan(),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Barre de progression
        if (discovery.isScanning) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: discovery.progress > 0 ? discovery.progress : null,
              backgroundColor: AppColors.surfaceBorder,
              color: AppColors.primary,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            discovery.statusMessage ?? 'Scan en cours...',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Liste des appareils découverts
        if (discovery.devices.isNotEmpty)
          ...discovery.devices.map((device) => _buildDeviceCard(device)),

        // Message si rien trouvé (scan terminé)
        if (!discovery.isScanning && discovery.devices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.surfaceBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.wifi_find,
                    size: 32,
                    color: AppColors.textDisabled.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(
                  discovery.statusMessage ?? 'Appuyez sur SCANNER pour chercher l\'ESP32',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    final isFluidNC = device.firmwareInfo?.contains('FluidNC') == true ||
        device.firmwareInfo?.contains('GRBL') == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glow = isFluidNC ? _pulseController.value * 0.15 : 0.0;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFluidNC
                    ? AppColors.success.withValues(alpha: 0.6 + glow)
                    : AppColors.surfaceBorder,
                width: isFluidNC ? 1.5 : 1,
              ),
              boxShadow: isFluidNC
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.08 + glow * 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Icône statut
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isFluidNC ? AppColors.success : AppColors.axisZ)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFluidNC ? Icons.developer_board : Icons.device_hub,
                    color: isFluidNC ? AppColors.success : AppColors.axisZ,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.ip,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (isFluidNC
                                      ? AppColors.success
                                      : AppColors.textSecondary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              device.firmwareInfo ?? 'HTTP',
                              style: TextStyle(
                                color: isFluidNC
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Réponse: ${device.responseTime.inMilliseconds}ms — Port WS: ${device.wsPort}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // Boutons d'action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton Sélectionner (remplir les champs)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      tooltip: 'Remplir les champs',
                      color: AppColors.textSecondary,
                      onPressed: () => _selectDevice(device),
                    ),
                    // Bouton Connecter (direct)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bolt, size: 14),
                      label: const Text('CONNECTER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFluidNC
                            ? AppColors.success
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () => _connectDevice(device),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _axisColor(String axis) {
    if (axis.contains('X')) return AppColors.axisX;
    if (axis.contains('Y')) return AppColors.axisY;
    if (axis.contains('Z')) return AppColors.axisZ;
    if (axis.contains('A')) return AppColors.axisA;
    return AppColors.axisC;
  }

  Widget _buildModeBadge(WidgetRef ref) {
    final isSim = ref.watch(isSimulationModeProvider);
    final color = isSim ? AppColors.axisA : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(isSim ? Icons.science : Icons.settings_ethernet,
            color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isSim
                        ? 'MODE SIMULATION — MOCK MACHINE'
                        : 'MODE PRODUCTION — ESP32 FluidNC',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(
                    isSim
                        ? 'Utilisation d\'un simulateur logiciel pour tester l\'interface sans machine.'
                        : 'Connexion WebSocket temps réel vers le contrôleur CNC 5-axes.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
        ),
        Switch(
          value: isSim,
          activeColor: AppColors.axisA,
          onChanged: (val) {
            ref.read(isSimulationModeProvider.notifier).state = val;
          },
        ),
      ]),
    );
  }
}

// ── Widgets utilitaires ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'JetBrains Mono',
            fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.surfaceBright,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$label: ',
            style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono',
                  overflow: TextOverflow.ellipsis)),
        ),
      ]);
}

