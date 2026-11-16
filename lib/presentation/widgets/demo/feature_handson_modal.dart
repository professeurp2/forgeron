import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../application/providers/controller_memory_provider.dart';
import '../../../application/providers/di_providers.dart';
import '../../../application/services/demo_benchmark_runner.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../domain/models/demo_benchmark_catalog.dart';
import '../../../domain/models/esp32_reboot_event.dart';

/// Modale et panneau interactif de « Prise en main Multimédia (Images + Vidéos) »
/// et Banc d'Essai 1-Clic (STEP Manufacturing & Médecine + Simulation ESP32).
class FeatureHandsOnModal extends ConsumerStatefulWidget {
  final int initialGuideIndex;
  final void Function(int screenIndex)? onNavigateToScreen;

  const FeatureHandsOnModal({
    super.key,
    this.initialGuideIndex = 0,
    this.onNavigateToScreen,
  });

  static Future<void> show(
    BuildContext context, {
    int initialGuideIndex = 0,
    void Function(int screenIndex)? onNavigateToScreen,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
          child: FeatureHandsOnModal(
            initialGuideIndex: initialGuideIndex,
            onNavigateToScreen: onNavigateToScreen,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FeatureHandsOnModal> createState() =>
      _FeatureHandsOnModalState();
}

class _FeatureHandsOnModalState extends ConsumerState<FeatureHandsOnModal>
    with SingleTickerProviderStateMixin {
  late int _selectedGuideIdx;
  late AnimationController _videoCtrl;
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = true;
  bool _isRunningBenchmark = false;
  String? _statusFeedback;

  @override
  void initState() {
    super.initState();
    _selectedGuideIdx = widget.initialGuideIndex.clamp(
      0,
      DemoBenchmarkCatalog.handsOnGuides.length - 1,
    );
    _videoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
    super.dispose();
  }

  FeatureHandsOnGuide get _activeGuide =>
      DemoBenchmarkCatalog.handsOnGuides[_selectedGuideIdx];

  Future<void> _launchSample(DemoBenchmarkSample sample) async {
    setState(() {
      _isRunningBenchmark = true;
      _statusFeedback =
          'Chargement de ${sample.title} (${sample.cadPath}) en cours…';
    });
    await DemoBenchmarkRunner.runSample(ref, sample);
    if (!mounted) return;
    setState(() {
      _isRunningBenchmark = false;
      _statusFeedback =
          '✅ ${sample.title} chargé ! Le parcours 5 axes et l\'analyse de l\'Agent sont prêts.';
    });
  }

  void _simulateEsp32Brownout() {
    final current = ref.read(machineRepositoryProvider).currentState;
    final event = Esp32RebootEvent(
      timestamp: DateTime.now(),
      reason: Esp32RebootReason.brownoutSpindleSurge,
      rawSignature:
          'rst:0xf (BROWNOUT_RESET) / Brownout detector was triggered after M3 (GPIO 21)',
      previousStatus: current.status,
      previousMPos: const [42.5, -18.0, -12.4, 15.0, 90.0],
      wasSpindleRecentlyStarted: true,
      continuousRunMinutes: 4,
      activeGcodeLine: 128,
    );
    ref.read(controllerMemoryProvider.notifier).recordEsp32Reboot(event);
    setState(() {
      _statusFeedback =
          '⚡ Redémarrage ESP32 (Brownout M3 GPIO 21) simulé ! Regardez le diagnostic temps réel dans le Chatbot.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final guides = DemoBenchmarkCatalog.handsOnGuides;
    final manufSamples =
        DemoBenchmarkCatalog.byDomain(DemoDomain.manufacturing);
    final medSamples = DemoBenchmarkCatalog.byDomain(DemoDomain.medicine);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.ondemand_video_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('CENTRE DE DÉMONSTRATION & PRISES EN MAIN MULTIMÉDIA'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        tr('Capsules visuelles interactives (Image + Vidéo), Essais STEP (Manufacturing & Médecine) & Simulation Temps Réel ESP32'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('Lire la présentation vocale IA'),
                  onPressed: () {
                    _tts.speak(_activeGuide.agentIntroduction);
                  },
                  icon: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF06B6D4)),
                ),
                IconButton(
                  tooltip: tr('Fermer'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // ── Corps principal ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur d'étapes de prise en main
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: guides.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final g = guides[index];
                        final selected = index == _selectedGuideIdx;
                        return ChoiceChip(
                          selected: selected,
                          selectedColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.22),
                          backgroundColor: const Color(0xFF1E293B),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF334155),
                          ),
                          label: Text(
                            g.title,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedGuideIdx = index),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Carte Multimédia : Capsule Vidéo Animée + Explication de l'Agent
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 720;
                      final videoPlayer = _buildAnimatedVideoPlayer(_activeGuide);
                      final guideDetails = _buildGuideDetailsCard(_activeGuide);
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: videoPlayer),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: guideDetails),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          videoPlayer,
                          const SizedBox(height: 14),
                          guideDetails,
                        ],
                      );
                    },
                  ),

                  if (_statusFeedback != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          if (_isRunningBenchmark)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF10B981),
                              ),
                            )
                          else
                            const Icon(Icons.check_circle_outline,
                                color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusFeedback!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Banc d'essai 1-clic : Fichiers STEP embarqués ───────
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_rounded,
                          color: Color(0xFF06B6D4), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        tr('TESTS EN 1 CLIC — FICHIERS STEP & CAO EMBARQUÉS DANS FORGERON'),
                        style: const TextStyle(
                          color: Color(0xFF06B6D4),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 720;
                      final manufCol = _buildDomainBenchmarkColumn(
                        title: '🏭 FILIÈRE MANUFACTURING (INDUSTRIE & ÉNERGIE)',
                        accent: const Color(0xFFF59E0B),
                        samples: manufSamples,
                      );
                      final medCol = _buildDomainBenchmarkColumn(
                        title: '🏥 FILIÈRE MÉDECINE (IMPLANTS & CFAO DENTAIRE)',
                        accent: const Color(0xFF10B981),
                        samples: medSamples,
                      );
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: manufCol),
                            const SizedBox(width: 14),
                            Expanded(child: medCol),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          manufCol,
                          const SizedBox(height: 12),
                          medCol,
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Banc de test résilience : Simulation Alarme / Reboot ESP32 ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'TEST SUPERVISION TEMPS RÉEL ESP32 :',
                              style: TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFFFCA5A5),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          onPressed: _simulateEsp32Brownout,
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text(
                            'Simuler Reboot ESP32 (Brownout Broche M3)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedVideoPlayer(FeatureHandsOnGuide guide) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF06090F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animation Temps Réel "Capsule Vidéo de Prise en Main"
          AnimatedBuilder(
            animation: _videoCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _HandsOnVideoSimulationPainter(
                  simulationType: guide.videoSimulationType,
                  progress: _videoCtrl.value,
                ),
              );
            },
          ),

          // Vignette Image de référence (en haut à droite)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    guide.imageAssetPath,
                    width: 22,
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.precision_manufacturing,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CAPSULE VIDÉO • ${guide.badge}',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barre de contrôle vidéo en bas
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        if (_isPlaying) {
                          _videoCtrl.repeat();
                        } else {
                          _videoCtrl.stop();
                        }
                      });
                    },
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _videoCtrl,
                      builder: (context, _) => SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: _videoCtrl.value,
                          activeColor: const Color(0xFFF59E0B),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: (v) {
                            _videoCtrl.value = v;
                          },
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '60 FPS • PRISE EN MAIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideDetailsCard(FeatureHandsOnGuide guide) {
    final linkedSample =
        DemoBenchmarkCatalog.sampleById(guide.linkedDemoSampleId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  guide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F17),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
            ),
            child: Text(
              '« ${guide.agentIntroduction} »',
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...guide.steps.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (linkedSample != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _isRunningBenchmark
                      ? null
                      : () => _launchSample(linkedSample),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(
                    'Tester avec ${linkedSample.title.split(" ").first}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              if (widget.onNavigateToScreen != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF06B6D4),
                    side: const BorderSide(color: Color(0xFF06B6D4)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onNavigateToScreen!(guide.targetScreenIndex);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text(
                    'Ouvrir la fenêtre métier',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDomainBenchmarkColumn({
    required String title,
    required Color accent,
    required List<DemoBenchmarkSample> samples,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          ...samples.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F17),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.subtitle} • ${s.cadPath}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.2),
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed:
                        _isRunningBenchmark ? null : () => _launchSample(s),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                    label: const Text(
                      'Charger & Tester',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre procédural 60 FPS générant la capsule vidéo interactive de prise en main
/// pour chaque fonctionnalité clé de Forgeron.
class _HandsOnVideoSimulationPainter extends CustomPainter {
  final String simulationType;
  final double progress;

  _HandsOnVideoSimulationPainter({
    required this.simulationType,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF070B12);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grille industrielle de fond
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final center = Offset(size.width * 0.5, size.height * 0.48);
    final angle = progress * 2 * math.pi;

    switch (simulationType) {
      case 'trunnion_5axis':
        _drawTrunnion5AxisSim(canvas, size, center, angle);
      case 'step_to_cam':
        _drawStepToCamSim(canvas, size, center, angle);
      case 'probing_cycle':
        _drawProbingSim(canvas, size, center, angle);
      case 'esp32_watchdog':
        _drawEsp32WatchdogSim(canvas, size, center, angle);
      default:
        _drawAiMemorySim(canvas, size, center, angle);
    }
  }

  void _drawTrunnion5AxisSim(
      Canvas canvas, Size size, Offset center, double angle) {
    final tiltA = math.sin(angle) * 28; // degrés simulés
    final rotC = (progress * 360).toInt();

    // Berceau A (arc ambre)
    final cradlePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 68),
      0.2 + math.sin(angle) * 0.25,
      math.pi - 0.4,
      false,
      cradlePaint,
    );

    // Plateau rotatif C
    final tablePaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 12),
        width: 96,
        height: 32 + math.sin(angle) * 10,
      ),
      tablePaint,
    );

    // Outil / Broche animé
    final toolX = center.dx + math.cos(angle * 2) * 32;
    final toolY = center.dy - 48 + math.sin(angle * 2) * 12;
    final spindlePaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(toolX, toolY - 22), width: 16, height: 34),
      spindlePaint,
    );
    canvas.drawLine(
      Offset(toolX, toolY - 5),
      Offset(toolX, toolY + 18),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );

    _drawCaption(
      canvas,
      Offset(16, 16),
      'JUMEAU 5-AXES TRUNNION • A=${tiltA.toStringAsFixed(1)}° | C=$rotC°',
      const Color(0xFF10B981),
    );
  }

  void _drawStepToCamSim(
      Canvas canvas, Size size, Offset center, double angle) {
    // Maillage CAO STEP à gauche → Parcours G-code 5 axes à droite
    final leftCenter = Offset(size.width * 0.3, center.dy);
    final rightCenter = Offset(size.width * 0.72, center.dy);

    final cadPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      canvas.drawLine(
        leftCenter,
        leftCenter + Offset(math.cos(a) * 44, math.sin(a) * 44),
        cadPaint,
      );
    }
    canvas.drawCircle(leftCenter, 44, cadPaint);

    // Flèche de pipeline OCCT
    final arrowX = size.width * 0.44 + (progress * 28);
    canvas.drawLine(
      Offset(size.width * 0.42, center.dy),
      Offset(size.width * 0.56, center.dy),
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
        Offset(arrowX.clamp(size.width * 0.42, size.width * 0.56), center.dy),
        5,
        Paint()..color = const Color(0xFFF59E0B));

    // Spirale G-Code 5 axes
    final path = Path();
    for (var t = 0.0; t < progress * 4 * math.pi; t += 0.15) {
      final r = 8 + t * 3.2;
      final pt = rightCenter + Offset(math.cos(t) * r, math.sin(t) * r * 0.7);
      if (t == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    _drawCaption(
      canvas,
      Offset(16, 16),
      'PIPELINE STEP → G-CODE (IMPELLER.STP & IMPLANT CRÂNIEN)',
      const Color(0xFF06B6D4),
    );
  }

  void _drawProbingSim(Canvas canvas, Size size, Offset center, double angle) {
    final probeZ = (math.sin(angle)).abs() * 38;
    final touching = probeZ < 5.0;

    // Pièce sur la table
    canvas.drawRect(
      Rect.fromCenter(
          center: center.translate(0, 38), width: 130, height: 32),
      Paint()..color = const Color(0xFF334155),
    );

    // Sonde G38.2
    final tipY = center.dy + 22 - probeZ;
    canvas.drawLine(
      Offset(center.dx, tipY - 50),
      Offset(center.dx, tipY),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      Offset(center.dx, tipY),
      6,
      Paint()
        ..color =
            touching ? const Color(0xFFEF4444) : const Color(0xFF10B981),
    );

    if (touching) {
      canvas.drawCircle(
        Offset(center.dx, tipY),
        18,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    _drawCaption(
      canvas,
      Offset(16, 16),
      touching
          ? 'CONTACT SONDE DÉTECTÉ [PRB:Z-10.000:1] → G10 L2 P1'
          : 'APPROCHE PALPAGE G38.2 Z-25 F100 (Pn:P)',
      touching ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
    );
  }

  void _drawEsp32WatchdogSim(
      Canvas canvas, Size size, Offset center, double angle) {
    // Onde de tension 12V/5V avec creux Brownout M3 puis interprétation IA
    final path = Path();
    for (double x = 24; x < size.width - 24; x += 4) {
      final norm = (x - 24) / (size.width - 48);
      final isDip = (norm - progress).abs() < 0.08;
      final y = center.dy + (isDip ? 42.0 : math.sin(norm * 20 + angle) * 5);
      if (x == 24) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    _drawCaption(
      canvas,
      Offset(16, 16),
      'SURVEILLANCE TEMPS RÉEL : ALARM:1..18 & BROWNOUT ESP32 (GPIO 21)',
      const Color(0xFFEF4444),
    );
  }

  void _drawAiMemorySim(Canvas canvas, Size size, Offset center, double angle) {
    final nodes = <Offset>[
      center + Offset(-90, -35),
      center + Offset(90, -35),
      center + Offset(-90, 40),
      center + Offset(90, 40),
    ];
    for (final n in nodes) {
      canvas.drawLine(
        center,
        n,
        Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.6)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(n, 14, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(
        n,
        14,
        Paint()
          ..color = const Color(0xFF06B6D4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      center,
      26 + math.sin(angle * 2) * 3,
      Paint()..color = const Color(0xFFF59E0B),
    );
    _drawCaption(
      canvas,
      Offset(16, 16),
      'MÉMOIRE DU CONTRÔLEUR • CHATBOT FLOTTANT / BAS / DROITE',
      const Color(0xFFF59E0B),
    );
  }

  void _drawCaption(Canvas canvas, Offset offset, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HandsOnVideoSimulationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.simulationType != simulationType;
}
