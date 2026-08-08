import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../widgets/mobile/mobile_tab_bar.dart';
import '../../application/providers/file_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/providers/workspace_provider.dart';
import '../../domain/models/gcode_file.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';
import '../../core/widgets/gcode_editor_controller.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});
  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> with SingleTickerProviderStateMixin {
  late GCodeEditingController _editorCtrl;
  bool _isEditing = false;
  late TabController _tabCtrl;

  /// Chemin du fichier du dossier de travail actuellement ouvert dans l'éditeur
  /// (null si le contenu vient de la SD). Permet le « Sauver dans le dossier ».
  String? _openWorkFilePath;
  String? _openWorkFileName;

  @override
  void initState() {
    super.initState();
    _editorCtrl = GCodeEditingController();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _editorCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadFile() async {
    final result = await FilePickerService.pickFileForUpload();
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final okColor = context.fc.success;
    final errColor = context.fc.error;
    try {
      await ref.read(fileRepositoryProvider).uploadFile(result.name, Uint8List.fromList(result.bytes));
      ref.invalidate(fileListProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('✅ Fichier ${result.name} chargé sur la SD'),
        backgroundColor: okColor,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Erreur upload: $e'),
        backgroundColor: errColor,
      ));
    }
  }

  Future<void> _loadFileIntoEditor(GCodeFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.fc.error;
    try {
      final content = await ref.read(fileRepositoryProvider).readFile(file.name);
      await ref.read(gcodeProvider.notifier).loadFile(content);
      _editorCtrl.text = content;
      // Contenu SD → plus lié à un fichier du dossier de travail.
      setState(() {
        _openWorkFilePath = null;
        _openWorkFileName = file.name;
      });
      _tabCtrl.animateTo(2); // Basculer vers l'éditeur
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: errorColor));
    }
  }

  Future<void> _saveEditorContent() async {
    final content = _editorCtrl.text;
    final messenger = ScaffoldMessenger.of(context);
    final okColor = context.fc.success;
    await ref.read(gcodeProvider.notifier).loadFile(content);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('✅ Programme mis à jour dans l\'unité de streaming'),
      backgroundColor: okColor,
    ));
    setState(() => _isEditing = false);
  }

  Future<void> _saveToSD() async {
    final content = _editorCtrl.text;
    // On demande un nom de fichier (par défaut le dernier chargé ou "edit.nc")
    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: 'modified_program.nc');
        return AlertDialog(
          backgroundColor: context.fc.surface,
          title: Text('SAUVEGARDER SUR LA CARTE SD', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'Nom du fichier', labelStyle: TextStyle(color: context.fc.textSecondary)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ANNULER')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text('SAUVEGARDER')),
          ],
        );
      },
    );

    if (fileName != null && fileName.isNotEmpty) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final okColor = context.fc.success;
      final errColor = context.fc.error;
      try {
        final bytes = Uint8List.fromList(content.codeUnits);
        await ref.read(fileRepositoryProvider).uploadFile(fileName, bytes);
        ref.invalidate(fileListProvider);
        messenger.showSnackBar(SnackBar(content: Text('✅ Enregistré : $fileName'), backgroundColor: okColor));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: errColor));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProgram = ref.watch(gcodeProvider).allLines.isNotEmpty;
    final streaming = ref.watch(streamingProvider);
    return Column(children: [
      // ── BARRE D'ONGLETS compacte (48 px) ──────────────────────────────
      MobileTabBar(
        controller: _tabCtrl,
        tabs: const [
          MobileTab(Icons.folder_special_rounded, 'DOSSIER'),
          MobileTab(Icons.sd_storage_rounded, 'CARTE SD'),
          MobileTab(Icons.edit_note_rounded, 'ÉDITEUR'),
        ],
      ),

      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildWorkFolderTab(),
            _buildExplorerTab(),
            _buildEditorTab(),
          ],
        ),
      ),

      // ── DÉPART CYCLE : disponible dès qu'un programme est chargé ──────────
      if (hasProgram) _buildCycleStartBar(streaming),
    ]);
  }

  /// Bandeau bas de l'écran Travail : lance le programme chargé (validé +
  /// ForceGuard, même chemin que le bouton du Tableau).
  Widget _buildCycleStartBar(bool streaming) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: streaming ? null : _handleCycleStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: streaming ? fc.surfaceBright : fc.success,
              foregroundColor: streaming ? fc.textDisabled : Colors.white,
              disabledBackgroundColor: fc.surfaceBright,
              disabledForegroundColor: fc.textDisabled,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(streaming
                ? Icons.hourglass_top_rounded
                : Icons.play_arrow_rounded),
            label: Text(
              streaming ? 'EXÉCUTION EN COURS…' : 'DÉPART CYCLE',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCycleStart() async {
    final messenger = ScaffoldMessenger.of(context);
    final errColor = context.fc.error;
    HapticFeedback.mediumImpact();
    final result = await ref.read(streamingProvider.notifier).startStream();
    if (!result.isValid) {
      final line = result.errorLine != null ? ' (ligne ${result.errorLine})' : '';
      messenger.showSnackBar(SnackBar(
        content: Text('Refusé : ${result.errorMessage}$line'),
        backgroundColor: errColor,
      ));
    }
  }

  // ── Onglet DOSSIER DE TRAVAIL ─────────────────────────────────────────────

  Future<void> _pickWorkFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final errColor = context.fc.error;
    final path = await ref.read(workFolderProvider.notifier).pickAndSet();
    if (!mounted) return;
    if (path != null) {
      ref.read(workFilesRefreshProvider.notifier).state++;
    } else {
      messenger.showSnackBar(SnackBar(
          content: const Text('Aucun dossier sélectionné'),
          backgroundColor: errColor));
    }
  }

  Future<void> _openWorkFile(WorkFile f) async {
    final messenger = ScaffoldMessenger.of(context);
    final errColor = context.fc.error;
    try {
      final content = await FilePickerService.readWorkFile(f.path);
      await ref.read(gcodeProvider.notifier).loadFile(content);
      if (!mounted) return;
      _editorCtrl.text = content;
      setState(() {
        _openWorkFilePath = f.path;
        _openWorkFileName = f.name;
        _isEditing = false;
      });
      _tabCtrl.animateTo(2);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Lecture impossible : $e'), backgroundColor: errColor));
    }
  }

  Future<void> _saveToWorkFile() async {
    final path = _openWorkFilePath;
    if (path == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final okColor = context.fc.success;
    final errColor = context.fc.error;
    try {
      await FilePickerService.writeWorkFile(path, _editorCtrl.text);
      await ref.read(gcodeProvider.notifier).loadFile(_editorCtrl.text);
      if (!mounted) return;
      ref.read(workFilesRefreshProvider.notifier).state++;
      setState(() => _isEditing = false);
      messenger.showSnackBar(SnackBar(
          content: Text('✅ Enregistré : $_openWorkFileName'),
          backgroundColor: okColor));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Écriture impossible : $e'), backgroundColor: errColor));
    }
  }

  Widget _buildWorkFolderTab() {
    final folder = ref.watch(workFolderProvider);
    final files = ref.watch(workFilesProvider);

    if (folder == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_off_rounded,
                size: 56, color: context.fc.surfaceBorder),
            const SizedBox(height: 16),
            Text('AUCUN DOSSIER DE TRAVAIL',
                style: TextStyle(
                    color: context.fc.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
                'Choisis un dossier du téléphone contenant tes G-code. Tu pourras les ouvrir, les éditer et les enregistrer — même hors ligne.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.fc.textDisabled, fontSize: 11)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickWorkFolder,
              icon: const Icon(Icons.create_new_folder_rounded, size: 18),
              label: const Text('CHOISIR LE DOSSIER'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.fc.primary,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      // Bandeau : chemin du dossier + actions.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: context.fc.surface,
            border:
                Border(bottom: BorderSide(color: context.fc.surfaceBorder))),
        child: Row(children: [
          Icon(Icons.folder_rounded, color: context.fc.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(folder.split('/').last.isEmpty ? folder : folder.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.fc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: () =>
                ref.read(workFilesRefreshProvider.notifier).state++,
            icon: Icon(Icons.refresh_rounded,
                color: context.fc.textSecondary, size: 18),
            tooltip: 'Rafraîchir',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _pickWorkFolder,
            icon: Icon(Icons.swap_horiz_rounded,
                color: context.fc.textSecondary, size: 18),
            tooltip: 'Changer de dossier',
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ),
      Expanded(
        child: files.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'Aucun fichier G-code lisible dans ce dossier.\n\nSur Android 11+, autorise « Accès à tous les fichiers » pour Forgeron dans les réglages, ou choisis un dossier accessible (ex. Téléchargements).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.fc.textDisabled, fontSize: 11)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: files.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final f = files[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openWorkFile(f),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.fc.surface,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: context.fc.surfaceBorder),
                        ),
                        child: Row(children: [
                          Icon(Icons.description_rounded,
                              color: context.fc.primary, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: context.fc.textPrimary,
                                          fontWeight: FontWeight.bold)),
                                  Text('${(f.size / 1024).toStringAsFixed(1)} Ko',
                                      style: TextStyle(
                                          color: context.fc.textDisabled,
                                          fontSize: 10)),
                                ]),
                          ),
                          Icon(Icons.edit_rounded,
                              color: context.fc.textDisabled, size: 18),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildExplorerTab() {
    final filesAsync = ref.watch(fileListProvider);
    return Column(children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
            color: context.fc.background,
            border: Border(bottom: BorderSide(color: context.fc.surfaceBorder))),
        child: Row(children: [
          Text('FICHIERS SUR CARTE SD', style: TextStyle(color: context.fc.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: _uploadFile,
            icon: Icon(Icons.add, size: 16),
            label: Text('AJOUTER'),
            style: TextButton.styleFrom(foregroundColor: context.fc.primary),
          ),
        ]),
      ),
      Expanded(
        child: filesAsync.when(
          data: (files) => ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: files.length,
            separatorBuilder: (_, __) => SizedBox(height: 8),
            itemBuilder: (ctx, i) => _FileCard(
              file: files[i],
              onLoad: () => _loadFileIntoEditor(files[i]),
              onDelete: () async {
                await ref.read(fileRepositoryProvider).deleteFile(files[i].name);
                ref.invalidate(fileListProvider);
              },
            ),
          ),
          loading: () => Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Erreur: $e')),
        ),
      ),
    ]);
  }

  Widget _buildEditorTab() {
    final gcodeState = ref.watch(gcodeProvider);
    
    if (gcodeState.allLines.isEmpty && !_isEditing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_document, size: 64, color: context.fc.surfaceBorder),
            SizedBox(height: 24),
            Text('AUCUN PROGRAMME CHARGÉ', style: TextStyle(color: context.fc.textPrimary, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabCtrl.animateTo(0),
              child: Text('CHARGER DEPUIS LA SD'),
            ),
          ],
        ),
      );
    }

    return Column(children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        color: context.fc.surfaceBright.withValues(alpha: 0.5),
        child: Row(children: [
          Icon(Icons.terminal, color: context.fc.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_openWorkFileName ?? 'ÉDITEUR',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.fc.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          // Actions compactes en icônes (évite le débordement sur mobile).
          if (_isEditing) ...[
            _EditorAction(Icons.close_rounded, 'Annuler', context.fc.textDisabled,
                () => setState(() => _isEditing = false)),
            _EditorAction(Icons.flash_on_rounded, 'Appliquer à la machine',
                context.fc.success, _saveEditorContent),
            if (_openWorkFilePath != null)
              _EditorAction(Icons.save_rounded, 'Sauver dans le dossier',
                  context.fc.primary, _saveToWorkFile),
          ] else ...[
            if (_openWorkFilePath != null)
              _EditorAction(Icons.save_rounded, 'Sauver dans le dossier',
                  context.fc.primary, _saveToWorkFile),
            _EditorAction(Icons.sd_card_rounded, 'Sauver sur la carte SD',
                context.fc.textSecondary, _saveToSD),
            _EditorAction(Icons.edit_rounded, 'Modifier', context.fc.primary,
                () => setState(() => _isEditing = true)),
          ],
        ]),
      ),
      Expanded(
        child: Container(
          color: context.fc.terminalBg,
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _isEditing
              ? TextField(
                  controller: _editorCtrl,
                  maxLines: null,
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: context.fc.textPrimary, height: 1.5),
                  decoration: const InputDecoration(border: InputBorder.none),
                )
              : ListView.builder(
                  itemCount: gcodeState.allLines.length,
                  itemBuilder: (context, index) {
                    return _GCodeLine(
                      index: index + 1,
                      content: gcodeState.allLines[index],
                      isCurrent: index == gcodeState.currentLineIndex,
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}

class _FileCard extends StatelessWidget {
  final GCodeFile file;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  const _FileCard({required this.file, required this.onLoad, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fc.surfaceBorder),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file, color: context.fc.textSecondary),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(file.name, style: TextStyle(color: context.fc.textPrimary, fontWeight: FontWeight.bold)),
            Text('${(file.size / 1024).toStringAsFixed(1)} Ko', style: TextStyle(color: context.fc.textDisabled, fontSize: 10)),
          ]),
        ),
        IconButton(onPressed: onLoad, icon: Icon(Icons.file_open_rounded, color: context.fc.primary), tooltip: 'Charger dans l\'éditeur'),
        IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: context.fc.danger)),
      ]),
    );
  }
}

class _GCodeLine extends StatelessWidget {
  final int index;
  final String content;
  final bool isCurrent;

  const _GCodeLine({required this.index, required this.content, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCurrent ? context.fc.primary.withValues(alpha: 0.1) : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('$index', style: TextStyle(color: context.fc.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  height: 1.5,
                ),
                children: GCodeHighlighter.buildSpans(content, isCurrent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Bouton d'action compact (icône) pour la barre de l'éditeur.
class _EditorAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _EditorAction(this.icon, this.tooltip, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      onPressed: onTap,
    );
  }
}
