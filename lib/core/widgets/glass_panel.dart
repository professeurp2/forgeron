import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/forgeron_colors.dart';

/// Conteneur réutilisable style "Machined Anodized Glass" — Forge Titanium & Magma v3.
/// Utilisé partout dans l'app pour les panneaux de données.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  // Nullables : résolus depuis le thème (context.fc) quand non fournis, pour
  // que le panneau suive le mode clair/sombre au lieu d'être toujours noir.
  final Color? borderColor;
  final Color? backgroundColor;
  final String? title;
  final Widget? titleTrailing;
  final bool expand;

  const GlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12.0,
    this.borderColor,
    this.backgroundColor,
    this.title,
    this.titleTrailing,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final bg = backgroundColor ?? fc.surface;
    final border = borderColor ?? fc.surfaceBorder;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (title != null) _buildTitle(context),
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
            color: Colors.black.withValues(alpha: fc.isDark ? 0.38 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          // Halo subtil de couleur primaire
          BoxShadow(
            color: fc.primary.withValues(alpha: 0.04),
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
              // Gradient anodisé translucide
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (backgroundColor == null ? fc.surfaceBright : bg)
                      .withValues(alpha: fc.isDark ? 0.68 : 0.90),
                  bg.withValues(alpha: fc.isDark ? 0.88 : 0.96),
                ],
              ),
              // Bordure biseautée ultra-fine
              border: Border.all(
                color: border.withValues(alpha: 0.72),
                width: 1.2,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: BorderSide(
                  color: fc.rimHighlight,
                  width: 1.0,
                ),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: borderColor ?? fc.surfaceBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: fc.primary,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: fc.primary.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Rajdhani',
                color: fc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (titleTrailing != null) ...[
            const SizedBox(width: 8),
            titleTrailing!,
          ],
        ],
      ),
    );
  }
}