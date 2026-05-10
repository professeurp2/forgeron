import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Conteneur réutilisable style "Glassmorphism Industriel".
/// Utilisé partout dans l'app pour les panneaux de données.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final Color backgroundColor;
  final String? title;
  final Widget? titleTrailing;
  final bool expand;

  const GlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 8.0,
    this.borderColor = AppColors.surfaceBorder,
    this.backgroundColor = AppColors.surface,
    this.title,
    this.titleTrailing,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (title != null) _buildTitle(),
        if (expand)
          Expanded(child: Padding(padding: padding, child: child))
        else
          Padding(padding: padding, child: child),
      ],
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: content,
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Text(
            title!.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (titleTrailing != null) titleTrailing!,
        ],
      ),
    );
  }
}
