import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/providers/ai_agent_provider.dart';
import '../../application/providers/ai_artifacts_provider.dart';
import '../../application/providers/medical_implant_provider.dart';
import '../../application/providers/reco3d_provider.dart';
import '../../application/services/medical_implant_service.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/medical_material.dart';
import 'ai_assistant_screen.dart';
import 'main_scaffold.dart' show selectedNavIndexProvider;

class Scan3dScreen extends ConsumerStatefulWidget {
  const Scan3dScreen({super.key});

  @override
  ConsumerState<Scan3dScreen> createState() => _Scan3dScreenState();
}

class _Scan3dScreenState extends ConsumerState<Scan3dScreen> {
  List<File> get _selectedPhotos => ref.watch(reco3dPhotosProvider);
  String get _selectedMode => ref.watch(reco3dSelectedModeProvider);

  String _selectedScaleType = 'aruco'; // 'aruco', 'ruler', 'manual_edge', 'none'
  final TextEditingController _scaleController = TextEditingController(text: '50.0');
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _medLotController =
      TextEditingController(text: 'LOT-MED-2026-01');
  final TextEditingController _medPatientController =
      TextEditingController(text: 'CAS-ANONYME-01');
  final TextEditingController _medTargetLengthController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(reco3dServerUrlProvider);
    _checkLostData();
    _markScreenActive(true);
  }

  Future<void> _markScreenActive(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (active) {
        await prefs.setBool('on_scan3d_screen', true);
      } else {
        await prefs.remove('on_scan3d_screen');
      }
    } catch (_) {}
  }

  Future<void> _checkLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final file = File(response.file!.path);
        ref.read(reco3dPhotosProvider.notifier).update((list) {
          if (!list.any((f) => f.path == file.path)) {
            return [...list, file];
          }
          return list;
        });
      } else if (response.files != null) {
        final files = response.files!.map((f) => File(f.path)).toList();
        ref.read(reco3dPhotosProvider.notifier).update((list) {
          final updated = List<File>.from(list);
          for (final f in files) {
            if (!updated.any((existing) => existing.path == f.path)) {
              updated.add(f);
            }
          }
          return updated;
        });
      }
    } catch (e) {
      debugPrint('[Scan3D] Récupération photos perdues : $e');
    }
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

  Future<void> _autoDiscoverServer() async {
    setState(() => _isDiscovering = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Recherche automatique du PC sur le réseau...'))),
    );
    try {
      final client = ref.read(reco3dClientProvider);
      final foundUrl = await client.discoverServer();
      if (foundUrl != null) {
        _updateServerUrl(foundUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Text('${tr("PC de calcul détecté :")} $foundUrl'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange.shade800,
              content: Text(tr('Aucun PC trouvé. Vérifiez que le PC et le téléphone sont sur le même Wi-Fi.')),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr("Erreur détection :")} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  @override
  void dispose() {
    _markScreenActive(false);
    _scaleController.dispose();
    _urlController.dispose();
    _medLotController.dispose();
    _medPatientController.dispose();
    _medTargetLengthController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    try {
      await _markScreenActive(true);
      if (source == ImageSource.camera) {
        final photo = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (photo != null) {
          final file = File(photo.path);
          ref.read(reco3dPhotosProvider.notifier).update((list) => [...list, file]);
        }
      } else {
        final photos = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (photos.isNotEmpty) {
          final files = photos.map((p) => File(p.path)).toList();
          ref.read(reco3dPhotosProvider.notifier).update((list) => [...list, ...files]);
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
    ref.read(reco3dPhotosProvider.notifier).update((list) {
      final updated = List<File>.from(list);
      if (index >= 0 && index < updated.length) {
        updated.removeAt(index);
      }
      return updated;
    });
  }

  void _clearPhotos() {
    ref.read(reco3dPhotosProvider.notifier).state = [];
  }

  Future<void> _startScan() async {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Veuillez ajouter au moins une photo.'))),
      );
      return;
    }

    // Avertissement interactif sur le nombre de photos pour la photogrammétrie dense
    if (_selectedMode == 'photo' && _selectedPhotos.length < 15) {
      final shouldSwitch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Photogrammétrie : photos insuffisantes'))),
            ],
          ),
          content: Text(
            '${tr("Le mode Pièce réelle (Meshroom) exige au moins 20 à 40 photos tout autour de l'objet avec 60% de recouvrement pour trianguler les caméras dans l'espace.")}\n\n'
            '${tr("Avec vos")} ${_selectedPhotos.length} ${tr("photo(s), utilisez l'onglet « Forme concept (Génératif) » qui reconstruit la forme 3D en 2 secondes.")}\n\n'
            '${tr("Voulez-vous basculer automatiquement sur « Forme concept » ?")}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Forcer Pièce réelle')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: context.fc.primary),
              child: Text(tr('Basculer en Forme concept')),
            ),
          ],
        ),
      );

      if (shouldSwitch == true) {
        ref.read(reco3dSelectedModeProvider.notifier).state = 'gen';
      } else if (shouldSwitch == null) {
        return; // L'utilisateur a fermé la boîte de dialogue
      }
    }

    // Vérifier la présence du moteur sur le serveur avant de soumettre
    final health = ref.read(reco3dHealthProvider).valueOrNull;
    if (health != null) {
      final engineMsg = health.engines[_selectedMode];
      if (engineMsg != null && engineMsg.startsWith('moteur(s) absent(s)')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.construction, color: Colors.orange),
                const SizedBox(width: 8),
                Text(tr('Moteur 3D non configuré')),
              ],
            ),
            content: Text(
              '${tr("Le service Reco3D est bien connecté au GPU, mais le moteur de calcul requis n'est pas installé sur le PC hôte")} :\n\n• $engineMsg\n\n${tr("Conformément aux règles du projet, aucun maillage fictif n'est inventé tant que le moteur n'est pas prêt.")}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('Compris')),
              ),
            ],
          ),
        );
        return;
      }
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

            // 7. Chaîne Implant Médical sur Mesure (STL DICOM / Scan 3D -> G-code ISO 13485)
            const SizedBox(height: 20),
            _buildMedicalImplantSection(scanState),
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
                    hintText: 'http://192.168.54.35:8765',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    suffixIcon: _isDiscovering
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
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
            data: (health) {
              final engineMsg = health.engines[_selectedMode];
              final hasEngine = engineMsg == 'moteurs présents';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (engineMsg != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          hasEngine ? Icons.verified : Icons.construction,
                          color: hasEngine ? Colors.green : Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasEngine ? tr('Moteur 3D : prêt') : engineMsg,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasEngine ? Colors.green : Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
            loading: () => const Text('Vérification du service...', style: TextStyle(fontSize: 12)),
            error: (err, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr("Service hors ligne")} : $err',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: context.fc.primary,
                      ),
                      onPressed: _isDiscovering ? null : _autoDiscoverServer,
                      icon: const Icon(Icons.search, size: 15),
                      label: Text(
                        tr('Détecter le PC automatiquement'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateServerUrl('http://192.168.88.94:8765'),
                      icon: const Icon(Icons.wifi, size: 14),
                      label: const Text('192.168.88.94:8765', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateServerUrl('http://DESKTOP-24IDAFU.local:8765'),
                      icon: const Icon(Icons.dns, size: 14),
                      label: const Text('DESKTOP-24IDAFU.local', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateServerUrl('http://192.168.137.1:8765'),
                      icon: const Icon(Icons.wifi_tethering, size: 14),
                      label: const Text('Hotspot (192.168.137.1)', style: TextStyle(fontSize: 11)),
                    ),
                  ],
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
              ref.read(reco3dSelectedModeProvider.notifier).state = set.first;
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
                  if (_selectedPhotos.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                      tooltip: tr('Tout effacer'),
                      onPressed: _clearPhotos,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedMode == 'photo') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Conseil Pièce réelle : Prenez 20 à 40 photos avec votre appareil photo habituel, puis touchez « Importer galerie » pour tout sélectionner en un clic.'),
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhotos(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text(tr('Prendre photo'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickPhotos(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: Text(tr('Importer galerie'), style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fc.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedPhotos.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  tr('Aucune photo ajoutée.'),
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
                          cacheWidth: 200,
                          cacheHeight: 200,
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
                if (scanState.downloadedStepFile != null) ...[
                  const Divider(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 14, color: Colors.lightBlueAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'STEP : ${scanState.downloadedStepFile!.path}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (scanState.downloadedMeshFile != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 14, color: Colors.lightGreenAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'STL : ${scanState.downloadedMeshFile!.path}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bouton d'action directe vers l'adaptateur de fabrication
          ElevatedButton.icon(
            onPressed: () async {
              final stepFile = scanState.downloadedStepFile;
              final meshFile = scanState.downloadedMeshFile;
              final targetFile = stepFile ?? meshFile;
              if (targetFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('Aucun fichier 3D disponible.'))),
                );
                return;
              }

              // 1. Charger la pièce dans le magasin d'artefacts et ouvrir l'aperçu 3D
              await ref.read(aiArtifactsProvider.notifier).loadStep(targetFile.path);
              ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.step);

              if (!mounted) return;

              // 2. Transmettre à l'agent IA CAM
              final prompt = tr(
                'Charge ce fichier STEP et prépare le G-code de finition.\n\nFichier : {}',
                [targetFile.path],
              );
              ref.read(aiAgentControllerProvider.notifier).sendUserMessage(prompt);

              // 3. Basculer vers l'écran CAM / Agent IA
              final isDesktop = MediaQuery.of(context).size.width >= 900;
              if (isDesktop) {
                ref.read(selectedNavIndexProvider.notifier).state = 6; // Onglet Agent IA (AiConsoleScreen)
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: SafeArea(child: AiAssistantScreen(embedded: false)),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.precision_manufacturing),
            label: Text(tr('Ouvrir dans l\'adaptateur d\'usinage (CAM)')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final targetFile = scanState.downloadedStepFile ?? scanState.downloadedMeshFile;
              if (targetFile != null) {
                await ref.read(aiArtifactsProvider.notifier).loadStep(targetFile.path);
                ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.step);
              }
              if (!mounted) return;
              ref.read(selectedNavIndexProvider.notifier).state = 0; // Tableau de bord 3D
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.view_in_ar),
            label: Text(tr('Voir sur le plateau 3D (Tableau de bord)')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedicalStlFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['stl', 'step', 'stp'],
      );
      if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
        final file = File(res.files.single.path!);
        ref
            .read(medicalImplantProvider.notifier)
            .selectStlFile(file, provenanceApproximate: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr("Erreur import 3D")} : $e')),
        );
      }
    }
  }

  Widget _buildMedicalImplantSection(Reco3dScanState scanState) {
    final medState = ref.watch(medicalImplantProvider);
    final notifier = ref.read(medicalImplantProvider.notifier);

    // Source 3D effective : fichier choisi explicitement, sinon le STL issu du scan
    final effectiveStl = medState.stlFile ?? scanState.downloadedMeshFile;
    final effectiveApprox = medState.stlFile != null
        ? medState.provenanceApproximate
        : (scanState.provenance?.isApproximate ?? false);

    final spec = medState.materialSpec;
    final blocker = () {
      if (!spec.machinable) return spec.refusalReason;
      if (effectiveApprox &&
          medState.implantType != MedicalImplantType.anatomicalModel &&
          (medState.targetLengthMm == null || medState.targetLengthMm! <= 0)) {
        return tr(
          'Modèle issu d\'un scan sans mire certifiée : indiquez une longueur '
          'cible (mm) ci-dessous ou basculez sur « Modèle anatomique pré-opératoire ».',
        );
      }
      return null;
    }();

    final isStep = effectiveStl != null &&
        (effectiveStl.path.toLowerCase().endsWith('.step') ||
            effectiveStl.path.toLowerCase().endsWith('.stp'));

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Chaîne Usinage Médical sur Mesure (STL / STEP → G-code)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'ISO 13485 · M9 SEC',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Prépare un modèle 3D (STL scanner/DICOM ou STEP CAO natif), '
              'oriente la pièce à plat sur le berceau, centre l\'origine G54, '
              'vérifie la biocompatibilité d\'usinage (coupe à sec M9) et '
              'génère le dossier de lot.',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),

          // Sélection du fichier 3D (import STL/STEP ou récupération du scan courant)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMedicalStlFile,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(
                    tr('Importer 3D (STL ou STEP CAO)'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (scanState.downloadedMeshFile != null &&
                  medState.stlFile?.path != scanState.downloadedMeshFile!.path) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    notifier.selectStlFile(
                      scanState.downloadedMeshFile!,
                      provenanceApproximate: scanState.provenance?.isApproximate ?? true,
                    );
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(tr('Utiliser le Scan 3D'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  effectiveStl != null ? Icons.insert_drive_file_outlined : Icons.info_outline,
                  size: 15,
                  color: effectiveStl != null ? Colors.tealAccent : Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    effectiveStl != null
                        ? '${isStep ? "STEP CAO" : "STL"} : ${effectiveStl.path.split(Platform.pathSeparator).last}'
                            '${effectiveApprox ? " (échelle approximative)" : " (échelle métrique)"}'
                        : tr('Aucun fichier 3D sélectionné (importez un STL/STEP ou lancez un scan).'),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Type de dispositif médical
          DropdownButtonFormField<MedicalImplantType>(
            key: ValueKey<MedicalImplantType>(medState.implantType),
            initialValue: medState.implantType,
            decoration: InputDecoration(
              labelText: tr('Type de dispositif médical'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final t in MedicalImplantType.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(t.label, style: const TextStyle(fontSize: 13)),
                ),
            ],
            onChanged: (val) {
              if (val != null) notifier.setImplantType(val);
            },
          ),
          const SizedBox(height: 12),

          // Matériau médical (avec signalement honnête des métaux hors capacité)
          DropdownButtonFormField<MedicalMaterialId>(
            key: ValueKey<MedicalMaterialId>(medState.material),
            initialValue: medState.material,
            decoration: InputDecoration(
              labelText: tr('Matériau biomédical & enveloppe machine'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final m in MedicalMaterialId.values)
                DropdownMenuItem(
                  value: m,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.spec.machinable ? Icons.check_circle_outline : Icons.block,
                        size: 15,
                        color: m.spec.machinable ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${m.spec.name} (${m.spec.machinable ? "ap ≤ ${m.spec.apMax} mm" : "Hors capacité 200 W"})',
                          style: TextStyle(
                            fontSize: 12,
                            color: m.spec.machinable ? null : Colors.redAccent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (val) {
              if (val != null) notifier.setMaterial(val);
            },
          ),
          const SizedBox(height: 8),

          // Fiche du matériau sélectionné ou refus motivé
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: spec.machinable
                  ? Colors.teal.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: spec.machinable ? Colors.tealAccent.withValues(alpha: 0.4) : Colors.redAccent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${spec.name} — ${spec.standard}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: spec.machinable ? Colors.tealAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Usage : ${spec.clinicalUse}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (spec.machinable) ...[
                  Text(
                    '• Plafonds machine : ap ≤ ${spec.apMax} mm · ae ≤ ${spec.aeMax} mm · '
                    'pas finition ${spec.stepoverRecommended} mm · F ébauche ${spec.feedRoughMax.toInt()} mm/min',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const Text(
                    '• Hygiène : Coupe à sec obligatoire (M9 forcé, M7/M8 bloqués)',
                    style: TextStyle(fontSize: 11, color: Colors.amberAccent),
                  ),
                ] else if (spec.refusalReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⛔ ${spec.refusalReason!}',
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Traçabilité de lot (ISO 13485) & recalage métrique optionnel
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _medLotController,
                  decoration: InputDecoration(
                    labelText: tr('N° de Lot (ISO 13485)'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => notifier.setLotInfo(lotId: v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _medPatientController,
                  decoration: InputDecoration(
                    labelText: tr('Réf. Cas / Patient (anonymisée)'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => notifier.setLotInfo(patientRef: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _medTargetLengthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Longueur XY cible (mm, optionnel)'),
                    hintText: tr('Ex: 45.0 (recalage DICOM/Scan)'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => notifier.setTargetLengthMm(double.tryParse(v.trim())),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(
                  medState.fiveAxis ? tr('5 Axes Continu') : tr('3 Axes (A=0)'),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: medState.fiveAxis,
                onSelected: (v) => notifier.setFiveAxis(v),
              ),
            ],
          ),

          if (blocker != null && spec.machinable) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(
                '⚠️ $blocker',
                style: const TextStyle(fontSize: 11, color: Colors.amber),
              ),
            ),
          ],

          if (medState.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              medState.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],

          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: (medState.isGenerating || blocker != null || effectiveStl == null)
                ? null
                : () {
                    notifier.setLotInfo(
                      lotId: _medLotController.text,
                      patientRef: _medPatientController.text,
                    );
                    notifier.setTargetLengthMm(
                      double.tryParse(_medTargetLengthController.text.trim()),
                    );
                    notifier.generateProgram(
                      overrideStlFile: effectiveStl,
                      overrideProvenanceApproximate: effectiveApprox,
                    );
                  },
            icon: medState.isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.healing),
            label: Text(
              medState.isGenerating
                  ? tr('Préparation géométrique & calcul 5 axes en cours...')
                  : tr('Préparer l\'implant & Générer le G-code médical'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          if (medState.result != null) ...[
            const SizedBox(height: 16),
            _buildMedicalDossierCard(medState.result!),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalDossierCard(MedicalImplantResult res) {
    final d = res.dossier;
    final crit = res.critique;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.tealAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tr("Dossier de Lot ISO 13485")} — ${d.lotId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: tr('Copier la fiche de traçabilité'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: d.toMarkdownSummary()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('Fiche de traçabilité ISO 13485 copiée.'))),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 12),
          Text('• Cas / Patient : ${d.patientRef} · ${d.implantType.label}',
              style: const TextStyle(fontSize: 12)),
          Text('• Matériau : ${d.material.name} (${d.material.standard})',
              style: const TextStyle(fontSize: 12)),
          Text('• Dimensions G54 : ${d.sizeLabel} (vol. ${d.volumeMm3.toStringAsFixed(1)} mm³)',
              style: const TextStyle(fontSize: 12)),
          Text(
            '• Coupe : ap ${d.apMm} mm · ae ${d.aeMm} mm · pas ${d.stepoverMm} mm '
            '(crête ${d.crestUm.toStringAsFixed(1)} µm) · Coupe à sec M9',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '• Parcours : ${d.roughLayers} couches d\'ébauche + ${d.finishPoints} pts finition '
            '(A de ${d.aRangeDeg.first.toStringAsFixed(1)}° à ${d.aRangeDeg.last.toStringAsFixed(1)}°) '
            '· ${d.durationTotalMin.toStringAsFixed(1)} min (${d.gcodeLines} lignes)',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '• Critique G-code médicale : ${crit.usable ? "CONFORME (sans lubrifiant M7/M8)" : "BLOQUÉ"}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: crit.usable ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          for (final note in d.preparationNotes)
            Text('  ↳ $note',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.step);
                    ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.toolpath);
                    ref.read(selectedNavIndexProvider.notifier).state = 0;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.view_in_ar, size: 16),
                  label: Text(tr('Plateau 3D & Parcours'), style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final prompt =
                        'Vérifie le dossier médical du lot ${d.lotId} (${d.material.name}, '
                        '${d.implantType.label}) généré dans ${res.gcodePath}.';
                    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(prompt);
                    final isDesktop = MediaQuery.of(context).size.width >= 900;
                    if (isDesktop) {
                      ref.read(selectedNavIndexProvider.notifier).state = 6;
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            body: SafeArea(child: AiAssistantScreen(embedded: false)),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: Text(tr('Ouvrir dans l\'Agent IA'), style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
