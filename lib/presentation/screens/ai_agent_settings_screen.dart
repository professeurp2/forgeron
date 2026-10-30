import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/widgets/readable_width.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../application/providers/ai_agent_settings_provider.dart';
import '../../application/providers/ai_model_provider.dart';
import '../../application/providers/lexicon_provider.dart';
import '../widgets/local_server_assistant.dart';
import '../../application/services/command_understanding.dart' show lexiconLanguageLabel;
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
    // Le champ montre l'adresse COMPLÈTE qui va être interrogée (schéma et
    // port compris), comme après « Enregistrer » : « localhost » seul laisse
    // croire qu'elle est incomplète, et ne dit pas sur quel port on a testé.
    _localUrlCtrl.text = url;
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
        _setProbe(false, 'Serveur joignable à $url, mais aucun modèle chargé.');
      } else if (LocalAiAgentService.isListed(ids, wanted)) {
        // Joignable ET présent ne suffit pas : un contexte trop court fait
        // tronquer le prompt de l'agent en silence — mieux vaut le dire ici
        // que de laisser des réponses étranges le faire découvrir.
        final info = await LocalAiAgentService.probe(url, wanted);
        final problem = LocalAiAgentService.problemFor(wanted, info);
        if (problem != null) {
          _setProbe(false, problem);
        } else {
          final ctx = info.contextTokens;
          _setProbe(
              true,
              'Serveur joignable à $url, modèle « $wanted » disponible — contexte '
              '${ctx == null ? 'non communiqué' : '$ctx tokens'}, '
              '${info.supportsImages ? 'images lues' : 'texte seul (les images ne lui sont pas transmises)'}.');
        }
      } else {
        _setProbe(
            false,
            'Serveur joignable à $url, mais « $wanted » est absent. '
            'Disponibles : ${ids.join(', ')}');
      }
    } catch (e) {
      _setProbe(
          false,
          'Injoignable à $url. Vérifie qu\'Ollama écoute sur 0.0.0.0 '
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
                    title: tr('COMPRÉHENSION DES COMMANDES'),
                    borderColor: fc.surfaceBorder,
                    backgroundColor: fc.surface,
                    child: _LexiconSection(fc: fc),
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
                        LocalServerAssistant(
                          onSaved: () {
                            final st = ref.read(aiAgentSettingsProvider);
                            setState(() {
                              _localUrlCtrl.text = st.localBaseUrl;
                              _localModelCtrl.text = st.localModel;
                            });
                          },
                        ),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: Text(tr('Réglage manuel (avancé)'),
                                style: TextStyle(color: fc.textSecondary, fontSize: 12)),
                            children: [
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
                            hintText: tr('forgeron-qwen'),
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
        _autonomyChip(fc, tr('CONFIRMER'), !isAuto,
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


/// Réglage et état du lexique fermé : ce que l'assistant comprend SANS modèle,
/// dans quelles langues, et à quel point on peut s'y fier.
class _LexiconSection extends ConsumerWidget {
  const _LexiconSection({required this.fc});

  final ForgeronColorPalette fc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(aiAgentSettingsProvider.select((s) => s.lexiconEnabled));
    final load = ref.watch(lexiconLoadProvider);
    final value = load.valueOrNull;
    final lexicon = value?.lexicon;
    final sizes = lexicon?.sizes() ?? const <String, Map<String, int>>{};

    Widget status(String code) {
      final reviewed = lexicon!.isReviewed(code);
      final review = lexicon.reviews[code];
      final text = reviewed
          ? tr('relu par {} le {}', [review?.by ?? '?', review?.on ?? '?'])
          : tr('brouillon : pas encore relu, confirmation toujours demandée');
      final color = reviewed ? fc.success : fc.warning;
      final words = (sizes[code] ?? const {}).values.fold<int>(0, (a, b) => a + b);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(reviewed ? Icons.verified_outlined : Icons.edit_note,
                size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(
                children: [
                  TextSpan(
                      text: lexiconLanguageLabel(code),
                      style: TextStyle(
                          color: fc.textPrimary, fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: '  ·  ${tr('{} mots', [words])}  ·  ',
                      style: TextStyle(color: fc.textSecondary)),
                  TextSpan(text: text, style: TextStyle(color: color)),
                ],
                style: const TextStyle(fontSize: 11.5),
              )),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Comprendre les commandes sans l\'IA'),
                      style: TextStyle(
                          color: fc.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Lit tes ordres courts (état, pause, homing, broche, déplacement, arrêt) dans plusieurs langues, sans réseau ni modèle. L\'arrêt d\'urgence reste toujours immédiat.'),
                    style: TextStyle(color: fc.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              activeThumbColor: fc.primary,
              onChanged: ref.read(aiAgentSettingsProvider.notifier).setLexiconEnabled,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (load.isLoading)
          Text(tr('Chargement du lexique…'),
              style: TextStyle(color: fc.textSecondary, fontSize: 11))
        else if (lexicon == null)
          Text(
            tr('Lexique indisponible : {}. L\'assistant fonctionne comme avant, avec le modèle seul.',
                [value?.failure ?? '?']),
            style: TextStyle(color: fc.danger, fontSize: 11),
          )
        else ...[
          Text(
            tr('Lexique version {} · empreinte {}',
                [lexicon.version, lexicon.fingerprint.substring(0, 8)]),
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 10.5,
                fontFamily: 'JetBrains Mono'),
          ),
          for (final code in lexicon.languages) status(code),
          if ((value?.warnings.length ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              tr('{} avertissement(s) de validation : voir docs/lexique-gouvernance.md',
                  [value!.warnings.length]),
              style: TextStyle(color: fc.warning, fontSize: 10.5),
            ),
          ],
        ],
      ],
    );
  }
}
