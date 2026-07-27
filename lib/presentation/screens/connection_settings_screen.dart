import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/responsive_layout.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/forgeron_colors.dart';
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
      backgroundColor: context.fc.success,
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
      backgroundColor: context.fc.success,
      behavior: SnackBarBehavior.floating,
      width: 400,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      backgroundColor: context.fc.background,
      appBar: AppBar(
        backgroundColor: context.fc.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.fc.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.settings_input_component,
                  color: context.fc.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CONNEXION',
                    style: TextStyle(
                      color: context.fc.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Lien ESP32 / FluidNC',
                    style: TextStyle(
                      color: context.fc.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _save,
              icon: Icon(Icons.check_circle, color: context.fc.primary),
              tooltip: 'Appliquer',
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
              context.fc.primary.withValues(alpha: 0.05),
              context.fc.background,
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
                  SizedBox(height: 32),

                  Builder(builder: (context) {
                    if (ResponsiveLayout.isMobile(context)) {
                      return Column(
                        children: [
                          _buildDiscoverySection(discovery),
                          SizedBox(height: 24),
                          _buildManualConfigCard(),
                          SizedBox(height: 24),
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
                        SizedBox(width: 32),

                        // ─── Colonne DROITE (Config Manuelle & Infos) ───
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildManualConfigCard(),
                              SizedBox(height: 24),
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
    final color = isSim ? context.fc.axisA : context.fc.success;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: context.fc.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          Row(
            children: [
              // Globe Icon with pulse
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: isMobile ? 44 : 60,
                        height: isMobile ? 44 : 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(
                                alpha: 1.0 - _pulseController.value),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: isMobile ? 32 : 44,
                    height: isMobile ? 32 : 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isSim ? Icons.science_outlined : Icons.language,
                        color: color, size: isMobile ? 18 : 24),
                  ),
                ],
              ),
              SizedBox(width: isMobile ? 12 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSim ? 'SIMULATION' : 'LIAISON ACTIVE',
                      style: TextStyle(
                        color: color,
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSim ? 'LOCAL DATA' : 'REMOTE WS',
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSim,
                activeColor: context.fc.axisA,
                onChanged: (val) =>
                    ref.read(isSimulationModeProvider.notifier).state = val,
              ),
            ],
          ),
          if (!isMobile) ...[
            const SizedBox(height: 12),
            Text(
              isSim
                  ? 'L\'interface utilise des données virtuelles. Aucune machine physique n\'est requise.'
                  : 'L\'application tente de communiquer avec l\'IP ${ref.watch(espIpProvider)} via WebSocket.',
              style: TextStyle(color: context.fc.textSecondary, fontSize: 12),
            ),
          ]
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
                color: context.fc.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: InkWell(
                onTap: () => ref.read(discoveryProvider.notifier).stop(),
                child: Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.fc.danger),
                    ),
                    SizedBox(width: 8),
                    Text('ARRÊTER', style: TextStyle(color: context.fc.danger, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () => ref.read(discoveryProvider.notifier).scan(),
              icon: Icon(Icons.radar, size: 14),
              label: Text('RECHERCHER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.fc.primary.withValues(alpha: 0.1),
                foregroundColor: context.fc.primary,
                elevation: 0,
                textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discovery.isScanning) ...[
            LinearProgressIndicator(
              value: discovery.progress > 0 ? discovery.progress : null,
              backgroundColor: context.fc.surfaceBorder,
              color: context.fc.primary,
              minHeight: 2,
            ),
            SizedBox(height: 12),
            Text(
              '${discovery.statusMessage ?? "Scan en cours..."}',
              style: TextStyle(color: context.fc.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
          ],

          if (discovery.devices.isEmpty && !discovery.isScanning)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.fc.background.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.fc.surfaceBorder, style: BorderStyle.none),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: context.fc.textDisabled.withValues(alpha: 0.2), size: 64),
                  SizedBox(height: 16),
                  Text('Aucun appareil détecté sur le segment réseau.',
                      style: TextStyle(color: context.fc.textDisabled, fontSize: 12)),
                  SizedBox(height: 8),
                  Text('Vérifiez que l\'ESP32 est allumé et sur le même WiFi.',
                      style: TextStyle(color: context.fc.textDisabled, fontSize: 10)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: discovery.devices.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
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
    final isMobile = ResponsiveLayout.isMobile(context);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.fc.surfaceBright.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFluidNC
                ? context.fc.success.withValues(alpha: 0.3)
                : context.fc.surfaceBorder,
          ),
        ),
        child: isMobile
            ? Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFluidNC ? Icons.precision_manufacturing : Icons.router,
                        color: isFluidNC ? context.fc.success : context.fc.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          device.ip,
                          style: TextStyle(
                            color: context.fc.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ),
                      if (isFluidNC)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.fc.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('FLUIDNC',
                              style: TextStyle(
                                  color: context.fc.success,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _connectDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFluidNC ? context.fc.success : context.fc.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('CONNECTER',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isFluidNC ? context.fc.success : context.fc.primary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFluidNC ? Icons.precision_manufacturing : Icons.router,
                      color: isFluidNC ? context.fc.success : context.fc.primary,
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
                            Flexible(
                              child: Text(
                                device.ip,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.fc.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isFluidNC)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      context.fc.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('FLUIDNC',
                                    style: TextStyle(
                                        color: context.fc.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Réponse: ${device.responseTime.inMilliseconds}ms • Port: ${device.wsPort}',
                          style: TextStyle(
                              color: context.fc.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _connectDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFluidNC ? context.fc.success : context.fc.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CONNECTER',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5)),
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
          SizedBox(height: 20),
          _buildModernField(
            label: 'PORT WEBSOCKET',
            controller: _wsPortCtrl,
            icon: Icons.numbers,
            hint: 'Défaut: 81',
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.network_check_rounded, size: 18),
              label: Text(_testing ? 'VÉRIFICATION...' : 'TESTER LA CONNEXION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.fc.surfaceBright,
                foregroundColor: context.fc.primary,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: context.fc.primary.withValues(alpha: 0.3)),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
            ),
          ),
          if (_testResult != null) ...[
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testSuccess ? context.fc.success : context.fc.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_testSuccess ? context.fc.success : context.fc.error).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_testSuccess ? Icons.check_circle : Icons.error,
                      color: _testSuccess ? context.fc.success : context.fc.error, size: 16),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess ? context.fc.success : context.fc.error,
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
        Text(label, style: TextStyle(color: context.fc.textDisabled, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: context.fc.textPrimary, fontFamily: 'JetBrains Mono', fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: context.fc.textSecondary, size: 18),
            hintText: hint,
            hintStyle: TextStyle(color: context.fc.textDisabled, fontSize: 13),
            filled: true,
            fillColor: context.fc.background.withValues(alpha: 0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fc.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fc.primary, width: 1.5),
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
          _buildInfoRow('Type Cinématique', 'Trunnion 5-Axes (XYZAC)', context.fc.primary),
          SizedBox(height: 12),
          _buildInfoRow('Axe Pivot (A)', '±110° sur X', context.fc.axisA),
          SizedBox(height: 12),
          _buildInfoRow('Table Rotative (C)', '360° Continu sur Z', context.fc.axisC),
          SizedBox(height: 12),
          _buildInfoRow('Taux Télémétrie', '200ms (5Hz)', context.fc.axisZ),
          Divider(height: 32, color: context.fc.surfaceBorder),
          Row(
            children: [
              Icon(Icons.security, color: context.fc.warning, size: 14),
              SizedBox(width: 8),
              Text('ARRET D\'URGENCE LOGICIEL ACTIF',
                  style: TextStyle(color: context.fc.warning, fontSize: 10, fontWeight: FontWeight.bold)),
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
        Text(label, style: TextStyle(color: context.fc.textSecondary, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
      ],
    );
  }
}
