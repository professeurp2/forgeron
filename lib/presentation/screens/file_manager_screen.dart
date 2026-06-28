import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/file_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../domain/models/gcode_file.dart';
import '../../core/widgets/split_view.dart';
import '../../core/utils/file_picker_service.dart';
import '../../core/utils/gcode_highlighter.dart';
import '../../core/widgets/gcode_editor_controller.dart';
import '../tutorial/tutorial_keys.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});
  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> with SingleTickerProviderStateMixin {
  int? _selectedFileIndex;
  late GCodeEditingController _editorCtrl;
  bool _isEditing = false;
  bool _loadingPreview = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _editorCtrl = GCodeEditingController();
    _tabCtrl = TabController(length: 2, vsync: this);
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
    try {
      await ref.read(fileRepositoryProvider).uploadFile(result.name, Uint8List.fromList(result.bytes));
      ref.invalidate(fileListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Fichier ${result.name} chargé sur la SD'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erreur upload: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _loadFileIntoEditor(GCodeFile file) async {
    setState(() => _loadingPreview = true);
    try {
      final content = await ref.read(fileRepositoryProvider).readFile(file.name);
      await ref.read(gcodeProvider.notifier).loadFile(content);
      _editorCtrl.text = content;
      _tabCtrl.animateTo(1); // Basculer vers l'éditeur
      setState(() => _loadingPreview = false);
    } catch (e) {
      setState(() => _loadingPreview = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _saveEditorContent() async {
    final content = _editorCtrl.text;
    await ref.read(gcodeProvider.notifier).loadFile(content);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Programme mis à jour dans l\'unité de streaming'),
      backgroundColor: AppColors.success,
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
          backgroundColor: AppColors.surface,
          title: Text('SAUVEGARDER SUR LA CARTE SD', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'Nom du fichier', labelStyle: TextStyle(color: AppColors.textSecondary)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ANNULER')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text('SAUVEGARDER')),
          ],
        );
      },
    );

    if (fileName != null && fileName.isNotEmpty) {
      try {
        final bytes = Uint8List.fromList(content.codeUnits);
        await ref.read(fileRepositoryProvider).uploadFile(fileName, bytes);
        ref.invalidate(fileListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Enregistré : $fileName'), backgroundColor: AppColors.success));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── BARRE D'ONGLETS ────────────────────────────────────────────────
      Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textDisabled,
          labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2),
          tabs: [
            Tab(text: 'EXPLORATEUR SD', icon: Icon(Icons.sd_storage_rounded, size: 18)),
            Tab(text: 'ÉDITEUR DE PROGRAMME', icon: Icon(Icons.edit_note_rounded, size: 20)),
          ],
        ),
      ),
      
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildExplorerTab(),
            _buildEditorTab(),
          ],
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
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          Text('FICHIERS SUR CARTE SD', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: _uploadFile,
            icon: Icon(Icons.add, size: 16),
            label: Text('AJOUTER'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
            Icon(Icons.edit_document, size: 64, color: AppColors.surfaceBorder),
            SizedBox(height: 24),
            Text('AUCUN PROGRAMME CHARGÉ', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        color: AppColors.surfaceBright.withValues(alpha: 0.5),
        child: Row(children: [
          Icon(Icons.terminal, color: AppColors.primary, size: 16),
          SizedBox(width: 12),
          Text('ÉDITEUR TEMPS-RÉEL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_isEditing) ...[
            TextButton(onPressed: () => setState(() => _isEditing = false), child: Text('ANNULER', style: TextStyle(color: AppColors.textDisabled))),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveEditorContent,
              icon: Icon(Icons.flash_on, size: 14),
              label: Text('APPLIQUER'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.black),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: _saveToSD,
              icon: Icon(Icons.save, size: 14),
              label: Text('SAUVEGARDER SUR SD', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit, size: 14),
              label: Text('MODIFIER'),
            ),
          ],
        ]),
      ),
      Expanded(
        child: Container(
          color: AppColors.terminalBg,
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _isEditing
              ? TextField(
                  controller: _editorCtrl,
                  maxLines: null,
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: AppColors.textPrimary, height: 1.5),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file, color: AppColors.textSecondary),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(file.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            Text('${(file.size / 1024).toStringAsFixed(1)} Ko', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
          ]),
        ),
        IconButton(onPressed: onLoad, icon: Icon(Icons.file_open_rounded, color: AppColors.primary), tooltip: 'Charger dans l\'éditeur'),
        IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: AppColors.danger)),
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
      color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('$index', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontFamily: 'JetBrains Mono')),
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