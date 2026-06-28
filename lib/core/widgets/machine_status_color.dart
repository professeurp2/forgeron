import 'package:flutter/material.dart';
import '../../domain/models/machine_state.dart';
import '../theme/app_colors.dart';

Color getMachineStatusColor(MachineStatus s) {
  switch (s) {
    case MachineStatus.idle:
      return AppColors.success;
    case MachineStatus.run:
      return AppColors.primary;
    case MachineStatus.hold:
      return AppColors.warning;
    case MachineStatus.alarm:
      return AppColors.error;
    case MachineStatus.home:
      return AppColors.axisZ;
    case MachineStatus.check:
      return Colors.cyan;
    case MachineStatus.door:
      return Colors.orange;
    case MachineStatus.sleep:
      return Colors.indigo;
    default:
      return AppColors.textDisabled;
  }
}
