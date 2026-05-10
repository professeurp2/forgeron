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
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
        child: Row(children: [
          const Text('ESPACE DE TRAVAIL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(onPressed: _uploadFile, icon: const Icon(Icons.upload), label: const Text('UPLOAD')),
        ]),
      ),
      Expanded(
        child: ResizableSplitView(
          initialRatio: 0.3,
          left: filesAsync.when(
            data: (files) => ListView.builder(
              itemCount: files.length,
              itemBuilder: (ctx, i) => ListTile(
                selected: i == _selectedFile,
                title: Text(files[i].name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                onTap: () { setState(() => _selectedFile = i); _loadPreview(files[i]); },
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
          right: _previewContent.isEmpty ? const Center(child: Text('Sélectionnez un fichier')) : Container(color: AppColors.terminalBg, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Text(_previewContent, style: const TextStyle(color: Colors.green, fontFamily: 'JetBrains Mono', fontSize: 11)))),
        ),
      ),
    ]);
  }
}
