import 'dart:typed_data';
import '../../domain/repositories/camera_repository.dart';

/// Levée par [MockCameraRepository] : il n'y a pas d'image à simuler, et
/// fabriquer une fausse vue d'atelier serait trompeur. L'UI intercepte ce
/// type pour afficher un cartouche « mode simulation » explicite.
class CameraUnavailableInSimulation implements Exception {
  const CameraUnavailableInSimulation();

  @override
  String toString() => 'Caméra indisponible en mode simulation';
}

/// Caméra factice pour le mode simulation. Elle se déclare hors ligne plutôt
/// que d'inventer une image : sur un poste d'usinage, une vue truquée est pire
/// que pas de vue du tout.
class MockCameraRepository implements CameraRepository {
  @override
  Future<Uint8List> snapshot() async =>
      throw const CameraUnavailableInSimulation();

  @override
  String get streamUrl => '';

  @override
  Future<bool> ping() async => false;

  @override
  Future<void> setResolution(CameraResolution resolution) async {}

  @override
  Future<bool> setQuality(int quality) async => false;

  @override
  Future<void> setFlash(bool on) async {}

  @override
  void dispose() {}
}
