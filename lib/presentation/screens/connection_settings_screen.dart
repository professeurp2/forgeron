import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/responsive_layout.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/camera_provider.dart';
import '../../application/providers/discovery_provider.dart';
import '../../application/services/auto_discovery_service.dart';
import '../../core/net/esp_wifi_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tutorial/tutorial_keys.dart';
import '../../core/i18n/app_localizations.dart';

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

  // Connexion assistée à l'AP WiFi de l'ESP32.
  // SSID du point d'accès porté par l'ESP32 FluidNC de la machine.
  final _ssidCtrl = TextEditingController(text: 'FORGERON');
  final _pwdCtrl = TextEditingController(text: '00000001');
  bool _wifiConnecting = false;
  String? _wifiMsg;
  bool _wifiOk = false;

  // Caméra de surveillance (ESP32-CAM), second client de l'AP de la machine.
  // Aucun état local de test : la détection est automatique et son état vit
  // dans `cameraDetectionProvider`.
  late TextEditingController _camIpCtrl;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: ref.read(espIpProvider));
    _wsPortCtrl =
        TextEditingController(text: ref.read(wsPortProvider).toString());
    _camIpCtrl = TextEditingController(text: ref.read(cameraIpProvider));
    _loadWifiPrefs();
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
    _ssidCtrl.dispose();
    _pwdCtrl.dispose();
    _camIpCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ssid = prefs.getString('esp_ap_ssid');
      final pwd = prefs.getString('esp_ap_pwd');
      if (!mounted) return;
      setState(() {
        if (ssid != null && ssid.isNotEmpty) _ssidCtrl.text = ssid;
        if (pwd != null) _pwdCtrl.text = pwd;
      });
    } catch (_) {}
  }

  Future<void> _connectWifi() async {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) {
      setState(() => _wifiMsg = 'Renseigne le SSID de l\'AP ESP32.');
      return;
    }
    setState(() {
      _wifiConnecting = true;
      _wifiMsg = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp_ap_ssid', ssid);
      await prefs.setString('esp_ap_pwd', _pwdCtrl.text);
      final ok = await EspWifiService.connect(ssid, _pwdCtrl.text);
      if (!mounted) return;
      setState(() {
        _wifiOk = ok;
        _wifiMsg = ok
            ? 'Connecté à $ssid. Reconnexion auto après un reboot.'
            : 'Connexion non établie.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _wifiOk = false;
          _wifiMsg = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _wifiConnecting = false);
    }
  }

  Future<void> _disconnectWifi() async {
    await EspWifiService.disconnect();
    if (mounted) {
      setState(() {
        _wifiOk = false;
        _wifiMsg = 'Détaché de l\'AP ESP32.';
      });
    }
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
          tr('✅ Connecté à {} @ {}',
              [device.firmwareInfo ?? 'ESP32', ip])),
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
                    tr('CONNEXION'),
                    style: TextStyle(
                      color: context.fc.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    tr('Lien ESP32 / FluidNC'),
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
              tooltip: tr('Appliquer'),
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

                  if (EspWifiService.isSupported) ...[
                    _buildWifiCard(),
                    SizedBox(height: 24),
                  ],
                  Builder(builder: (context) {
                    if (ResponsiveLayout.isMobile(context)) {
                      return Column(
                        children: [
                          _buildDiscoverySection(discovery),
                          SizedBox(height: 24),
                          _buildManualConfigCard(),
                          SizedBox(height: 24),
                          _buildCameraCard(),
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
                              _buildCameraCard(),
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

  Widget _buildWifiCard() {
    final fc = context.fc;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: fc.textDisabled, fontSize: 12),
          filled: true,
          fillColor: fc.background.withValues(alpha: 0.4),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: fc.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: fc.primary, width: 1.5),
          ),
        );

    return GlassPanel(
      title: tr('CONNEXION WIFI ESP32'),
      borderColor: fc.surfaceBorder,
      backgroundColor: fc.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Rejoins le point d\'accès de l\'ESP32 directement depuis l\'app. Android demandera d\'approuver la première fois ; ensuite la reconnexion est automatique (même après un reboot).'),
            style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ssidCtrl,
            style: TextStyle(color: fc.textPrimary, fontSize: 14),
            decoration: deco('SSID de l\'AP ESP32'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pwdCtrl,
            obscureText: true,
            style: TextStyle(color: fc.textPrimary, fontSize: 14),
            decoration: deco('Mot de passe'),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _wifiConnecting ? null : _connectWifi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: fc.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(
                    _wifiConnecting ? Icons.hourglass_top_rounded : Icons.wifi,
                    size: 18),
                label: Text(
                    _wifiConnecting ? 'CONNEXION…' : 'SE CONNECTER À L\'ESP32',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _disconnectWifi,
              style: OutlinedButton.styleFrom(
                foregroundColor: fc.textSecondary,
                side: BorderSide(color: fc.surfaceBorder),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              ),
              child: const Icon(Icons.wifi_off, size: 18),
            ),
          ]),
          if (_wifiMsg != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(_wifiOk ? Icons.check_circle : Icons.info_outline,
                  size: 14, color: _wifiOk ? fc.success : fc.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_wifiMsg!,
                    style: TextStyle(
                        color: _wifiOk ? fc.success : fc.warning, fontSize: 11)),
              ),
            ]),
          ],
        ],
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
      title: tr('SCANNER DE RÉSEAU LOCAL'),
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
                    Text(tr('ARRÊTER'), style: TextStyle(color: context.fc.danger, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () => ref.read(discoveryProvider.notifier).scan(),
              icon: Icon(Icons.radar, size: 14),
              label: Text(tr('RECHERCHER')),
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
                  Text(tr('Aucun appareil détecté sur le segment réseau.'),
                      style: TextStyle(color: context.fc.textDisabled, fontSize: 12)),
                  SizedBox(height: 8),
                  Text(tr('Vérifiez que l\'ESP32 est allumé et sur le même WiFi.'),
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
                          child: Text(tr('FLUIDNC'),
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
                      child: Text(tr('CONNECTER'),
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
                                child: Text(tr('FLUIDNC'),
                                    style: TextStyle(
                                        color: context.fc.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Réponse: {}ms • Port: {}', [device.responseTime.inMilliseconds, device.wsPort]),
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
                    child: Text(tr('CONNECTER'),
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
      title: tr('CONFIGURATION MANUELLE'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernField(
            label: tr('ADRESSE IP DESTINATION'),
            controller: _ipCtrl,
            icon: Icons.lan_outlined,
            hint: 'ex: 192.168.1.100',
          ),
          SizedBox(height: 20),
          _buildModernField(
            label: tr('PORT WEBSOCKET'),
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

  // ── Caméra de surveillance ────────────────────────────────────────────────

  /// Relance la recherche. Bouton de dépannage uniquement : en fonctionnement
  /// normal la détection est automatique et l'opérateur n'ouvre jamais cette
  /// carte.
  Future<void> _searchCamera() async {
    await saveCameraIp(ref, _camIpCtrl.text);
  }

  Widget _buildCameraCard() {
    final detection = ref.watch(cameraDetectionProvider);

    final (Color tone, IconData glyph, String label) = switch (detection.status) {
      CameraStatus.found => (
          context.fc.success,
          Icons.videocam,
          'CAMÉRA DÉTECTÉE'
        ),
      CameraStatus.searching => (
          context.fc.info,
          Icons.search,
          'RECHERCHE EN COURS…'
        ),
      CameraStatus.absent => (
          context.fc.textDisabled,
          Icons.videocam_off_outlined,
          'AUCUNE CAMÉRA'
        ),
    };

    return GlassPanel(
      title: tr('CAMÉRA DE SURVEILLANCE'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tone.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detection.status == CameraStatus.searching)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: tone),
                  )
                else
                  Icon(glyph, color: tone, size: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: tone,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2)),
                      if (detection.status == CameraStatus.found) ...[
                        SizedBox(height: 3),
                        Text(
                          tr('{} — le panneau du visualiseur affiche la vue réelle.', [ref.watch(cameraIpProvider)]),
                          style: TextStyle(
                              color: context.fc.textSecondary, fontSize: 11),
                        ),
                      ] else if (detection.reason != null) ...[
                        SizedBox(height: 3),
                        Text(detection.reason!,
                            style: TextStyle(
                                color: context.fc.textSecondary, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.fc.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.fc.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: context.fc.info, size: 15),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Rien à configurer : connectez-vous au WiFi de la machine, la caméra est trouvée toute seule. Elle partage ce réseau avec le contrôleur, la cadence des images est donc réduite pendant un usinage pour laisser passer le G-code.'),
                    style: TextStyle(
                        color: context.fc.textSecondary,
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Repli manuel : utile seulement si la caméra a été reprogrammée sur
          // une autre adresse que son IP statique d'usine.
          SizedBox(height: 20),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(tr('ADRESSE MANUELLE'),
                style: TextStyle(
                    color: context.fc.textDisabled,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
            children: [
              _buildModernField(
                label: tr('ADRESSE IP DE LA CAMÉRA'),
                controller: _camIpCtrl,
                icon: Icons.photo_camera_outlined,
                hint: 'ex: $kDefaultCameraIp',
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: detection.status == CameraStatus.searching
                      ? null
                      : _searchCamera,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text(tr('RELANCER LA RECHERCHE')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fc.surfaceBright,
                    foregroundColor: context.fc.primary,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: context.fc.primary.withValues(alpha: 0.3)),
                    ),
                    textStyle: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMachineInfoCard() {
    return GlassPanel(
      title: tr('ARCHITECTURE MACHINE'),
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
              Text(tr('ARRET D\'URGENCE LOGICIEL ACTIF'),
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
