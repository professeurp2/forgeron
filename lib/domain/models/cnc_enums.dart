enum CncAxis {
  X,
  Y,
  Z,
  A,
  C
}

enum AlarmSeverity {
  info,
  warning,
  critical,
  fatal
}

extension AlarmSeverityExtension on AlarmSeverity {
  String get name {
    switch (this) {
      case AlarmSeverity.info:
        return 'Info';
      case AlarmSeverity.warning:
        return 'Warning';
      case AlarmSeverity.critical:
        return 'Critical';
      case AlarmSeverity.fatal:
        return 'Fatal';
    }
  }
}

/// Limites mécaniques par axe — issues du dimensionnement PFE §3.3-3.4.
extension CncAxisLimits on CncAxis {
  /// Course maximale (mm pour linéaire, ° pour rotatif).
  double get maxTravel => switch (this) {
        CncAxis.X => 200.0, // Lx = 200 mm (vis T8)
        CncAxis.Y => 300.0, // Ly = 300 mm
        CncAxis.Z => 150.0, // Lz = 150 mm
        CncAxis.A => 90.0, // ±90° (berceau)
        CncAxis.C => 360.0, // 360° continu (plateau)
      };

  /// `true` pour les axes rotatifs du Trunnion (A, C).
  bool get isRotary => this == CncAxis.A || this == CncAxis.C;
}

