import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../application/providers/file_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/gcode_file.dart';
import '../../core/widgets/split_view.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});
  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen>
    with SingleTickerProviderStateMixin {
  int _selectedFile = 0;
  late TabController _tabCtrl;
  String _previewContent = '';
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['nc', 'gcode', 'gc', 'tap', 'ngc', 'cnc'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    try {
      await ref.read(fileRepositoryProvider).uploadFile(f.name, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.success,
          content: Text('✓ ${f.name} uploadé avec succès',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
      }
      ref.invalidate(fileListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur upload: $e'),
        ));
      }
    }
  }

  Future<void> _deleteFile(GCodeFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirmer la suppression',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Supprimer "${file.name}" ?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(fileRepositoryProvider).deleteFile(file.name);
      ref.invalidate(fileListProvider);
      setState(() => _selectedFile = 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.success,
          content: Text('✓ ${file.name} supprimé'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur suppression: $e'),
        ));
      }
    }
  }

  Future<void> _runFile(GCodeFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Lancer l\'usinage',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_circle, color: AppColors.success, size: 48),
          const SizedBox(height: 16),
          Text('Envoyer "${file.name}" à la machine ?',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('⚠ Assurez-vous que la machine est correctement',
              style: TextStyle(color: AppColors.warning, fontSize: 11)),
          const Text('   positionnée et les origines définies.',
              style: TextStyle(color: AppColors.warning, fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LANCER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(machineRepositoryProvider).sendGCode('\$SD/Run=${file.name}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.success,
          content: Text('▶ Usinage lancé: ${file.name}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur lancement: $e'),
        ));
      }
    }
  }

  Future<void> _loadPreview(GCodeFile file) async {
    setState(() {
      _loadingPreview = true;
      _previewContent = '';
    });
    try {
      final content = await ref.read(fileRepositoryProvider).readFile(file.name);
      setState(() {
        _previewContent = content;
        _loadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _previewContent = '; Erreur de chargement: $e';
        _loadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(fileListProvider);

    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ESPACE DE TRAVAIL',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.storage, color: AppColors.textDisabled, size: 12),
              SizedBox(width: 4),
              Text('/ sd / gcodes', style: TextStyle(color: AppColors.primary, fontSize: 10, fontFamily: 'JetBrains Mono')),
            ]),
          ]),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('ESP32 — SD Card HTTP',
                style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          // Bouton Refresh
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(fileListProvider),
            icon: const Icon(Icons.sync, size: 14),
            label: const Text('SYNC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceBorder),
                minimumSize: const Size(0, 44)),
          ),
          const SizedBox(width: 8),
          // Bouton Upload
          ElevatedButton.icon(
            onPressed: _uploadFile,
            icon: const Icon(Icons.upload_file, size: 14),
            label: const Text('UPLOAD G-CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: AppColors.primary),
          ),
        ]),
      ),
      // ── Body ──────────────────────────────────────────────────────────────
      Expanded(
        child: ResizableSplitView(
          initialRatio: 0.35,
          left: Column(children: [
            // Recherche
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Filtrer les fichiers...',
                  hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textDisabled),
                  border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceBorder)),
                  filled: true,
                  fillColor: AppColors.surfaceBright,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Liste de fichiers
            Expanded(
              child: filesAsync.when(
                data: (files) => files.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.folder_off,
                              color: AppColors.textDisabled, size: 48),
                          const SizedBox(height: 12),
                          const Text('Aucun fichier G-Code',
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                          const Text('Uploadez un fichier .nc ou .gcode',
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                        ]),
                      )
                    : ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (ctx, i) {
                          final f = files[i];
                          final sel = i == _selectedFile;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedFile = i);
                              _loadPreview(f);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                border: Border(
                                    left: BorderSide(
                                        color: sel ? AppColors.primary : Colors.transparent,
                                        width: 3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.code, color: AppColors.primary, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(f.name,
                                        style: TextStyle(
                                            color: sel ? AppColors.primary : AppColors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    Text('${(f.size / 1024).toStringAsFixed(1)} KB',
                                        style: const TextStyle(
                                            color: AppColors.textDisabled,
                                            fontSize: 10,
                                            fontFamily: 'JetBrains Mono')),
                                  ]),
                                ),
                                // Run rapide
                                IconButton(
                                  icon: const Icon(Icons.play_circle,
                                      color: AppColors.success, size: 20),
                                  tooltip: 'Lancer',
                                  onPressed: () => _runFile(f),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, st) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text('Erreur: $e',
                        style: const TextStyle(color: AppColors.error, fontSize: 11),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(fileListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ]),
                ),
              ),
            ),
            // Zone drop
            InkWell(
              onTap: _uploadFile,
              child: Container(
                margin: const EdgeInsets.all(12),
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_upload, color: AppColors.primary, size: 24),
                    SizedBox(height: 4),
                    Text('CLIQUER POUR UPLOADER',
                        style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ),
          ]),
          // ── Panneau droite ─────────────────────────────────────────────────
          right: filesAsync.when(
            data: (files) {
              if (files.isEmpty) {
                return const Center(
                  child: Text('Aucun fichier sélectionné',
                      style: TextStyle(color: AppColors.textDisabled)));
              }
              final sel = _selectedFile < files.length
                  ? files[_selectedFile]
                  : files.first;
              return Column(children: [
                // Header fichier sélectionné
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
                  child: Row(children: [
                    const Icon(Icons.code, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sel.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        Text('${sel.size} bytes',
                            style: const TextStyle(
                                color: AppColors.textDisabled, fontSize: 10)),
                      ]),
                    ),
                    // RUN
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: const Size(0, 36)),
                      onPressed: () => _runFile(sel),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('RUN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    // DELETE
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(0, 36)),
                      onPressed: () => _deleteFile(sel),
                      child: const Text('SUPPRIMER',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
                // Tabs
                Container(
                  decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textDisabled,
                    tabs: const [
                      Tab(text: 'APERÇU G-CODE'),
                      Tab(text: 'TRAJECTOIRE 2D'),
                      Tab(text: 'INFORMATIONS'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _gcodeTab(sel),
                      _trajectoryTab(),
                      _infoTab(sel),
                    ],
                  ),
                ),
              ]);
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
        ),
      ),
    ]);
  }

  // ── Aperçu G-Code (depuis le vrai fichier) ─────────────────────────────────
  Widget _gcodeTab(GCodeFile file) {
    if (_loadingPreview) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final lines = _previewContent.isNotEmpty
        ? _previewContent.split('\n')
        : ['; Sélectionnez un fichier pour charger l\'aperçu', '; ou cliquez sur le fichier dans la liste'];

    return Container(
      color: AppColors.terminalBg,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (ctx, i) {
          final l = lines[i];
          Color c = AppColors.textSecondary;
          if (l.trimLeft().startsWith(';')) {
            c = AppColors.textDisabled;
          } else if (l.startsWith('G0 ') || l.startsWith('G00')) {
            c = AppColors.axisZ; // rapids en bleu
          } else if (l.startsWith('G')) {
            c = AppColors.primary;
          } else if (l.startsWith('M')) {
            c = AppColors.warning;
          } else if (l.startsWith('T') || l.startsWith('N')) {
            c = AppColors.secondary;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              SizedBox(
                width: 40,
                child: Text('${i + 1}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono')),
              ),
              Container(
                  width: 1,
                  height: 14,
                  color: AppColors.surfaceBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(
                child: Text(l,
                    style: TextStyle(color: c, fontSize: 11, fontFamily: 'JetBrains Mono')),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _trajectoryTab() {
    return Container(
      color: AppColors.terminalBg,
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timeline, color: AppColors.textDisabled, size: 64),
          SizedBox(height: 16),
          Text('VISUALISATION TRAJECTOIRE XY',
              style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('(Visualiseur G-Code 2D — À venir)',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _infoTab(GCodeFile file) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassPanel(
          title: 'Métadonnées',
          child: Column(children: [
            for (final e in [
              ('FICHIER', file.name),
              ('TAILLE', '${(file.size / 1024).toStringAsFixed(1)} KB'),
              ('LIGNES', file.lines > 0 ? '${file.lines}' : 'Non compté'),
              ('POST-PROCESSEUR', 'FluidNC 5X'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Text(e.$1,
                      style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(e.$2,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono')),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          title: 'Actions rapides',
          child: Column(children: [
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.play_arrow),
                label: const Text('LANCER L\'USINAGE (\$SD/Run)',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                onPressed: () => _runFile(file),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                icon: const Icon(Icons.preview, color: AppColors.primary),
                label: const Text('RECHARGER APERÇU',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                onPressed: () => _loadPreview(file),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                icon: const Icon(Icons.delete, color: AppColors.error),
                label: const Text('SUPPRIMER',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w900)),
                onPressed: () => _deleteFile(file),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
