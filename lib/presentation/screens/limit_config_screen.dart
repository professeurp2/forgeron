import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/di_providers.dart';
import '../../application/providers/config_provider.dart';
import '../../application/providers/limit_config_provider.dart';

/// Configuration des fins de course (pins + hard/soft limits) dans FluidNC,
/// depuis l'app. Écriture SÛRE : ne remplace que les clés existantes ; les
/// clés absentes sont signalées (à ajouter via la WebUI, pour ne jamais
/// corrompre un config.yaml critique).
class LimitConfigScreen extends ConsumerStatefulWidget {
  const LimitConfigScreen({super.key});

  @override
  ConsumerState<LimitConfigScreen> createState() => _LimitConfigScreenState();
}

class _LimitConfigScreenState extends ConsumerState<LimitConfigScreen> {
  static const _axes = ['X', 'Y', 'Z', 'A', 'C'];
  final _neg = List.generate(5, (_) => TextEditingController());
  final _pos = List.generate(5, (_) => TextEditingController());
  final _all = List.generate(5, (_) => TextEditingController());
  final _hard = List.filled(5, false, growable: false).toList();
  final _soft = List.filled(5, false, growable: false).toList();
  bool _init = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [..._neg, ..._pos, ..._all]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(List<AxisLimitConfig> cfg) {
    for (int i = 0; i < 5 && i < cfg.length; i++) {
      _neg[i].text = cfg[i].negPin;
      _pos[i].text = cfg[i].posPin;
      _all[i].text = cfg[i].allPin;
      _hard[i] = cfg[i].hardLimits;
      _soft[i] = cfg[i].softLimits;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final async = ref.watch(limitConfigProvider);

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        elevation: 0,
        foregroundColor: fc.textPrimary,
        title: const Text('FINS DE COURSE — CONFIG',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: fc.surfaceBorder),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Config indisponible : $e',
                    style: TextStyle(color: fc.textDisabled)))),
        data: (cfg) {
          if (!_init) {
            _init = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _load(cfg));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fc.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: fc.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Format des pins FluidNC : ex. gpio.16:low:pu (broche 16, actif '
                  'bas, pull-up). NO_PIN pour désactiver. Valide d\'abord ton '
                  'câblage dans « Test des fins de course ».',
                  style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < 5; i++) _axisCard(fc, i),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fc.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(
                      _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
                      size: 18),
                  label: Text(_saving ? 'ENREGISTREMENT…' : 'ENREGISTRER DANS FLUIDNC',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _axisCard(ForgeronColorPalette fc, int i) {
    final color = [fc.axisX, fc.axisY, fc.axisZ, fc.axisA, fc.axisC][i];
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: fc.textDisabled, fontSize: 11),
          isDense: true,
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
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.6))),
            child: Text(_axes[i],
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Text('Axe ${_axes[i]}',
              style: TextStyle(
                  color: fc.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _neg[i], style: TextStyle(color: fc.textPrimary, fontSize: 13), decoration: deco('limit_neg_pin')),
        const SizedBox(height: 8),
        TextField(controller: _pos[i], style: TextStyle(color: fc.textPrimary, fontSize: 13), decoration: deco('limit_pos_pin')),
        const SizedBox(height: 8),
        TextField(controller: _all[i], style: TextStyle(color: fc.textPrimary, fontSize: 13), decoration: deco('limit_all_pin')),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _hard[i],
          activeThumbColor: fc.danger,
          onChanged: (v) => setState(() => _hard[i] = v),
          title: Text('hard_limits (arrêt matériel immédiat)',
              style: TextStyle(color: fc.textPrimary, fontSize: 12)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _soft[i],
          activeThumbColor: fc.primary,
          onChanged: (v) => setState(() => _soft[i] = v),
          title: Text('soft_limits (bornes logicielles, exige homing)',
              style: TextStyle(color: fc.textPrimary, fontSize: 12)),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final fc = context.fc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fc.surface,
        title: Text('Enregistrer & redémarrer ?',
            style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        content: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: fc.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Écrit dans config.yaml puis redémarre FluidNC. La liaison sera '
              'coupée quelques secondes (reconnexion auto).',
              style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: TextStyle(color: fc.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: fc.primary, foregroundColor: Colors.white),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final okColor = fc.success;
    final errColor = fc.error;
    try {
      final yaml = ref.read(configResultProvider).valueOrNull?.yaml;
      if (yaml == null || !yaml.contains('axes:')) {
        throw Exception('config.yaml non chargé (machine hors ligne ?)');
      }
      final byAxis = <String, Map<String, String>>{};
      final requested = <String>{};
      for (int i = 0; i < 5; i++) {
        final a = _axes[i].toLowerCase();
        final m = <String, String>{
          'soft_limits': _soft[i] ? 'true' : 'false',
          'hard_limits': _hard[i] ? 'true' : 'false',
        };
        if (_neg[i].text.trim().isNotEmpty) m['limit_neg_pin'] = _neg[i].text.trim();
        if (_pos[i].text.trim().isNotEmpty) m['limit_pos_pin'] = _pos[i].text.trim();
        if (_all[i].text.trim().isNotEmpty) m['limit_all_pin'] = _all[i].text.trim();
        byAxis[a] = m;
        for (final k in m.keys) {
          requested.add('$a.$k');
        }
      }
      final res = patchLimitConfig(yaml, byAxis);
      final missing = requested.difference(res.applied);

      try {
        await ref.read(configRepositoryProvider).saveConfig(res.yaml);
        ref.invalidate(configResultProvider);
        ref.read(machineRepositoryProvider).sendRaw('\$Bye\n');
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(missing.isEmpty
              ? 'Config enregistrée — redémarrage de FluidNC…'
              : 'Enregistré. Clés absentes (à ajouter via WebUI) : '
                  '${missing.join(', ')}'),
          backgroundColor: missing.isEmpty ? okColor : fc.warning,
          duration: const Duration(seconds: 6),
        ));
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: res.yaml));
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: const Text(
              'Écriture auto impossible. Config copiée : colle-la dans la WebUI '
              'FluidNC (192.168.0.1 → Files → config.yaml), puis reboot.'),
          backgroundColor: errColor,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Échec : $e'), backgroundColor: errColor));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
