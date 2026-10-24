import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/providers/reco3d_provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';

class Scan3dScreen extends ConsumerStatefulWidget {
  const Scan3dScreen({super.key});

  @override
  ConsumerState<Scan3dScreen> createState() => _Scan3dScreenState();
}

class _Scan3dScreenState extends ConsumerState<Scan3dScreen> {
  final List<File> _selectedPhotos = [];
  String _selectedMode = 'photo'; // 'photo' ou 'gen'
  String _selectedScaleType = 'aruco'; // 'aruco', 'ruler', 'manual_edge', 'none'
  final TextEditingController _scaleController = TextEditingController(text: '50.0');
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(reco3dServerUrlProvider);
  }

  void _updateServerUrl([String? explicitUrl]) {
    final target = (explicitUrl ?? _urlController.text).trim();
    if (target.isNotEmpty) {
      if (explicitUrl != null) {
        _urlController.text = explicitUrl;
      }
      ref.read(reco3dServerUrlProvider.notifier).state = target;
      ref.invalidate(reco3dHealthProvider);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final photo = await _picker.pickImage(source: source);
        if (photo != null) {
          setState(() {
            _selectedPhotos.add(File(photo.path));
          });
        }
      } else {
        final photos = await _picker.pickMultiImage();
        if (photos.isNotEmpty) {
          setState(() {
            _selectedPhotos.addAll(photos.map((p) => File(p.path)));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr("Erreur sélection photo")} : $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _startScan() async {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Veuillez ajouter au moins une photo.'))),
      );
      return;
    }

    final scaleMm = double.tryParse(_scaleController.text);
    if (_selectedScaleType != 'none' && (scaleMm == null || scaleMm <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Veuillez indiquer une dimension de référence valide en mm.'))),
      );
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final scanDir = Directory('${appDir.path}/scans3d');
    if (!scanDir.existsSync()) {
      scanDir.createSync(recursive: true);
    }

    ref.read(reco3dServerUrlProvider.notifier).state = _urlController.text.trim();

    ref.read(reco3dScanProvider.notifier).submitAndProcess(
          photos: _selectedPhotos,
          mode: _selectedMode,
          scaleType: _selectedScaleType,
          scaleMm: scaleMm,
          storageDir: scanDir,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(reco3dScanProvider);
    final healthAsync = ref.watch(reco3dHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Scan 3D — Photo vers Usinage')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('Vérifier état service'),
            onPressed: () => ref.invalidate(reco3dHealthProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Indicateur d'état du service de calcul PC & GPU
            _buildServerHealthCard(healthAsync),
            const SizedBox(height: 16),

            // 2. Choix du mode et consignes opérateur
            _buildModeSelector(),
            const SizedBox(height: 16),

            // 3. Réglage de l'échelle métrique
            _buildScaleSection(),
            const SizedBox(height: 16),

            // 4. Galerie et ajout de photos
            _buildPhotosGallery(),
            const SizedBox(height: 20),

            // 5. Suivi de progression ou bouton de lancement
            if (scanState.isScanning || scanState.stage.isNotEmpty)
              _buildProgressSection(scanState)
            else
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.camera),
                label: Text(
                  tr('Lancer la reconstruction 3D'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: context.fc.primary,
                ),
              ),

            // 6. Résultat et provenance
            if (scanState.isDone) ...[
              const SizedBox(height: 20),
              _buildResultCard(scanState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerHealthCard(AsyncValue healthAsync) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: tr('Adresse PC de calcul (Reco3D)'),
                    hintText: 'http://192.168.0.104:8765',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, size: 18),
                      tooltip: tr('Tester cette adresse'),
                      onPressed: () => _updateServerUrl(),
                    ),
                  ),
                  onSubmitted: (val) => _updateServerUrl(val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          healthAsync.when(
            data: (health) => Row(
              children: [
                Icon(
                  health.status == 'ready' ? Icons.check_circle : Icons.warning,
                  color: health.status == 'ready' ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    health.gpuName != null
                        ? '${health.gpuName} (${health.gpuVramFreeMb ?? 0} Mo VRAM libre)'
                        : tr('GPU non détecté ou indisponible'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            loading: () => const Text('Vérification du service...', style: TextStyle(fontSize: 12)),
            error: (err, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr("Service hors ligne")} : $err',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _updateServerUrl('http://192.168.0.104:8765'),
                  icon: const Icon(Icons.wifi, size: 14),
                  label: const Text('Tester http://192.168.0.104:8765', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Chaîne de reconstruction'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'photo',
                label: Text(tr('Pièce réelle (Mesure)')),
                icon: const Icon(Icons.straighten),
              ),
              ButtonSegment<String>(
                value: 'gen',
                label: Text(tr('Forme concept (Génératif)')),
                icon: const Icon(Icons.auto_awesome),
              ),
            ],
            selected: {_selectedMode},
            onSelectionChanged: (set) {
              setState(() {
                _selectedMode = set.first;
              });
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedMode == 'photo'
                  ? tr('Consignes : 20 à 40 photos en orbite complète. Éclairage diffus, fond neutre. Matifier les métaux polis (talc/spray). Poser une mire.')
                  : tr('Consignes génératives : 1 à 4 croquis ou photos d\'inspiration. La forme sera marquée « approximative ». Cotes réelles à caler manuellement.'),
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleSection() {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Échelle et Cotes Réelles'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedScaleType,
                  decoration: InputDecoration(
                    labelText: tr('Référence'),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'aruco', child: Text(tr('Mire ArUco'))),
                    DropdownMenuItem(value: 'charuco', child: Text(tr('Planche ChArUco'))),
                    DropdownMenuItem(value: 'ruler', child: Text(tr('Réglet gradué'))),
                    DropdownMenuItem(value: 'manual_edge', child: Text(tr('Arête manuelle'))),
                    DropdownMenuItem(value: 'none', child: Text(tr('Sans mire (non mesuré)'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedScaleType = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedScaleType != 'none')
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _scaleController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('Taille (mm)'),
                      isDense: true,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGallery() {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tr("Photos capturées")} (${_selectedPhotos.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    tooltip: tr('Prendre une photo'),
                    onPressed: () => _pickPhotos(ImageSource.camera),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library),
                    tooltip: tr('Importer galerie'),
                    onPressed: () => _pickPhotos(ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPhotos.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  tr('Aucune photo. Cliquez sur l\'appareil pour démarrer la capture.'),
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedPhotos[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Reco3dScanState scanState) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('Progression : {}', [scanState.stage.toUpperCase()]),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${scanState.progressPercent.toInt()} %'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: scanState.progressPercent / 100.0,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(context.fc.primary),
          ),
          const SizedBox(height: 10),
          Text(scanState.message, style: const TextStyle(fontSize: 13)),
          if (scanState.hasError) ...[
            const SizedBox(height: 8),
            Text(
              scanState.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(reco3dScanProvider.notifier).reset(),
              icon: const Icon(Icons.refresh),
              label: Text(tr('Réinitialiser')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(Reco3dScanState scanState) {
    final prov = scanState.provenance;
    final isApprox = prov?.isApproximate ?? true;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                tr('Modèle 3D prêt pour fabrication'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fiche d'honnêteté & provenance
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isApprox ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isApprox ? Colors.amber : Colors.green,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isApprox ? Icons.warning_amber : Icons.verified, size: 18,
                        color: isApprox ? Colors.amber : Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      isApprox ? tr('FORME APPROXIMATIVE') : tr('ÉCHELLE CERTIFIÉE'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isApprox ? Colors.amber : Colors.green,
                      ),
                    ),
                  ],
                ),
                if (prov != null) ...[
                  const SizedBox(height: 6),
                  Text('• Moteur : ${prov.engine} (${prov.engineVersion})', style: const TextStyle(fontSize: 12)),
                  Text('• Échelle : ${prov.hasScaleReference ? "${prov.scaleFactor} mm (${prov.scaleType})" : "Sans mire"}', style: const TextStyle(fontSize: 12)),
                  if (prov.facetsCount != null)
                    Text('• Facettes : ${prov.facetsCount}', style: const TextStyle(fontSize: 12)),
                  for (final note in prov.notes)
                    Text('• $note', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bouton d'action directe vers l'adaptateur de fabrication
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tr('Maillage {} transmis au visualiseur et au CAM.', [scanState.downloadedMeshFile?.path.split('/').last ?? '']),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.precision_manufacturing),
            label: Text(tr('Ouvrir dans l\'adaptateur d\'usinage (CAM)')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
