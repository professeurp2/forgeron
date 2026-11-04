import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/reco3d_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Reco3dClient', () {
    test('checkHealth retourne les informations du GPU et des moteurs', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          jsonEncode({
            'status': 'ready',
            'gpu_name': 'NVIDIA GeForce RTX 3070',
            'gpu_vram_total_mb': 8192,
            'gpu_vram_free_mb': 6500,
            'active_job_id': null,
            'queue_length': 0,
            'engines': {'photo': 'moteurs présents', 'gen': 'moteurs présents'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = Reco3dClient(httpClient: mockClient);
      final health = await client.checkHealth(Uri.parse('http://192.168.1.50:8765'));

      expect(health.status, 'ready');
      expect(health.gpuName, 'NVIDIA GeForce RTX 3070');
      expect(health.gpuVramTotalMb, 8192);
      expect(health.queueLength, 0);
      expect(health.engines['photo'], 'moteurs présents');
    });

    test('getJobStatus parse la progression et la provenance', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/jobs/job_123');
        return http.Response(
          jsonEncode({
            'job_id': 'job_123',
            'mode': 'photo',
            'stage': 'done',
            'progress_percent': 100.0,
            'message': 'Reconstruction terminée.',
            'error': null,
            'provenance': {
              'mode': 'photo',
              'engine': 'AliceVision',
              'engine_version': '2026.1',
              'has_scale_reference': true,
              'scale_type': 'aruco',
              'scale_factor': 50.0,
              'photo_count': 24,
              'is_approximate': false,
              'unreconstructed_holes_count': 0,
              'facets_count': 12000,
              'created_at': '2026-10-24T19:00:00Z',
              'notes': ['Mire certifiée'],
            },
            'has_step': true,
            'has_mesh': true,
          }),
          200,
        );
      });

      final client = Reco3dClient(httpClient: mockClient);
      final status = await client.getJobStatus(Uri.parse('http://localhost:8765'), 'job_123');

      expect(status.jobId, 'job_123');
      expect(status.stage, 'done');
      expect(status.hasStep, isTrue);
      expect(status.hasMesh, isTrue);
      expect(status.provenance, isNotNull);
      expect(status.provenance!.isApproximate, isFalse);
      expect(status.provenance!.scaleFactor, 50.0);
    });

    test('pollUntilDone appelle onProgress et termine à l\'état done', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        final stage = callCount == 1 ? 'sfm' : (callCount == 2 ? 'meshing' : 'done');
        final pct = callCount == 1 ? 25.0 : (callCount == 2 ? 75.0 : 100.0);
        return http.Response(
          jsonEncode({
            'job_id': 'job_abc',
            'mode': 'photo',
            'stage': stage,
            'progress_percent': pct,
            'message': stage,
            'has_step': stage == 'done',
            'has_mesh': stage == 'done',
          }),
          200,
        );
      });

      final client = Reco3dClient(httpClient: mockClient);
      final progressList = <double>[];

      final finalStatus = await client.pollUntilDone(
        Uri.parse('http://localhost:8765'),
        'job_abc',
        pollInterval: const Duration(milliseconds: 10),
        onProgress: (st) => progressList.add(st.progressPercent),
      );

      expect(finalStatus.stage, 'done');
      expect(progressList, [25.0, 75.0, 100.0]);
      expect(callCount, 3);
    });

    test('pollUntilDone lève Reco3dClientException si le job passe à failed', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'job_id': 'job_err',
            'mode': 'photo',
            'stage': 'failed',
            'progress_percent': 10.0,
            'message': 'Échec',
            'error': 'moteur(s) absent(s) sur ce poste : meshroom_batch',
            'has_step': false,
            'has_mesh': false,
          }),
          200,
        );
      });

      final client = Reco3dClient(httpClient: mockClient);

      expect(
        () => client.pollUntilDone(
          Uri.parse('http://localhost:8765'),
          'job_err',
          pollInterval: const Duration(milliseconds: 10),
        ),
        throwsA(isA<Reco3dClientException>().having(
          (e) => e.message,
          'message',
          contains('meshroom_batch'),
        )),
      );
    });
  });
}
