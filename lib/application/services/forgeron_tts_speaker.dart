import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/i18n/waxal_voice_engine.dart';

/// Résultat d'une demande de lecture vocale.
class TtsSpeakOutcome {
  final PreparedVoiceUtterance prepared;
  final bool voiceMissingForPreferredLanguage;

  const TtsSpeakOutcome({
    required this.prepared,
    required this.voiceMissingForPreferredLanguage,
  });
}

/// Coordinateur centralisé de synthèse vocale (TTS) de Forgeron.
///
/// Résout trois problèmes critiques :
/// 1. **Course critique (Double-Speaking)** : Empêche `OmnipresentAiShell` et
///    `AiConsoleScreen` / `AiAssistantScreen` de lancer deux lectures
///    simultanées sur le même synthétiseur natif.
/// 2. **Voix anglaise et française naturelles sous Windows** : Le plugin
///    `flutter_tts` sous Windows (WinRT) ignore les voix SAPI5 classiques
///    (comme `Microsoft Zira Desktop` `en-US`) et sélectionne toujours la
///    dernière voix OneCore (`Microsoft Paul`, très robotique) au lieu de
///    `Microsoft Julie` (moteur Natural Unit Selection `.SPEECHUX.NUS`).
///    Ce service pilote un démon COM `SAPI.SpVoice` persistant capable d'utiliser
///    à la fois les voix OneCore (`Julie`) et SAPI5 (`Zira`) avec support
///    complet du balisage **SSML 1.0** (inflexions, pauses respiratoires).
/// 3. **Prosodie humaine sur Android / Mobile** : Sélectionne la meilleure voix
///    installée et rythme la lecture par segments conversationnels avec
///    modulation de hauteur (ouverture chaleureuse, corps posé, question finale).
class ForgeronTtsSpeaker {
  ForgeronTtsSpeaker._();

  static final ForgeronTtsSpeaker instance = ForgeronTtsSpeaker._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  Future<void>? _initFuture;

  List<String> _availableLocales = const [];
  List<Map<String, String>> _availableVoices = const [];

  // Démon SAPI5 + OneCore persistant sous Windows pour SSML et accès à Zira (en-US) + Julie (fr-FR)
  Process? _winSapiProcess;
  bool _winSapiReady = false;
  Completer<void>? _winSapiReadyCompleter;

  int _utteranceSerial = 0;
  String? _lastAutoText;
  DateTime? _lastAutoTime;

  List<String> get availableLocales => _availableLocales;

  /// Initialise le moteur TTS (idempotent).
  Future<void> ensureInitialized() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    final locales = <String>{'fr-FR', 'en-US'};
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.02);
      final rawLangs = await _flutterTts.getLanguages;
      if (rawLangs is Iterable) {
        for (final e in rawLangs) {
          if (e != null && '$e'.trim().isNotEmpty) {
            locales.add('$e'.trim());
          }
        }
      }
      final rawVoices = await _flutterTts.getVoices;
      if (rawVoices is Iterable) {
        final parsed = <Map<String, String>>[];
        for (final v in rawVoices) {
          if (v is Map) {
            final name = '${v['name'] ?? ''}'.trim();
            final locale = '${v['locale'] ?? ''}'.trim();
            if (name.isNotEmpty && locale.isNotEmpty) {
              parsed.add({'name': name, 'locale': locale});
              locales.add(locale);
            }
          }
        }
        _availableVoices = parsed;
      }
    } catch (e) {
      debugPrint('ForgeronTtsSpeaker FlutterTts init warning: $e');
    }

    if (!kIsWeb && Platform.isWindows) {
      await _startWindowsSapiDaemon();
    }

    _availableLocales = locales.toList();
    _initialized = true;
  }

  /// Démarre un processus PowerShell léger maintenant une instance COM
  /// `SAPI.SpVoice` prête en mémoire (< 30 ms de latence par phrase) qui voit
  /// à la fois les voix OneCore (`Microsoft Julie`) et SAPI5 (`Microsoft Zira`).
  Future<void> _startWindowsSapiDaemon() async {
    if (_winSapiProcess != null) return;
    try {
      const psScript = r'''
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$voice = New-Object -ComObject SAPI.SpVoice
$voice.Volume = 100

$allTokens = @()
try {
  $catOneCore = New-Object -ComObject SAPI.SpObjectTokenCategory
  $catOneCore.SetId("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices", $false)
  foreach ($t in $catOneCore.EnumerateTokens()) { $allTokens += $t }
} catch {}
try {
  foreach ($t in $voice.GetVoices()) { $allTokens += $t }
} catch {}

function Select-BestVoice([string]$langPrefix) {
  $isEn = $langPrefix -match '^en'
  $langHex = if ($isEn) { '^(409|809|c09|1009)$' } else { '^(40c|80c|c0c|0c)$' }
  $candidates = @()
  foreach ($t in $allTokens) {
    try {
      $l = $t.GetAttribute("Language")
      $d = $t.GetDescription()
      if ($l -match $langHex -or ($isEn -and $d -match 'English|Zira|David|Aria|Jenny|Hazel') -or ((-not $isEn) -and $d -match 'French|Julie|Hortense|Denise|Paul')) {
        $candidates += $t
      }
    } catch {}
  }
  if ($candidates.Count -eq 0) { return $null }
  $prefs = if ($isEn) { @('Natural', 'Neural', 'Aria', 'Jenny', 'Zira', 'Hazel', 'David') } else { @('Natural', 'Neural', 'Julie', 'Denise', 'Hortense', 'Paul') }
  foreach ($p in $prefs) {
    foreach ($c in $candidates) {
      if ($c.GetDescription() -match $p) { return $c }
    }
  }
  return $candidates[0]
}

Write-Output "READY"
while (($line = [Console]::ReadLine()) -ne $null) {
  $trimmed = $line.Trim()
  if ($trimmed -eq "STOP") {
    try { $voice.Speak("", 2) | Out-Null } catch {}
    continue
  }
  if ($trimmed.StartsWith("SPEAK|")) {
    $parts = $trimmed.Split("|", 3)
    if ($parts.Length -eq 3) {
      $lang = $parts[1]
      try {
        $ssml = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($parts[2]))
        $best = Select-BestVoice $lang
        if ($best -ne $null) { $voice.Voice = $best }
        $voice.Speak($ssml, 11) | Out-Null
      } catch {
        try {
          $plain = $ssml -replace '<[^>]+>', ' '
          $voice.Speak($plain, 3) | Out-Null
        } catch {}
      }
    }
  }
}
''';

      final proc = await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          psScript,
        ],
      );
      _winSapiProcess = proc;

      final readyCompleter = Completer<void>();
      _winSapiReadyCompleter = readyCompleter;
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim() == 'READY' && !readyCompleter.isCompleted) {
          _winSapiReady = true;
          readyCompleter.complete();
        }
      });
      proc.stderr.drain<void>();
      proc.exitCode.then((_) {
        _winSapiProcess = null;
        _winSapiReady = false;
      });

      // Démarrage à froid de PowerShell + énumération des voix OneCore : peut
      // dépasser 2 s au premier lancement. On attend jusqu'à 8 s.
      await readyCompleter.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('ForgeronTtsSpeaker Windows SAPI daemon fallback: $e');
      _winSapiProcess = null;
      _winSapiReady = false;
    }
  }

  /// Interrompt immédiatement toute lecture vocale en cours.
  Future<void> stop() async {
    _utteranceSerial++;
    if (!kIsWeb && Platform.isWindows && _winSapiProcess != null) {
      try {
        _winSapiProcess!.stdin.writeln('STOP');
      } catch (_) {}
    }
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  /// Lit [rawText] avec une prosodie humaine dans la langue appropriée.
  ///
  /// Si [isAutoTrigger] vaut `true` (lecture automatique à l'arrivée d'une
  /// réponse IA), déduplique les appels identiques rapprochés pour éviter
  /// qu'un écran et l'overlay ne lisent deux fois la même réponse.
  Future<TtsSpeakOutcome?> speak(
    String rawText, {
    required String preferredLanguageId,
    bool isAutoTrigger = false,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    if (isAutoTrigger) {
      final now = DateTime.now();
      if (_lastAutoText == trimmed &&
          _lastAutoTime != null &&
          now.difference(_lastAutoTime!) < const Duration(milliseconds: 2500)) {
        return null;
      }
      _lastAutoText = trimmed;
      _lastAutoTime = now;
    }

    await ensureInitialized();
    final mySerial = ++_utteranceSerial;

    final prepared = WaxalVoiceEngine.prepareForTts(
      trimmed,
      preferredLanguageId: preferredLanguageId,
      availableVoices: _availableLocales,
    );

    if (prepared.spokenText.isEmpty) {
      return TtsSpeakOutcome(
        prepared: prepared,
        voiceMissingForPreferredLanguage: false,
      );
    }

    // 1. Chemin Windows SAPI5 + OneCore avec SSML (Zira en-US / Julie fr-FR)
    if (!kIsWeb && Platform.isWindows) {
      if (_winSapiProcess == null) {
        await _startWindowsSapiDaemon();
      }
      // Démon lancé mais pas encore prêt : on attend plutôt que de basculer
      // sur le repli WinRT (souvent muet sous Windows).
      if (_winSapiProcess != null && !_winSapiReady) {
        final pending = _winSapiReadyCompleter;
        if (pending != null && !pending.isCompleted) {
          await pending.future
              .timeout(const Duration(seconds: 8), onTimeout: () {});
        }
      }
      if (mySerial != _utteranceSerial) return null;
      if (_winSapiProcess != null && _winSapiReady) {
        try {
          await _flutterTts.stop();
        } catch (_) {}
        try {
          final payload = prepared.ssmlText.isNotEmpty
              ? prepared.ssmlText
              : prepared.spokenText;
          final b64 = base64Encode(utf8.encode(payload));
          final targetLocale = prepared.selectedVoiceLocale ??
              (prepared.languageId == 'en' ? 'en-US' : 'fr-FR');
          _winSapiProcess!.stdin.writeln('SPEAK|$targetLocale|$b64');
          await _winSapiProcess!.stdin.flush();
          return TtsSpeakOutcome(
            prepared: prepared,
            voiceMissingForPreferredLanguage: false,
          );
        } catch (e) {
          debugPrint('ForgeronTtsSpeaker SAPI write error: $e');
        }
      }
    }

    // 2. Chemin FlutterTts (Android, iOS, ou repli Windows)
    try {
      await _flutterTts.stop();
      if (mySerial != _utteranceSerial) return null;

      final voiceLocale = prepared.selectedVoiceLocale;
      if (voiceLocale != null) {
        await _selectBestFlutterTtsVoice(voiceLocale);
      }

      final chunks = prepared.conversationalChunks.isNotEmpty
          ? prepared.conversationalChunks
          : <String>[prepared.spokenText];

      if (chunks.length <= 1) {
        await _flutterTts.setPitch(1.03);
        await _flutterTts.setSpeechRate(prepared.speechRate);
        await _flutterTts.speak(prepared.spokenText);
      } else {
        // Lecture segmentée avec inflexion humaine entre l'accroche, le corps
        // technique et la question finale
        try {
          await _flutterTts.awaitSpeakCompletion(true);
        } catch (_) {}

        for (var i = 0; i < chunks.length; i++) {
          if (mySerial != _utteranceSerial) break;
          final chunk = chunks[i];
          final isFirst = i == 0;
          final isLast = i == chunks.length - 1;
          final isQuestion = chunk.endsWith('?');

          final double pitch = (isQuestion && isLast)
              ? 1.05
              : (isFirst ? 1.03 : 1.01);
          final double rate = (isQuestion && isLast)
              ? (prepared.speechRate - 0.02).clamp(0.38, 0.65)
              : prepared.speechRate;

          await _flutterTts.setPitch(pitch);
          await _flutterTts.setSpeechRate(rate);
          await _flutterTts.speak(chunk);

          if (i < chunks.length - 1 && mySerial == _utteranceSerial) {
            await Future<void>.delayed(
              Duration(milliseconds: isQuestion ? 220 : 140),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ForgeronTtsSpeaker FlutterTts speak error: $e');
    }

    final voiceMissing = prepared.selectedVoiceLocale == null &&
        prepared.waxalProfile == null;
    return TtsSpeakOutcome(
      prepared: prepared,
      voiceMissingForPreferredLanguage: voiceMissing,
    );
  }

  Future<void> _selectBestFlutterTtsVoice(String targetLocale) async {
    await _flutterTts.setLanguage(targetLocale);
    if (_availableVoices.isEmpty) return;

    final langPrefix =
        targetLocale.split(RegExp(r'[-_]')).first.toLowerCase();
    final matching = _availableVoices.where((v) {
      final loc = (v['locale'] ?? '').toLowerCase();
      return loc.startsWith(langPrefix);
    }).toList();
    if (matching.isEmpty) return;

    // Préfère les voix naturelles / neurales / Julie / Zira quand présentes
    const preferredKeywords = [
      'natural',
      'neural',
      'wavenet',
      'julie',
      'zira',
      'denise',
      'vivienne',
      'ava',
      'aria',
      'enhanced',
      'premium',
      'network',
      'hortense',
    ];
    for (final kw in preferredKeywords) {
      for (final v in matching) {
        if ((v['name'] ?? '').toLowerCase().contains(kw)) {
          try {
            await _flutterTts.setVoice(v);
            return;
          } catch (_) {}
        }
      }
    }
  }
}

