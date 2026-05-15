import 'package:flutter/material.dart';

class TutorialKeys {
  // Phase 1 : Header
  static final headerBar = GlobalKey(debugLabel: 'tutorial_header');
  static final emergencyStopBtn = GlobalKey(debugLabel: 'tutorial_estop');
  static final settingsBtn = GlobalKey(debugLabel: 'tutorial_settings');
  
  // Phase 2 : Sidebar & Footer
  static final sidebar = GlobalKey(debugLabel: 'tutorial_sidebar');
  static final menuToggleBtn = GlobalKey(debugLabel: 'tutorial_menu');
  static final statusFooter = GlobalKey(debugLabel: 'tutorial_footer');
  
  // Phase 3 : Dashboard
  static final droPanel = GlobalKey(debugLabel: 'tutorial_dro');
  static final actionButtons = GlobalKey(debugLabel: 'tutorial_actions');
  static final overridesPanel = GlobalKey(debugLabel: 'tutorial_overrides');
  static final macrosPanel = GlobalKey(debugLabel: 'tutorial_macros');
  static final trunnionViz = GlobalKey(debugLabel: 'tutorial_3d');
  static final gcodeConsole = GlobalKey(debugLabel: 'tutorial_gcode');
  static final statusCockpit = GlobalKey(debugLabel: 'tutorial_cockpit');
  
  // Phase 4 : Palpage
  static final wcsCards = GlobalKey(debugLabel: 'tutorial_wcs');
  static final jogPanel = GlobalKey(debugLabel: 'tutorial_jog');
  static final probingTools = GlobalKey(debugLabel: 'tutorial_probing_tools');
  static final probingOffsets = GlobalKey(debugLabel: 'tutorial_probing_offsets');
  
  // Phase 5 : Outils
  static final toolTable = GlobalKey(debugLabel: 'tutorial_tool_table');
  static final calibrationWizard = GlobalKey(debugLabel: 'tutorial_calibration');
  
  // Phase 6 : Fichiers
  static final fileManager = GlobalKey(debugLabel: 'tutorial_file_manager');
  static final gcodePreview = GlobalKey(debugLabel: 'tutorial_gcode_preview');
  static final streamBtn = GlobalKey(debugLabel: 'tutorial_stream_btn');
  
  // Phase 7 : MDI
  static final mdiInput = GlobalKey(debugLabel: 'tutorial_mdi');
  static final mdiHistory = GlobalKey(debugLabel: 'tutorial_mdi_history');
  
  // Phase 8 : Diagnostics
  static final networkMonitor = GlobalKey(debugLabel: 'tutorial_network_monitor');
  static final performanceMetrics = GlobalKey(debugLabel: 'tutorial_perf_metrics');
  
  // Phase 9 : Connexion
  static final networkConfig = GlobalKey(debugLabel: 'tutorial_network_config');
  static final scannerBtn = GlobalKey(debugLabel: 'tutorial_scanner_btn');
}
