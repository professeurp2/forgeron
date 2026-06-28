import 'package:flutter/material.dart';

class AppConstants {
  // Machine Constraints
  static const int maxGCodeQueueSize = 127; // bytes for FluidNC
  static const Duration pingInterval = Duration(seconds: 2);
  static const Duration watchdogTimeout = Duration(seconds: 2);
  
  // UI Constants
  static const double panelPadding = 16.0;
  static const double borderRadius = 8.0;
  static const double compactBorderRadius = 4.0;
  static const double defaultIconSize = 16.0;

  // Connection
  static const String defaultWsUrl = 'ws://192.168.1.100:80'; // Replace with typical ESP32 IP
}
