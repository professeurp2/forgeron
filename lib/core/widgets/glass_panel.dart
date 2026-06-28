import 'dart:ui';
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

  GlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12.0, // Un peu plus arrondi pour un look moderne
    Color? borderColor,
    Color? backgroundColor,
    this.title,
    this.titleTrailing,
    this.expand = false,
  }) : borderColor = borderColor ?? AppColors.surfaceBorder,
       backgroundColor = backgroundColor ?? AppColors.surface;

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
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Ombre portée sombre et diffuse
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          // Halo subtil de couleur primaire
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              // Gradient de fond translucide (effet verre)
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor.withValues(alpha: 0.45),
                  backgroundColor.withValues(alpha: 0.8),
                ],
              ),
              // Bordure biseautée ultra-fine
              border: Border.all(
                color: borderColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (titleTrailing != null) ...[
            SizedBox(width: 8),
            titleTrailing!,
          ],
        ],
      ),
    );
  }
}