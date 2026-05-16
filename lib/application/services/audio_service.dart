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
  final AudioPlayer _player = AudioPlayer();
  
  // Utilisation de liens vers des fichiers audio courts et nets (Assets à ajouter plus tard)
  // Pour le prototype, nous pouvons utiliser des sons système ou des URLs si nécessaire.
  // Idéalement, nous utiliserons des fichiers locaux dans assets/audio/
  
  static const String _basePath = 'assets/audio';
  
  final Map<SoundEffect, String> _soundMap = {
    SoundEffect.click: 'audio/click.mp3',
    SoundEffect.navigation: 'audio/nav.mp3',
    SoundEffect.alert: 'audio/alert.mp3',
    SoundEffect.alarm: 'audio/alarm.mp3',
    SoundEffect.success: 'audio/success.mp3',
    SoundEffect.scan: 'audio/scan.mp3',
  };

  /// Joue un effet sonore spécifique
  Future<void> play(SoundEffect effect) async {
    try {
      final assetPath = _soundMap[effect];
      debugPrint('Tentative de lecture audio : $assetPath');
      if (assetPath != null) {
        // Sur le Web, le volume doit parfois être ré-appliqué
        await _player.setVolume(0.5);
        await _player.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('ERREUR AUDIO : $e');
    }
  }

  /// Initialise le contexte audio (nécessaire sur le Web après le premier clic)
  Future<void> warmUp() async {
    try {
      debugPrint('AudioService: Warming up audio context...');
      await _player.setSource(AssetSource('audio/click.mp3'));
      await _player.stop(); // On charge juste la source
    } catch (e) {
      debugPrint('AudioService: Warmup error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
