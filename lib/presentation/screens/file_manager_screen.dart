import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/file_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../domain/models/gcode_file.dart';
import '../../core/widgets/split_view.dart';
import '../../core/utils/file_picker_service.dart';
import '../tutorial/tutorial_keys.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});
  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _uploadFile() async {
    final result = await FilePickerService.pickFileForUpload();
    if (result == null) return;
    try {
      await ref.read(fileRepositoryProvider).uploadFile(result.name, Uint8List.fromList(result.bytes));
      ref.invalidate(fileListProvider);
    } catch (e) {
      print('Upload error: $e');
    }
  }

  Future<void> _deleteFile(GCodeFile file) async {
    try {
      await ref.read(fileRepositoryProvider).deleteFile(file.name);
      ref.invalidate(fileListProvider);
    } catch (e) {
      print('Delete error: $e');
    }
  }

  Future<void> _runFile(GCodeFile file) async {
    await ref.read(machineRepositoryProvider).sendGCode('\$SD/Run=${file.name}');
  }

  Future<void> _loadPreview(GCodeFile file) async {
    setState(() => _loadingPreview = true);
    try {
      final content = await ref.read(fileRepositoryProvider).readFile(file.name);
      setState(() { _previewContent = content; _loadingPreview = false; });
    } catch (e) {
      setState(() { _previewContent = '; Error: $e'; _loadingPreview = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(fileListProvider);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          const Icon(Icons.folder_open, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          const Text('ESPACE DE TRAVAIL',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0)),
          const Spacer(),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceBright,
                  foregroundColor: AppColors.primary),
              onPressed: _uploadFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('CHARGER NC')),
        ]),
      ),
      Expanded(
        child: ResizableSplitView(
          initialRatio: 0.3,
          left: Container(
            key: TutorialKeys.fileManager,
            child: filesAsync.when(
            data: (files) => files.isEmpty
                ? const Center(
                    child: Text('AUCUN FICHIER SUR LA SD',
                        style: TextStyle(color: AppColors.textDisabled)))
                : ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AppColors.surfaceBorder, height: 1),
                    itemBuilder: (ctx, i) => ListTile(
                      selected: i == _selectedFile,
                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                      leading: Icon(Icons.insert_drive_file,
                          color: i == _selectedFile
                              ? AppColors.primary
                              : AppColors.textDisabled,
                          size: 18),
                      title: Text(files[i].name,
                          style: TextStyle(
                              color: i == _selectedFile
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: i == _selectedFile
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      subtitle: Text('${(files[i].size / 1024).toStringAsFixed(1)} Ko',
                          style: const TextStyle(
                              color: AppColors.textDisabled, fontSize: 10)),
                      trailing: i == _selectedFile
                          ? IconButton(
                              key: TutorialKeys.streamBtn,
                              icon: const Icon(Icons.play_circle_fill,
                                  color: AppColors.success, size: 24),
                              onPressed: () => _runFile(files[i]),
                              tooltip: 'Lancer l\'usinage',
                            )
                          : IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger, size: 18),
                              onPressed: () => _deleteFile(files[i]),
                            ),
                      onTap: () {
                        setState(() => _selectedFile = i);
                        _loadPreview(files[i]);
                      },
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
          right: Container(
            key: TutorialKeys.gcodePreview,
            child: _loadingPreview
                ? const Center(child: CircularProgressIndicator())
              : _previewContent.isEmpty
                  ? const Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description,
                            size: 48, color: AppColors.surfaceBorder),
                        SizedBox(height: 16),
                        Text('SÉLECTIONNEZ UN FICHIER POUR APERÇU',
                            style: TextStyle(color: AppColors.textDisabled)),
                      ],
                    ))
                  : Container(
                      color: AppColors.terminalBg,
                      width: double.infinity,
                      height: double.infinity,
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(_previewContent,
                              style: const TextStyle(
                                  color: Color(0xFF00FF00),
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  height: 1.4))),
                    ),
          ),
        ),
      ),
    ]);
  }
}
