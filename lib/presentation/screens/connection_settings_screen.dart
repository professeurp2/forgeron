import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/responsive_layout.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/discovery_provider.dart';
import '../../application/services/auto_discovery_service.dart';
import '../tutorial/tutorial_keys.dart';

/// Écran de configuration de la connexion à l'ESP32/FluidNC
/// avec une interface moderne, "vivante" et hautement visuelle.
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
              'ESP32 FluidNC détecté à $ip (HTTP ${response.statusCode})';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Erreur serveur HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Non joignable: $e';
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
      behavior: SnackBarBehavior.floating,
      width: 400,
    ));
    Navigator.of(context).pop();
  }

  void _selectDevice(DiscoveredDevice device) {
    _ipCtrl.text = device.ip;
    _wsPortCtrl.text = device.wsPort.toString();
    setState(() {
      _testSuccess = true;
      _testResult =
          '${device.firmwareInfo ?? "ESP32"} sélectionné — ${device.ip}';
    });
  }

  void _connectDevice(DiscoveredDevice device) {
    _ipCtrl.text = device.ip;
    _wsPortCtrl.text = device.wsPort.toString();

    final ip = device.ip;
    final wsPort = device.wsPort;
    ref.read(espIpProvider.notifier).state = ip;
    ref.read(wsPortProvider.notifier).state = wsPort;
    ref.read(isSimulationModeProvider.notifier).state = false;
    saveNetworkPreferences(ref, ip, wsPort);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '✅ Connecté à ${device.firmwareInfo ?? "ESP32"} @ $ip'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      width: 400,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_input_component,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RÉSEAU & CONNEXION',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Configuration du lien ESP32 / FluidNC',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('APPLIQUER'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  // ─── Header Status Card ───
                  _buildHeaderStatus(),
                  const SizedBox(height: 32),

                  Builder(builder: (context) {
                    if (ResponsiveLayout.isMobile(context)) {
                      return Column(
                        children: [
                          _buildDiscoverySection(discovery),
                          const SizedBox(height: 24),
                          _buildManualConfigCard(),
                          const SizedBox(height: 24),
                          _buildMachineInfoCard(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Colonne GAUCHE (Découverte) ───
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildDiscoverySection(discovery),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // ─── Colonne DROITE (Config Manuelle & Infos) ───
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildManualConfigCard(),
                              const SizedBox(height: 24),
                              _buildMachineInfoCard(),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatus() {
    final isSim = ref.watch(isSimulationModeProvider);
    final color = isSim ? AppColors.axisA : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Globe Icon with pulse
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(1.0 - _pulseController.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isSim ? Icons.science_outlined : Icons.language,
                    color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isSim ? 'MODE SIMULATION' : 'LIAISON RÉSEAU ACTIVE',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        isSim ? 'LOCAL' : 'REMOTE',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isSim
                      ? 'L\'interface utilise des données virtuelles. Aucune machine physique n\'est requise.'
                      : 'L\'application tente de communiquer avec l\'IP ${ref.watch(espIpProvider)} via WebSocket.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('TYPE DE SESSION',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Switch(
                value: isSim,
                activeColor: AppColors.axisA,
                activeTrackColor: AppColors.axisA.withOpacity(0.2),
                inactiveThumbColor: AppColors.success,
                inactiveTrackColor: AppColors.success.withOpacity(0.2),
                onChanged: (val) => ref.read(isSimulationModeProvider.notifier).state = val,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection(DiscoveryState discovery) {
    return GlassPanel(
      title: 'SCANNER DE RÉSEAU LOCAL',
      titleTrailing: discovery.isScanning
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: InkWell(
                onTap: () => ref.read(discoveryProvider.notifier).stop(),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                    ),
                    SizedBox(width: 8),
                    Text('ARRÊTER', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () => ref.read(discoveryProvider.notifier).scan(),
              icon: const Icon(Icons.radar, size: 14),
              label: const Text('RECHERCHER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discovery.isScanning) ...[
            LinearProgressIndicator(
              value: discovery.progress > 0 ? discovery.progress : null,
              backgroundColor: AppColors.surfaceBorder,
              color: AppColors.primary,
              minHeight: 2,
            ),
            const SizedBox(height: 12),
            Text(
              '${discovery.statusMessage ?? "Scan en cours..."}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
          ],

          if (discovery.devices.isEmpty && !discovery.isScanning)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder, style: BorderStyle.none),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppColors.textDisabled.withOpacity(0.2), size: 64),
                  const SizedBox(height: 16),
                  const Text('Aucun appareil détecté sur le segment réseau.',
                      style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('Vérifiez que l\'ESP32 est allumé et sur le même WiFi.',
                      style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: discovery.devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = discovery.devices[index];
                return _buildModernDeviceCard(device, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModernDeviceCard(DiscoveredDevice device, int index) {
    final isFluidNC = device.firmwareInfo?.contains('FluidNC') == true;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBright.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFluidNC ? AppColors.success.withOpacity(0.3) : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isFluidNC ? AppColors.success : AppColors.primary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFluidNC ? Icons.precision_manufacturing : Icons.router,
                color: isFluidNC ? AppColors.success : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isFluidNC)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('FLUIDNC',
                              style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Réponse: ${device.responseTime.inMilliseconds}ms • Port: ${device.wsPort}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => _connectDevice(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFluidNC ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('CONNECTER',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualConfigCard() {
    return GlassPanel(
      title: 'CONFIGURATION MANUELLE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernField(
            label: 'ADRESSE IP DESTINATION',
            controller: _ipCtrl,
            icon: Icons.lan_outlined,
            hint: 'ex: 192.168.1.100',
          ),
          const SizedBox(height: 20),
          _buildModernField(
            label: 'PORT WEBSOCKET',
            controller: _wsPortCtrl,
            icon: Icons.numbers,
            hint: 'Défaut: 81',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.network_check_rounded, size: 18),
              label: Text(_testing ? 'VÉRIFICATION...' : 'TESTER LA CONNEXION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceBright,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testSuccess ? AppColors.success : AppColors.error).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_testSuccess ? AppColors.success : AppColors.error).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_testSuccess ? Icons.check_circle : Icons.error,
                      color: _testSuccess ? AppColors.success : AppColors.error, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess ? AppColors.success : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'JetBrains Mono', fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
            filled: true,
            fillColor: AppColors.background.withOpacity(0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMachineInfoCard() {
    return GlassPanel(
      title: 'ARCHITECTURE MACHINE',
      child: Column(
        children: [
          _buildInfoRow('Type Cinématique', 'Trunnion 5-Axes (XYZAC)', AppColors.primary),
          const SizedBox(height: 12),
          _buildInfoRow('Axe Pivot (A)', '±110° sur X', AppColors.axisA),
          const SizedBox(height: 12),
          _buildInfoRow('Table Rotative (C)', '360° Continu sur Z', AppColors.axisC),
          const SizedBox(height: 12),
          _buildInfoRow('Taux Télémétrie', '200ms (5Hz)', AppColors.axisZ),
          const Divider(height: 32, color: AppColors.surfaceBorder),
          const Row(
            children: [
              Icon(Icons.security, color: AppColors.warning, size: 14),
              SizedBox(width: 8),
              Text('ARRET D\'URGENCE LOGICIEL ACTIF',
                  style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
      ],
    );
  }
}
