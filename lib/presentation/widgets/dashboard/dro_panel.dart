import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../application/providers/machine_provider.dart';
import '../../tutorial/tutorial_keys.dart';

class DROPanel extends ConsumerWidget {
  const DROPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final wPos = state?.wPos ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    
    return Column(
      key: TutorialKeys.droPanel,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LECTURE DIGITALE (DRO)', 
          style: TextStyle(
            color: AppColors.textDisabled, 
            fontSize: 10, 
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 12),
        for (int i = 0; i < 3; i++) 
          _DROCoordCard(
            axis: ['X', 'Y', 'Z'][i], 
            value: wPos[i], 
            color: [AppColors.axisX, AppColors.axisY, AppColors.axisZ][i],
          ),
        Row(
          children: [
            Expanded(
              child: _DROCoordCard(
                axis: 'A', 
                value: wPos[3], 
                color: AppColors.axisA, 
                small: true,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _DROCoordCard(
                axis: 'C', 
                value: wPos[4], 
                color: AppColors.axisC, 
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DROCoordCard extends StatefulWidget {
  final String axis;
  final double value;
  final Color color;
  final bool small;

  const _DROCoordCard({
    required this.axis,
    required this.value,
    required this.color,
    this.small = false,
  });

  @override
  State<_DROCoordCard> createState() => _DROCoordCardState();
}

class _DROCoordCardState extends State<_DROCoordCard> {
  double? _oldValue;
  String _direction = 'idle'; // 'up', 'down', 'idle'
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _DROCoordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_oldValue != null && widget.value != oldWidget.value) {
      final diff = widget.value - _oldValue!;
      // Ignorer les micro-bruits de capteurs inférieurs à 0.0005 mm/deg
      if (diff.abs() > 0.0005) {
        setState(() {
          _direction = diff > 0 ? 'up' : 'down';
        });
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _direction = 'idle';
            });
          }
        });
      }
    }
    _oldValue = widget.value;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.small
        ? '${widget.value.toStringAsFixed(2)}°'
        : widget.value.toStringAsFixed(3);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
        horizontal: widget.small ? 10 : 14, 
        vertical: widget.small ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: widget.color, width: 4.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Axe (ex: X, Y, Z, A, C)
          Text(
            widget.axis, 
            style: TextStyle(
              color: widget.color, 
              fontSize: widget.small ? 14 : 18, 
              fontWeight: FontWeight.w900,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          SizedBox(width: 8),
          
          // Indicateur de mouvement réactif ▲/▼
          _buildDirectionIndicator(),
          
          const Spacer(),
          
          // Coordonnée avec effet de luminescence (glow)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                displayValue,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: widget.small ? 18 : 25,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                  shadows: [
                    Shadow(
                      color: widget.color.withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionIndicator() {
    IconData icon;
    Color color;
    double opacity;

    if (_direction == 'up') {
      icon = Icons.arrow_drop_up_rounded;
      color = AppColors.success;
      opacity = 1.0;
    } else if (_direction == 'down') {
      icon = Icons.arrow_drop_down_rounded;
      color = AppColors.danger;
      opacity = 1.0;
    } else {
      icon = Icons.remove_rounded;
      color = AppColors.textDisabled;
      opacity = 0.35;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: opacity,
      child: Icon(
        icon,
        color: color,
        size: widget.small ? 16 : 22,
        shadows: _direction != 'idle'
            ? [
                Shadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
    );
  }
}
