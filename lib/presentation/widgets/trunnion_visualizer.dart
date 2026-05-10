import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

/// Nouveau Visualiseur 3D accéléré par GPU pour configuration Trunnion (A/C).
/// Utilise flutter_cube pour la scène et une gestion de mesh optimisée pour le toolpath.
class TrunnionVisualizer extends ConsumerStatefulWidget {
  final List<double> mPos;
  final List<double>? targetPos;
  final List<List<double>>? toolpath;

  const TrunnionVisualizer({
    super.key,
    required this.mPos,
    this.targetPos,
    this.toolpath,
  });

  @override
  ConsumerState<TrunnionVisualizer> createState() => _TrunnionVisualizerState();
}

class _TrunnionVisualizerState extends ConsumerState<TrunnionVisualizer> {
  late Scene _scene;
  Object? _machineBase;
  Object? _axisA;
  Object? _axisC;
  Object? _spindle;
  Object? _toolpathObject;

  @override
  void initState() {
    super.initState();
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    _scene.light.position.setFrom(Vector3(0, 100, 100));
    _scene.camera.position.setFrom(Vector3(0, 50, 250));
    _scene.camera.target.setFrom(Vector3(0, 0, 0));

    _initMachineObjects();
    _updateKinematics();
  }

  void _initMachineObjects() {
    // 1. Base Machine
    _machineBase = Object(
      name: 'base',
      mesh: _createBoxMesh(Vector3(120, 10, 120)),
      position: Vector3(0, -60, 0),
    );

    // 2. Axe A (Berceau)
    _axisA = Object(
      name: 'axisA',
      mesh: _createCradleMesh(),
      position: Vector3(0, 0, 0),
    );

    // 3. Axe C (Plateau tournant sur A)
    _axisC = Object(
      name: 'axisC',
      mesh: _createTableMesh(),
      position: Vector3(0, 0, 0),
    );

    // 4. Broche / Spindle
    _spindle = Object(
      name: 'spindle',
      mesh: _createBoxMesh(Vector3(30, 60, 30)),
      position: Vector3(0, 0, 0),
    );

    _axisA!.add(_axisC!);
    _scene.world.add(_machineBase!);
    _scene.world.add(_axisA!);
    _scene.world.add(_spindle!);
  }

  void _updateKinematics() {
    if (_axisA == null || _axisC == null || _spindle == null) return;

    // Rotation A (en degrés)
    _axisA!.rotation.x = widget.mPos[3];
    
    // Rotation C
    _axisC!.rotation.z = widget.mPos[4];

    // Position Linéaire (X, Y, Z)
    _spindle!.position.setFrom(Vector3(widget.mPos[0], widget.mPos[2], -widget.mPos[1]));

    // Mise à jour du Toolpath
    if (widget.toolpath != null) {
      _updateToolpathMesh();
    }

    _scene.update();
  }

  void _updateToolpathMesh() {
    if (widget.toolpath == null || widget.toolpath!.isEmpty) return;

    final List<Vector3> vertices = [];
    final List<Polygon> polygons = [];
    
    for (int i = 0; i < widget.toolpath!.length; i++) {
      final p = widget.toolpath![i];
      vertices.add(Vector3(p[0], p[2], -p[1]));
      if (i > 0) {
        // flutter_cube dessine des polygones. Pour un toolpath (lignes), on triche avec des triangles fins.
        polygons.add(Polygon(i - 1, i, i));
      }
    }

    if (_toolpathObject != null) {
      _scene.world.remove(_toolpathObject!);
    }

    _toolpathObject = Object(
      mesh: Mesh(vertices: vertices, indices: polygons),
    );
    _scene.world.add(_toolpathObject!);
  }

  Mesh _createBoxMesh(Vector3 size) {
    final x = size.x / 2;
    final y = size.y / 2;
    final z = size.z / 2;

    final List<Vector3> vertices = [
      Vector3(-x, -y, z),  Vector3(x, -y, z),  Vector3(x, y, z),  Vector3(-x, y, z),
      Vector3(-x, -y, -z), Vector3(x, -y, -z), Vector3(x, y, -z), Vector3(-x, y, -z),
    ];

    final List<Polygon> indices = [
      Polygon(0, 1, 2), Polygon(0, 2, 3),
      Polygon(1, 5, 6), Polygon(1, 6, 2),
      Polygon(5, 4, 7), Polygon(5, 7, 6),
      Polygon(4, 0, 3), Polygon(4, 3, 7),
      Polygon(3, 2, 6), Polygon(3, 6, 7),
      Polygon(4, 5, 1), Polygon(4, 1, 0),
    ];

    return Mesh(vertices: vertices, indices: indices);
  }

  Mesh _createCradleMesh() {
    return _createBoxMesh(Vector3(180, 20, 60));
  }

  Mesh _createTableMesh() {
    // Simplifié : un plateau rectangulaire pour le moment
    return _createBoxMesh(Vector3(120, 120, 10));
  }

  @override
  void didUpdateWidget(TrunnionVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateKinematics();
  }

  @override
  Widget build(BuildContext context) {
    return Cube(
      onSceneCreated: _onSceneCreated,
    );
  }
}
