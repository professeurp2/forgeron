import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'prefs_guard.dart';

/// Résultat du gardien au démarrage, à montrer UNE fois à l'opérateur.
///
/// `null` : rien à dire (fichier sain, ou plateforme sans fichier JSON).
final prefsRestoreNoticeProvider =
    StateProvider<PrefsGuardReport?>((ref) => null);

Timer? _backupTimer;

/// Installe le gardien sur les plateformes où `shared_preferences` stocke un
/// fichier JSON non atomique (Windows, Linux). Android et macOS passent par le
/// système, qui écrit déjà de façon atomique.
///
/// À appeler AVANT la première lecture des préférences. Ne lève jamais : un
/// gardien indisponible ne doit pas empêcher l'application de démarrer.
Future<PrefsGuardReport?> installPrefsGuard() async {
  if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return null;
  try {
    final dir = await getApplicationSupportDirectory();
    final guard = PrefsFileGuard(dir.path);
    final report = await guard.restoreIfNeeded();
    if (report.action == PrefsGuardAction.restored ||
        report.action == PrefsGuardAction.setAside) {
      debugPrint('[Préférences] $report');
    }
    await guard.backupIfValid();
    _backupTimer?.cancel();
    _backupTimer = guard.start();
    return report;
  } catch (e) {
    debugPrint('[Préférences] gardien indisponible : $e');
    return null;
  }
}

/// Montre, une fois, ce que le gardien a dû faire — **dire la vérité** : une
/// copie de secours est plus ancienne que le fichier perdu, l'opérateur doit le
/// savoir ; et sans copie, il repart de zéro.
class PrefsRestoreNotice extends ConsumerStatefulWidget {
  const PrefsRestoreNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrefsRestoreNotice> createState() => _PrefsRestoreNoticeState();
}

class _PrefsRestoreNoticeState extends ConsumerState<PrefsRestoreNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() {
    if (!mounted) return;
    final report = ref.read(prefsRestoreNoticeProvider);
    if (report == null) return;
    final text = switch (report.action) {
      PrefsGuardAction.restored =>
        'Le fichier de réglages était corrompu (arrêt brutal du PC ?). '
            'Il a été restauré depuis une copie de secours'
            '${report.keys == null ? '' : ' (${report.keys} éléments)'} : '
            'les derniers changements, juste avant l\'incident, peuvent manquer.',
      PrefsGuardAction.setAside =>
        'Le fichier de réglages était corrompu et aucune copie de secours '
            'n\'existait : l\'application repart sur les réglages par défaut. '
            'Ressaisis la connexion à la machine et le serveur IA.',
      _ => null,
    };
    ref.read(prefsRestoreNoticeProvider.notifier).state = null;
    if (text == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 20),
      showCloseIcon: true,
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
