import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications système (barre Android) pour l'agent IA : prévient l'opérateur
/// quand l'agent a une information ou un problème à présenter, y compris quand
/// l'app est en arrière-plan.
///
/// Singleton initialisé au démarrage ([init]). No-op hors Android/iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'forgeron_ai';
  static const _channelName = 'Agent IA';
  static const _channelDesc = 'Alertes et réponses de l\'assistant IA Forgeron';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialise le plugin et le canal Android. À appeler une fois au démarrage.
  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
        // Android 13+ : demande la permission de notifier.
        await androidImpl.requestNotificationsPermission();
      }
      _ready = true;
    } catch (_) {
      // Init non critique : en cas d'échec, l'app fonctionne sans notifs.
    }
  }

  /// Affiche une notification. [problem] relève l'importance visuelle.
  Future<void> show(String title, String body, {bool problem = false}) async {
    if (!_supported) return;
    if (!_ready) await init();
    if (!_ready) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          color: problem ? const Color(0xFFE53935) : const Color(0xFFFF6D00),
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _plugin.show(_id++, title, body, details);
    } catch (_) {
      // Affichage non critique.
    }
  }
}
