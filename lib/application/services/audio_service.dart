import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Types de sons industriels disponibles
enum SoundEffect {
  click,      // Clic bouton standard
  navigation, // Transition de page
  alert,      // Alerte mineure / Warning
  alarm,      // Alarme critique / E-Stop
  success,    // Action terminée avec succès
  scan,       // Découverte réseau
}

/// Service Audio pour gérer les retours sonores industriels.
class AudioService {
  final AudioPlayer _alarmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  static const String _basePath = 'assets/audio';
  
  final Map<SoundEffect, String> _soundMap = {
    SoundEffect.click: 'audio/click.wav',
    SoundEffect.navigation: 'audio/nav.wav',
    SoundEffect.alert: 'audio/alert.wav',
    SoundEffect.alarm: 'audio/alarm.wav',
    SoundEffect.success: 'audio/success.wav',
    SoundEffect.scan: 'audio/scan.wav',
  };

  /// Joue un effet sonore spécifique
  Future<void> play(SoundEffect effect) async {
    try {
      final assetPath = _soundMap[effect];
      debugPrint('Tentative de lecture audio : $assetPath');
      if (assetPath != null) {
        final source = AssetSource(assetPath);
        if (effect == SoundEffect.alarm) {
          await _alarmPlayer.setVolume(1.0);
          await _alarmPlayer.setReleaseMode(ReleaseMode.loop); // Loop alarm
          await _alarmPlayer.play(source);
        } else {
          // Fire and forget pour les SFX
          await _sfxPlayer.setVolume(0.5);
          await _sfxPlayer.play(source);
        }
      }
    } catch (e) {
      debugPrint('ERREUR AUDIO : $e');
    }
  }

  /// Arrête l'alarme en cours
  Future<void> stopAlarm() async {
    try {
      await _alarmPlayer.stop();
    } catch (e) {
      debugPrint('ERREUR AUDIO STOP : $e');
    }
  }

  /// Initialise le contexte audio (nécessaire sur le Web après le premier clic)
  Future<void> warmUp() async {
    try {
      debugPrint('AudioService: Warming up audio context...');
      await _sfxPlayer.setSource(AssetSource('audio/click.wav'));
      await _sfxPlayer.stop(); // On charge juste la source
    } catch (e) {
      debugPrint('AudioService: Warmup error: $e');
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _alarmPlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
