import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/ai_agent_settings_provider.dart';
import '../../application/services/ollama_discovery.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';

/// Connexion au modèle local en trois gestes, sans adresse IP ni nom de modèle :
/// « Chercher » (balaie le réseau), choisir un modèle dans la liste, « Utiliser ».
///
/// Les champs manuels existent toujours dans les réglages, repliés : ils servent
/// aux cas que la recherche ne couvre pas (autre sous-réseau, autre port).
class LocalServerAssistant extends ConsumerStatefulWidget {
  const LocalServerAssistant({super.key, this.discovery, this.onSaved});

  /// Injectable pour les tests.
  final OllamaDiscovery? discovery;

  /// Appelé quand une adresse et un modèle viennent d'être enregistrés (pour que
  /// les champs manuels les reflètent).
  final VoidCallback? onSaved;

  @override
  ConsumerState<LocalServerAssistant> createState() => _LocalServerAssistantState();
}

class _LocalServerAssistantState extends ConsumerState<LocalServerAssistant> {
  late final OllamaDiscovery _discovery = widget.discovery ?? OllamaDiscovery();

  bool _scanning = false;
  double _progress = 0;
  List<OllamaServer>? _found;
  OllamaServer? _selected;
  String? _model;

  /// Modèle choisi pour lire les images (`null` = aucun).
  String? _visionModel;
  String? _message;
  bool _messageOk = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiAgentSettingsProvider);
    if (s.localBaseUrl.isNotEmpty) _checkCurrent(s.localBaseUrl, s.localModel);
  }

  /// Contrôle silencieux de ce qui est déjà enregistré.
  Future<void> _checkCurrent(String url, String model) async {
    final d = await _discovery.diagnose(url, wantedModel: model);
    if (!mounted) return;
    setState(() {
      _messageOk = d.ok;
      _message = d.ok
          ? tr('Connecté à {} · modèle « {} ».', [d.server!.host, model])
          : d.message;
      _showHelp = !d.ok;
    });
  }

  Future<void> _search() async {
    setState(() {
      _scanning = true;
      _progress = 0;
      _found = null;
      _selected = null;
      _message = null;
      _showHelp = false;
    });
    var servers = await _discovery.scan(onProgress: (p) {
      if (mounted && (p - _progress) > 0.04) setState(() => _progress = p);
    });
    servers = [for (final s in servers) await _discovery.describe(s)];
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _found = servers;
      if (servers.isEmpty) {
        _messageOk = false;
        _message = tr('Aucun serveur trouvé sur ce réseau.');
        _showHelp = true;
      } else {
        _pick(servers.first);
        _message = null;
      }
    });
  }

  void _pick(OllamaServer s) {
    _selected = s;
    _model = OllamaDiscovery.recommend(s.models)?.name;
    _visionModel = OllamaDiscovery.recommendVision(s.models, main: _model)?.name;
  }

  /// Le modèle principal change : le modèle d'images ne peut pas être lui-même
  /// (s'il voit, il s'en charge seul).
  void _pickMain(String name) {
    _model = name;
    if (_visionModel == name) _visionModel = null;
    final seeing = _selected?.models.where((m) => m.name == name && m.supportsVision);
    if (seeing != null && seeing.isNotEmpty) _visionModel = null;
  }

  Future<void> _use() async {
    final s = _selected;
    final m = _model;
    if (s == null || m == null) return;
    final n = ref.read(aiAgentSettingsProvider.notifier);
    n.setLocalBaseUrl(s.url);
    n.setLocalModel(m);
    n.setLocalVisionModel(_visionModel ?? '');
    widget.onSaved?.call();
    final d = await _discovery.diagnose(s.url, wantedModel: m);
    if (!mounted) return;
    setState(() {
      _found = null;
      _messageOk = d.ok;
      _message = d.ok
          ? (_visionModel == null
              ? tr('Connecté à {} · modèle « {} ». L\'assistant fonctionne sans Internet.', [s.host, m])
              : tr('Connecté à {} · modèle « {} », images lues par « {} ». L\'assistant fonctionne sans Internet.', [s.host, m, _visionModel]))
          : d.message;
    });
  }

  void _disconnect() {
    ref.read(aiAgentSettingsProvider.notifier).setLocalBaseUrl('');
    widget.onSaved?.call();
    setState(() {
      _messageOk = false;
      _message = tr('Serveur local retiré : l\'assistant repasse par Gemini (Internet requis).');
      _showHelp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final saved = ref.watch(aiAgentSettingsProvider.select((s) => s.localBaseUrl));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _search,
            icon: _scanning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, value: _progress == 0 ? null : _progress))
                : const Icon(Icons.search),
            label: Text(
              _scanning ? tr('RECHERCHE EN COURS…') : tr('CHERCHER MON SERVEUR'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_found != null && _found!.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final s in _found!) _serverCard(fc, s),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _model == null ? null : _use,
              style: ElevatedButton.styleFrom(
                backgroundColor: fc.success,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tr('UTILISER CE SERVEUR'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_messageOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16, color: _messageOk ? fc.success : fc.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_message!,
                    style: TextStyle(
                        color: _messageOk ? fc.success : fc.danger, fontSize: 11.5)),
              ),
            ],
          ),
        ],
        if (saved.isNotEmpty && !_scanning)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _disconnect,
              child: Text(tr('Ne plus utiliser de serveur local'),
                  style: TextStyle(color: fc.textSecondary, fontSize: 11)),
            ),
          ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _showHelp = !_showHelp),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(_showHelp ? Icons.expand_less : Icons.help_outline,
                    size: 16, color: fc.textSecondary),
                const SizedBox(width: 6),
                Text(tr('Ça ne marche pas ?'),
                    style: TextStyle(color: fc.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ),
        if (_showHelp)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kOllamaHelpSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${i + 1}. ${tr(kOllamaHelpSteps[i])}',
                        style: TextStyle(
                            color: fc.textSecondary, fontSize: 11.5, height: 1.35)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _serverCard(ForgeronColorPalette fc, OllamaServer s) {
    final selected = identical(_selected, s);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? fc.primary : fc.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _pick(s)),
            child: Row(
              children: [
                Icon(Icons.computer, size: 18, color: fc.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr('PC trouvé : {}', [s.host]),
                      style: TextStyle(
                          color: fc.textPrimary, fontWeight: FontWeight.w700)),
                ),
                if (selected) Icon(Icons.check, size: 18, color: fc.primary),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (s.models.isEmpty)
            Text(tr('Ollama répond, mais aucun modèle n\'est installé sur ce PC.'),
                style: TextStyle(color: fc.danger, fontSize: 11.5))
          else if (selected)
            for (final m in s.models) _modelRow(fc, m),
        ],
      ),
    );
  }

  Widget _modelRow(ForgeronColorPalette fc, OllamaModel m) {
    final chosen = _model == m.name;
    final recommended = OllamaDiscovery.recommend(_selected!.models)?.name == m.name;
    final seesOnly = !m.usable && m.supportsVision && m.unusableReason == 'tools';
    final note = seesOnly
        ? tr('lit les images, ne pilote pas la machine')
        : !m.usable
            ? (m.unusableReason == 'context'
                ? tr('contexte trop court')
                : tr('ne sait pas piloter la machine'))
            : recommended
                ? tr('recommandé')
                : null;
    final canWatch = m.supportsVision && m.name != _model;
    final watching = _visionModel == m.name;
    return InkWell(
      onTap: m.usable ? () => setState(() => _pickMain(m.name)) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: !m.usable
                  ? fc.textDisabled
                  : (chosen ? fc.primary : fc.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(m.name,
                  style: TextStyle(
                      color: m.usable ? fc.textPrimary : fc.textDisabled,
                      fontSize: 12.5,
                      fontFamily: 'JetBrains Mono')),
            ),
            if (note != null)
              Flexible(
                child: Text(note,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: (m.usable || seesOnly) ? fc.success : fc.warning,
                        fontSize: 10.5)),
              ),
            if (canWatch)
              IconButton(
                tooltip: tr('Pour lire les images'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                padding: EdgeInsets.zero,
                iconSize: 20,
                onPressed: () => setState(() => _visionModel = watching ? null : m.name),
                icon: Icon(watching ? Icons.visibility : Icons.visibility_outlined,
                    color: watching ? fc.primary : fc.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
