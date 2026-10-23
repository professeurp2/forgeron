import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/camera/esp32cam_repository.dart';
import '../../data/mock/mock_camera_repository.dart';
import '../../domain/repositories/camera_repository.dart';
import 'machine_provider.dart';
import 'streaming_provider.dart';

/// IP par défaut de l'ESP32-CAM.
///
/// La caméra rejoint le point d'accès de FluidNC, qui se donne 192.168.0.1 et
/// distribue en 192.168.0.x. On la fixe en .50 **côté firmware** (IP statique)
/// plutôt que de dépendre d'un bail DHCP : au redémarrage de la machine
/// l'adresse ne bouge pas, et l'utilisateur n'a rien à rechercher.
const kDefaultCameraIp = '192.168.0.50';

final cameraIpProvider = StateProvider<String>((ref) => kDefaultCameraIp);

/// La caméra est-elle utilisable ?
///
/// Dérivé de la **détection automatique**, jamais d'un réglage à cocher :
/// l'opérateur connecte son téléphone au WiFi de la machine, et l'application
/// se débrouille. Une machine sans caméra reste parfaitement utilisable — le
/// panneau retombe simplement sur le simulateur 3D.
final cameraEnabledProvider = Provider<bool>(
    (ref) => ref.watch(cameraDetectionProvider).status == CameraStatus.found);

/// Résolution demandée au capteur. VGA par défaut : au-delà, l'ESP32-CAM
/// sature l'AP de la machine pour un gain de lisibilité nul sur un téléphone.
final cameraResolutionProvider =
    StateProvider<CameraResolution>((ref) => CameraResolution.vga);

// ── Dépôt ────────────────────────────────────────────────────────────────────

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  if (ref.watch(isSimulationModeProvider)) {
    return MockCameraRepository();
  }

  final repo = Esp32CamRepository(ref.watch(cameraIpProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

// ── Garde-fou bande passante ────────────────────────────────────────────────

/// Vrai quand la machine **ne coupe pas** — la radio est alors libre.
///
/// La caméra et le téléphone sont tous les deux clients du point d'accès porté
/// par l'ESP32 FluidNC : une seule radio 2,4 GHz pour tout le monde, et les
/// trames caméra transitent par le contrôleur lui-même.
///
/// Pendant une passe on ne ralentit donc pas l'affichage — voir couper est
/// précisément le moment où la caméra sert — mais on **allège les images**
/// ([kCameraMachiningQuality]) pour libérer du temps d'antenne, et on ajoute un
/// léger frein ([cameraSnapshotIntervalProvider]).
final cameraLiveAllowedProvider = Provider<bool>((ref) {
  return !ref.watch(streamingProvider);
});

/// Délai **ajouté** entre deux captures pendant un usinage.
///
/// À lire comme un frein, pas comme une période : les captures étant
/// séquentielles, la cadence réelle vaut ce délai plus le temps d'aller-retour.
///
/// Volontairement court. Le streaming G-code ne consomme presque pas de débit
/// (quelques centaines d'octets par ligne) — ce qu'il craint, c'est le **temps
/// d'antenne** que chaque trame caméra occupe sur la radio de l'ESP32 qui
/// porte l'AP. On agit donc sur le poids des images ([kCameraMachiningQuality])
/// plutôt qu'en espaçant les captures : c'est ce qui permet de rester fluide
/// pendant la coupe, moment où regarder l'outil a le plus de valeur.
final cameraSnapshotIntervalProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 200));

/// Délai ajouté quand la machine ne coupe pas. Presque nul : plus rien ne se
/// dispute la radio, autant afficher le maximum que le réseau accepte.
const kCameraIdleGap = Duration(milliseconds: 100);

/// Compression JPEG pendant un usinage (10 = meilleure, 63 = plus comprimée).
/// Environ deux fois moins d'octets par trame qu'en [kCameraIdleQuality], donc
/// deux fois moins de temps d'antenne volé au contrôleur — pour une perte à
/// peine visible sur l'écran d'un téléphone.
const kCameraMachiningQuality = 20;

/// Compression au repos : la radio est libre, autant avoir une image nette
/// pour inspecter le montage ou une pièce finie.
const kCameraIdleQuality = 12;

// ── Capture ──────────────────────────────────────────────────────────────────

/// Dernière image capturée. `ref.invalidate(cameraSnapshotProvider)` déclenche
/// une nouvelle capture — c'est le seul mécanisme de rafraîchissement, aucun
/// timer n'est armé ici : c'est le widget qui décide de son rythme et qui
/// s'arrête proprement quand il quitte l'écran.
final cameraSnapshotProvider = FutureProvider.autoDispose<Uint8List>((ref) {
  // Sans ce délai de grâce, chaque changement d'onglet relance une capture.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 30), link.close);
  ref.onDispose(timer.cancel);

  return ref.watch(cameraRepositoryProvider).snapshot();
});

/// Vrai si la caméra répond. Sondé à la demande (écran de réglages), pas en
/// continu.
final cameraOnlineProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(cameraRepositoryProvider).ping();
});

// ── Persistance ──────────────────────────────────────────────────────────────

Future<void> loadCameraPreferences(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(cameraIpProvider.notifier).state =
      prefs.getString('camera_ip') ?? kDefaultCameraIp;

  // Rien à activer : on part chercher la caméra tout de suite.
  ref.read(cameraDetectionProvider.notifier).startAutoDetect();
}

/// Sert uniquement au cas particulier d'une caméra déplacée hors de son
/// adresse statique. Le fonctionnement nominal ne passe jamais par là.
Future<void> saveCameraIp(WidgetRef ref, String ip) async {
  ref.read(cameraIpProvider.notifier).state = ip.trim();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('camera_ip', ip.trim());
  await ref.read(cameraDetectionProvider.notifier).probe();
}

// ── Détection automatique ───────────────────────────────────────────────────

enum CameraStatus { searching, found, absent }

class CameraDetection {
  const CameraDetection({required this.status, this.reason});

  final CameraStatus status;

  /// Pourquoi la caméra n'a pas été trouvée — affiché dans les réglages, pour
  /// que « pas de caméra » ne soit jamais un silence inexplicable.
  final String? reason;
}

/// Cherche la caméra toute seule.
///
/// L'opérateur connecte son téléphone au WiFi de la machine, point final.
/// L'adresse étant statique et connue, il n'y a rien à scanner : on sonde
/// directement, et on retente tant qu'on ne trouve pas — le téléphone rejoint
/// souvent le réseau APRÈS l'ouverture de l'application.
class CameraDetector extends StateNotifier<CameraDetection> {
  CameraDetector(this._ref)
      : super(const CameraDetection(status: CameraStatus.searching));

  final Ref _ref;
  Timer? _retry;
  bool _disposed = false;

  static const _retryInterval = Duration(seconds: 20);

  void startAutoDetect() {
    if (!_disposed) unawaited(probe());
  }

  Future<void> probe() async {
    if (_disposed) return;
    _retry?.cancel();
    state = const CameraDetection(status: CameraStatus.searching);

    final ip = _ref.read(cameraIpProvider).trim();

    // Garde-fou explicite : la caméra et le contrôleur ne peuvent pas partager
    // une adresse. Sans ce test, une IP mal saisie ferait bombarder l'ESP32
    // qui exécute le G-code de requêtes de capture pendant l'usinage.
    if (ip.isEmpty) {
      _settle('Aucune adresse de caméra configurée.');
      return;
    }
    if (ip == _ref.read(espIpProvider).trim()) {
      _settle('Adresse identique à celle du contrôleur ($ip) : refusé.');
      return;
    }

    // `ping()` exige une identification positive de la caméra : un simple
    // « 200 OK » ne suffit pas, le contrôleur en renvoie un aussi.
    final found = await _ref.read(cameraRepositoryProvider).ping();
    if (_disposed) return;

    if (found) {
      // Trouvée : on arrête de sonder. Une perte ultérieure sera signalée par
      // le flux lui-même, inutile de doubler avec un sondage périodique.
      state = const CameraDetection(status: CameraStatus.found);
      return;
    }
    _settle('Aucune caméra ne répond à $ip.');
  }

  void _settle(String reason) {
    state = CameraDetection(status: CameraStatus.absent, reason: reason);
    _retry = Timer(_retryInterval, () => unawaited(probe()));
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }
}

final cameraDetectionProvider =
    StateNotifierProvider<CameraDetector, CameraDetection>(
        (ref) => CameraDetector(ref));

// ── Flux par captures successives ───────────────────────────────────────────

/// État du flux caméra.
///
/// [frame] conserve la **dernière image valide** même quand la capture en
/// cours échoue : sur un AP chargé les timeouts isolés sont normaux, et faire
/// clignoter le panneau vers un écran d'erreur à chaque raté le rendrait
/// inutilisable. On ne bascule en erreur qu'après plusieurs échecs de suite.
class CameraFeedState {
  const CameraFeedState({
    this.frame,
    this.loading = false,
    this.error,
    this.consecutiveFailures = 0,
  });

  final Uint8List? frame;
  final bool loading;
  final String? error;
  final int consecutiveFailures;

  /// Seuil à partir duquel on considère la caméra réellement perdue.
  static const kFailureThreshold = 3;

  bool get isLost => consecutiveFailures >= kFailureThreshold;
  bool get hasFrame => frame != null;

  CameraFeedState copyWith({
    Uint8List? frame,
    bool? loading,
    String? error,
    int? consecutiveFailures,
  }) =>
      CameraFeedState(
        frame: frame ?? this.frame,
        loading: loading ?? this.loading,
        error: error,
        consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      );
}

/// Boucle de capture **séquentielle** : la requête suivante n'est armée
/// qu'une fois la précédente terminée. Un simple `Timer.periodic` empilerait
/// les requêtes dès que la caméra ralentit — exactement le moment où il ne
/// faut pas ajouter de trafic sur l'AP de la machine.
class CameraFeedController extends StateNotifier<CameraFeedState> {
  CameraFeedController(this._ref) : super(const CameraFeedState());

  final Ref _ref;
  Timer? _next;
  bool _running = false;
  bool _disposed = false;

  /// Démarre la boucle. Idempotent : un second appel ne double pas le rythme.
  void start() {
    if (_running || _disposed) return;
    _running = true;
    _tick();
  }

  void stop() {
    _running = false;
    _next?.cancel();
    _next = null;
  }

  /// Cadence courante : lâche pendant l'usinage (la bande passante est à
  /// l'envoi du G-code), soutenue quand la machine est à l'arrêt.
  Duration get _interval => _ref.read(cameraLiveAllowedProvider)
      ? kCameraIdleGap
      : _ref.read(cameraSnapshotIntervalProvider);

  /// Dernier profil de compression réellement appliqué à la caméra.
  /// `null` tant qu'aucun n'a été posé — au démarrage on ne sait pas dans quel
  /// état le firmware se trouve.
  int? _appliedQuality;

  /// Aligne la compression de la caméra sur ce que fait la machine.
  ///
  /// Rejoué à chaque tick tant que le profil voulu n'est pas celui appliqué :
  /// si la requête échoue (AP saturé au démarrage d'une passe, précisément le
  /// moment où ça compte), le tick suivant réessaie tout seul.
  Future<void> _syncQuality(bool machining) async {
    final wanted = machining ? kCameraMachiningQuality : kCameraIdleQuality;
    if (_appliedQuality == wanted) return;

    final ok = await _ref.read(cameraRepositoryProvider).setQuality(wanted);
    if (_disposed) return;
    // Mémorisé UNIQUEMENT en cas de succès : sinon le tick suivant retenterait
    // sur une caméra restée en haute qualité pendant toute la passe.
    if (ok) _appliedQuality = wanted;
  }

  Future<void> _tick() async {
    if (!_running || _disposed) return;

    state = state.copyWith(loading: true, error: state.error);
    try {
      // `cameraLiveAllowedProvider` est vrai quand la machine NE coupe PAS.
      await _syncQuality(!_ref.read(cameraLiveAllowedProvider));
      if (!_running || _disposed) return;

      final bytes = await _ref.read(cameraRepositoryProvider).snapshot();
      if (_disposed) return;
      state = CameraFeedState(frame: bytes, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        consecutiveFailures: state.consecutiveFailures + 1,
      );
    }

    if (!_running || _disposed) return;
    _next = Timer(_interval, _tick);
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

final cameraFeedProvider =
    StateNotifierProvider.autoDispose<CameraFeedController, CameraFeedState>(
  (ref) => CameraFeedController(ref),
);

// ── Mode du panneau visualiseur ─────────────────────────────────────────────

/// Ce que montre le panneau du visualiseur. La caméra y **remplace** le
/// simulateur 3D : quand elle est configurée, c'est elle qu'on voit par
/// défaut, le rendu 3D restant accessible d'une touche.
enum VisualizerMode { camera, simulation3d }

final visualizerModeProvider =
    StateProvider<VisualizerMode>((ref) => VisualizerMode.camera);

/// Mode réellement affiché : sans caméra configurée, le panneau retombe sur
/// le simulateur 3D quel que soit le choix mémorisé.
final effectiveVisualizerModeProvider = Provider<VisualizerMode>((ref) {
  if (!ref.watch(cameraEnabledProvider)) return VisualizerMode.simulation3d;
  return ref.watch(visualizerModeProvider);
});
