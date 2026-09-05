import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/widgets/readable_width.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/ai_agent_settings_provider.dart';
import '../../application/providers/ai_model_provider.dart';
import '../../application/services/local_ai_agent_service.dart';
import '../../core/i18n/app_localizations.dart';

/// Écran de configuration de l'agent IA : activation, clé API Gemini
/// (stockage sécurisé), et permissions par catégorie d'action (exécution
/// automatique vs confirmation obligatoire).
class AiAgentSettingsScreen extends ConsumerStatefulWidget {
  const AiAgentSettingsScreen({super.key});

  @override
  ConsumerState<AiAgentSettingsScreen> createState() =>
      _AiAgentSettingsScreenState();
}

class _AiAgentSettingsScreenState extends ConsumerState<AiAgentSettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _localUrlCtrl = TextEditingController();
  final _localModelCtrl = TextEditingController();
  bool _hasStoredKey = false;
  bool _saving = false;

  /// Résultat du dernier test de connexion au serveur local (null = pas testé).
  String? _localProbe;
  bool _localProbeOk = false;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _loadKeyStatus();
    final settings = ref.read(aiAgentSettingsProvider);
    _localUrlCtrl.text = settings.localBaseUrl;
    _localModelCtrl.text = settings.localModel;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _localUrlCtrl.dispose();
    _localModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKeyStatus() async {
    final key = await ref.read(aiAgentSettingsProvider.notifier).readApiKey();
    if (mounted) setState(() => _hasStoredKey = key != null && key.isNotEmpty);
  }

  Future<void> _saveKey() async {
    final value = _apiKeyCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(aiAgentSettingsProvider.notifier).saveApiKey(value);
    _apiKeyCtrl.clear();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasStoredKey = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Clé API enregistrée.'))),
    );
  }

  /// Enregistre l'adresse et le modèle du serveur local. Une adresse vide
  /// ramène l'agent sur Gemini.
  void _saveLocalServer() {
    final notifier = ref.read(aiAgentSettingsProvider.notifier);
    notifier.setLocalBaseUrl(_localUrlCtrl.text);
    notifier.setLocalModel(_localModelCtrl.text);
    final saved = ref.read(aiAgentSettingsProvider).localBaseUrl;
    _localUrlCtrl.text = saved; // reflète la normalisation
    setState(() => _localProbe = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved.isEmpty
          ? tr('Serveur local effacé — l\'agent repasse sur Gemini.')
          : tr('Serveur local enregistré.')),
    ));
  }

  /// Interroge `/v1/models` pour vérifier que le serveur répond ET que le
  /// modèle demandé y est bien chargé. Un test qui se contente du ping laisse
  /// découvrir le nom de modèle erroné à la première question posée.
  Future<void> _probeLocalServer() async {
    final url = LocalAiAgentService.normalizeBaseUrl(_localUrlCtrl.text);
    if (url.isEmpty) return;
    setState(() {
      _probing = true;
      _localProbe = null;
    });
    final wanted = _localModelCtrl.text.trim();
    try {
      final res = await http
          .get(Uri.parse('$url/v1/models'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        _setProbe(false, 'HTTP ${res.statusCode} — le serveur répond mais '
            'refuse la requête.');
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ids = ((data['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m['id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isEmpty) {
        _setProbe(false, 'Serveur joignable, mais aucun modèle chargé.');
      } else if (ids.contains(wanted)) {
        _setProbe(true, 'Serveur joignable, modèle « $wanted » disponible.');
      } else {
        _setProbe(
            false,
            'Serveur joignable, mais « $wanted » est absent. '
            'Disponibles : ${ids.join(', ')}');
      }
    } catch (e) {
      _setProbe(
          false,
          'Injoignable. Vérifie qu\'Ollama écoute sur 0.0.0.0 '
          '(OLLAMA_HOST) et que le port 11434 est ouvert au pare-feu.');
    }
  }

  void _setProbe(bool ok, String message) {
    if (!mounted) return;
    setState(() {
      _probing = false;
      _localProbeOk = ok;
      _localProbe = message;
    });
  }

  Future<void> _clearKey() async {
    await ref.read(aiAgentSettingsProvider.notifier).clearApiKey();
    if (mounted) setState(() => _hasStoredKey = false);
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final settings = ref.watch(aiAgentSettingsProvider);
    // Une adresse de serveur local renseignee suffit a basculer le fournisseur :
    // pas de second interrupteur a tenir coherent avec elle.
    final usingLocal = settings.localBaseUrl.isNotEmpty;
    final notifier = ref.read(aiAgentSettingsProvider.notifier);
    final modelState = ref.watch(aiModelProvider);
    final modelNotifier = ref.read(aiModelProvider.notifier);

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.smart_toy_outlined, color: fc.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('AGENT IA'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fc.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    tr('Gemini & permissions'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fc.textSecondary, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassPanel(
                    title: tr('ACTIVATION'),
                    borderColor: fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('Agent IA activé'),
                                  style: TextStyle(
                                      color: fc.textPrimary,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                tr('Autorise l\'assistant conversationnel à consulter et piloter la machine via les outils ci-dessous.'),
                                style:
                                    TextStyle(color: fc.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: settings.enabled,
                          activeThumbColor: fc.primary,
                          onChanged: notifier.setEnabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    title: tr('CLÉ API GEMINI'),
                    borderColor: fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasStoredKey
                              ? 'Une clé est déjà enregistrée (stockage sécurisé de l\'appareil).'
                              : 'Aucune clé enregistrée — l\'agent ne peut pas être utilisé.',
                          style: TextStyle(color: fc.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: true,
                          style: TextStyle(
                              color: fc.textPrimary,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13),
                          decoration: InputDecoration(
                            hintText: tr('AIzaSy...'),
                            hintStyle: TextStyle(color: fc.textDisabled),
                            filled: true,
                            fillColor: fc.background.withValues(alpha: 0.4),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saving ? null : _saveKey,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: fc.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  _saving ? 'ENREGISTREMENT...' : 'ENREGISTRER',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            if (_hasStoredKey) ...[
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _clearKey,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: fc.danger,
                                  side: BorderSide(color: fc.danger),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                child: Text(tr('EFFACER')),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    title: tr('SERVEUR IA LOCAL'),
                    borderColor: usingLocal ? fc.success : fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usingLocal
                              ? tr('Actif : l\'agent interroge ce serveur. Ni Internet, ni clé API, ni données mobiles.')
                              : tr('Vide : l\'agent passe par Gemini via la 4G. Renseigne l\'adresse du PC pour que tout reste sur le réseau de la machine.'),
                          style: TextStyle(
                              color: usingLocal ? fc.success : fc.textSecondary,
                              fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _localUrlCtrl,
                          style: TextStyle(
                              color: fc.textPrimary,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13),
                          decoration: InputDecoration(
                            labelText: tr('Adresse du serveur'),
                            labelStyle: TextStyle(color: fc.textSecondary),
                            hintText: '192.168.0.42',
                            hintStyle: TextStyle(color: fc.textDisabled),
                            filled: true,
                            fillColor: fc.background.withValues(alpha: 0.4),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: fc.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _localModelCtrl,
                          style: TextStyle(
                              color: fc.textPrimary,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13),
                          decoration: InputDecoration(
                            labelText: tr('Modèle'),
                            labelStyle: TextStyle(color: fc.textSecondary),
                            hintText: 'qwen2.5:7b',
                            hintStyle: TextStyle(color: fc.textDisabled),
                            filled: true,
                            fillColor: fc.background.withValues(alpha: 0.4),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: fc.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveLocalServer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: fc.primary,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(tr('ENREGISTRER'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _probing ? null : _probeLocalServer,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: fc.primary,
                                side: BorderSide(color: fc.primary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              child:
                                  Text(_probing ? tr('TEST...') : tr('TESTER')),
                            ),
                          ],
                        ),
                        if (_localProbe != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _localProbeOk
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                size: 16,
                                color: _localProbeOk ? fc.success : fc.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _localProbe!,
                                  style: TextStyle(
                                      color:
                                          _localProbeOk ? fc.success : fc.danger,
                                      fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    title: tr('MODÈLE IA'),
                    borderColor: fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Flash Lite offre 500 requêtes/jour en gratuit ; les autres modèles 20/jour. Chaque modèle a son propre quota.'),
                          style: TextStyle(color: fc.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: modelState.active.id,
                          isExpanded: true,
                          dropdownColor: fc.surface,
                          style: TextStyle(color: fc.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fc.background.withValues(alpha: 0.4),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          items: [
                            for (final m in kAiModels)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  tr('{} — {} req/j', [m.label, m.rpd]) +
                                      (modelState.exhausted.contains(m.id)
                                          ? tr(' (épuisé)')
                                          : ''),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) {
                            if (id == null) return;
                            modelNotifier.select(
                                kAiModels.firstWhere((e) => e.id == id));
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr('Bascule automatique'),
                                      style: TextStyle(
                                          color: fc.textPrimary,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr('Passe au modèle suivant quand le quota du jour est atteint (429) — cumule les quotas.'),
                                    style: TextStyle(
                                        color: fc.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: modelState.auto,
                              activeThumbColor: fc.primary,
                              onChanged: modelNotifier.setAuto,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    title: tr('PERMISSIONS PAR CATÉGORIE'),
                    borderColor: fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final category in AiActionCategory.values) ...[
                          _permissionRow(
                              fc, category, settings.levelFor(category), notifier),
                          if (category != AiActionCategory.values.last)
                            Divider(color: fc.surfaceBorder, height: 24),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: fc.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: fc.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: fc.warning, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('La lecture de l\'état machine et l\'arrêt d\'urgence sont toujours autorisés sans confirmation, quels que soient ces réglages.'),
                                  style:
                                      TextStyle(color: fc.warning, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionRow(
    ForgeronColorPalette fc,
    AiActionCategory category,
    AiAutonomyLevel level,
    AiAgentSettingsNotifier notifier,
  ) {
    final isAuto = level == AiAutonomyLevel.autoExecute;
    return Row(
      children: [
        Expanded(
          child: Text(tr(category.label),
              style: TextStyle(color: fc.textPrimary, fontSize: 13)),
        ),
        _autonomyChip(fc, 'CONFIRMER', !isAuto,
            () => notifier.setAutonomy(category, AiAutonomyLevel.requireConfirmation)),
        const SizedBox(width: 8),
        _autonomyChip(fc, 'AUTO', isAuto,
            () => notifier.setAutonomy(category, AiAutonomyLevel.autoExecute)),
      ],
    );
  }

  Widget _autonomyChip(
      ForgeronColorPalette fc, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? fc.primary.withValues(alpha: 0.15) : fc.surfaceBright,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? fc.primary : fc.surfaceBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? fc.primary : fc.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
