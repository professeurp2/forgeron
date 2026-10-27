import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/providers/reco3d_provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';

/// Scan EN MACHINE (doc §12) : le maître est bridé, on tourne les axes A/C par
/// angles connus (tourne-table calibré) et on capture avec les caméras
/// embarquées, puis on reconstruit et on usine la reproduction.
///
/// Lancé depuis l'écran de l'agent IA. Le volet simulation est mis de côté :
/// cet écran vise le flux réel. Le backend `/scan` (commande A/C + caméras)
/// reste à brancher côté serveur reco3d (jalon 5) ; en son absence, l'écran le
/// signale honnêtement au lieu de faire semblant.
class MachineScanScreen extends ConsumerStatefulWidget {
  const MachineScanScreen({super.key});

  @override
  ConsumerState<MachineScanScreen> createState() => _MachineScanScreenState();
}

class _MachineScanScreenState extends ConsumerState<MachineScanScreen> {
  // Course de l'axe A — cohérente avec pipeline/kinematics.py et capture.py.
  static const double kAMin = -88.0;
  static const double kAMax = 90.0;

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _cameraCtrl =
      TextEditingController(text: 'http://192.168.0.50/capture');

  int _poses = 12;
  double _aDeg = 0.0;
  bool _discovering = false;
  bool _showCamera = false;

  bool _running = false;
  double _progress = 0.0;
  String _stage = '';
  String _message = '';
  String? _error;
  String? _meshPath;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = ref.read(reco3dServerUrlProvider);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _cameraCtrl.dispose();
    super.dispose();
  }

  bool get _aInCourse => _aDeg >= kAMin && _aDeg <= kAMax;

  Future<void> _discover() async {
    setState(() => _discovering = true);
    try {
      final found = await ref.read(reco3dClientProvider).discoverServer();
      if (found != null) {
        ref.read(reco3dServerUrlProvider.notifier).state = found;
        _urlCtrl.text = found;
        ref.invalidate(reco3dHealthProvider);
      }
    } catch (_) {}
    if (mounted) setState(() => _discovering = false);
  }

  Future<void> _launch() async {
    if (!_aInCourse || _running) return;
    final client = ref.read(reco3dClientProvider);
    final uri = Uri.parse(_urlCtrl.text.trim());
    ref.read(reco3dServerUrlProvider.notifier).state = _urlCtrl.text.trim();

    setState(() {
      _running = true;
      _error = null;
      _meshPath = null;
      _stage = 'start';
      _progress = 2.0;
      _message = tr('Démarrage du scan en machine…');
    });

    try {
      final job = await client.startMachineScan(
        baseUri: uri,
        poses: _poses,
        aDeg: _aDeg,
        cameraUrl: _cameraCtrl.text.trim(),
      );
      setState(() {
        _stage = 'queued';
        _progress = 10.0;
        _message = job.message;
      });

      final done = await client.pollUntilDone(
        uri,
        job.jobId,
        pollInterval: const Duration(milliseconds: 800),
        onProgress: (s) => setState(() {
          _stage = s.stage;
          _progress = s.progressPercent;
          _message = s.message;
        }),
      );

      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/${job.jobId}.stl');
      await client.downloadResult(uri, job.jobId, format: 'mesh', destination: dest);

      if (!mounted) return;
      setState(() {
        _running = false;
        _stage = 'done';
        _progress = 100.0;
        _message = done.message.isNotEmpty
            ? done.message
            : tr('Scan terminé — maillage prêt.');
        _meshPath = dest.path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _stage = 'failed';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final health = ref.watch(reco3dHealthProvider);

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        foregroundColor: fc.textPrimary,
        title: Text(tr('Scan en machine')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _intro(fc),
          const SizedBox(height: 16),
          _section(fc, tr('Poste de calcul (reco3d)'), _serverBlock(fc, health)),
          const SizedBox(height: 16),
          _section(fc, tr('Caméra embarquée'), _cameraBlock(fc)),
          const SizedBox(height: 16),
          _section(fc, tr('Plan de capture (axes A/C)'), _planBlock(fc)),
          const SizedBox(height: 20),
          _launchBlock(fc),
          if (_running || _stage.isNotEmpty) ...[
            const SizedBox(height: 16),
            _progressBlock(fc),
          ],
        ],
      ),
    );
  }

  Widget _intro(ForgeronColorPalette fc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: fc.primary, width: 3)),
      ),
      child: Text(
        tr('Le maître est bridé sur la machine. On tourne les axes A/C par '
            'angles connus (tourne-table calibré) et les caméras capturent, puis '
            'on reconstruit et on usine la reproduction. Pièce marquée '
            '« approximative » tant que l\'échelle n\'est pas certifiée.'),
        style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _section(ForgeronColorPalette fc, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: fc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fc.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fc.surfaceBorder),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _serverBlock(ForgeronColorPalette fc, AsyncValue<dynamic> health) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlCtrl,
                style: TextStyle(color: fc.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'http://192.168.x.x:8765',
                  hintStyle: TextStyle(color: fc.textDisabled),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _discovering
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: tr('Rechercher le serveur'),
                    icon: Icon(Icons.wifi_find_outlined, color: fc.primary),
                    onPressed: _discover,
                  ),
          ],
        ),
        const SizedBox(height: 8),
        health.when(
          data: (h) => _pill(fc, fc.success,
              '${tr('Connecté')} · ${h.status}${h.gpuName != null ? ' · ${h.gpuName}' : ''}'),
          loading: () => _pill(fc, fc.info, tr('Vérification…')),
          error: (e, _) => _pill(fc, fc.danger, tr('Hors ligne — lance une recherche')),
        ),
      ],
    );
  }

  Widget _cameraBlock(ForgeronColorPalette fc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cameraCtrl,
          style: TextStyle(color: fc.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            labelText: tr('URL de capture ESP32-CAM'),
            labelStyle: TextStyle(color: fc.textSecondary),
            hintText: 'http://192.168.0.50/capture',
            hintStyle: TextStyle(color: fc.textDisabled),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(_showCamera ? Icons.visibility_off_outlined : Icons.photo_camera_outlined,
                size: 18, color: fc.primary),
            label: Text(_showCamera ? tr('Masquer l\'aperçu') : tr('Tester la caméra')),
            onPressed: () => setState(() => _showCamera = !_showCamera),
          ),
        ),
        if (_showCamera)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _cameraCtrl.text.trim(),
              height: 160,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => Container(
                height: 160,
                alignment: Alignment.center,
                color: fc.surfaceHigh,
                child: Text(tr('Caméra injoignable sur ce réseau'),
                    style: TextStyle(color: fc.textDisabled, fontSize: 12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _planBlock(ForgeronColorPalette fc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Nombre de poses (rotation C)'),
            style: TextStyle(color: fc.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [8, 12, 16, 24].map((n) {
            final sel = n == _poses;
            return ChoiceChip(
              label: Text('$n'),
              selected: sel,
              onSelected: (_) => setState(() => _poses = n),
              selectedColor: fc.primary,
              labelStyle: TextStyle(color: sel ? fc.background : fc.textPrimary),
              backgroundColor: fc.surfaceHigh,
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(tr('Angle A'), style: TextStyle(color: fc.textSecondary, fontSize: 12)),
            const Spacer(),
            Text('${_aDeg.toStringAsFixed(0)}°',
                style: TextStyle(
                    color: _aInCourse ? fc.axisA : fc.danger,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: _aDeg.clamp(kAMin, kAMax),
          min: kAMin,
          max: kAMax,
          divisions: (kAMax - kAMin).toInt(),
          activeColor: fc.axisA,
          onChanged: (v) => setState(() => _aDeg = v),
        ),
        Text(
          tr('Course A : {} à {}°', [kAMin.toStringAsFixed(0), kAMax.toStringAsFixed(0)]),
          style: TextStyle(color: fc.textDisabled, fontSize: 11),
        ),
      ],
    );
  }

  Widget _launchBlock(ForgeronColorPalette fc) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: fc.primary,
          foregroundColor: fc.background,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _running
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.threed_rotation),
        label: Text(_running
            ? tr('Scan en cours…')
            : tr('Lancer le scan en machine')),
        onPressed: (_running || !_aInCourse) ? null : _launch,
      ),
    );
  }

  Widget _progressBlock(ForgeronColorPalette fc) {
    final isFail = _stage == 'failed';
    final isDone = _stage == 'done';
    final color = isFail ? fc.danger : (isDone ? fc.success : fc.primary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFail)
            LinearProgressIndicator(
              value: isDone ? 1.0 : (_progress / 100.0).clamp(0.0, 1.0),
              backgroundColor: fc.surfaceBorder,
              color: color,
            ),
          const SizedBox(height: 8),
          Text(
            isFail ? (_error ?? tr('Échec du scan')) : _message,
            style: TextStyle(color: isFail ? fc.danger : fc.textSecondary, fontSize: 12),
          ),
          if (isFail && (_error?.contains('/scan') ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _pill(fc, fc.warning,
                  tr('L\'écran et le contrat sont prêts ; le backend de scan machine (jalon 5) reste à brancher sur le serveur reco3d.')),
            ),
          if (isDone && _meshPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(tr('Maillage : {}', [_meshPath!.split(Platform.pathSeparator).last]),
                  style: TextStyle(color: fc.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _pill(ForgeronColorPalette fc, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
