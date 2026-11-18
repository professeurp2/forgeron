import 'package:flutter/material.dart';
import '../theme/forge_tokens.dart';
import '../theme/forgeron_colors.dart';

/// Panneau de données de l'application (nom historique : « verre »).
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
    this.borderRadius = FRadius.lg,
    this.borderColor,
    this.backgroundColor,
    this.title,
    this.titleTrailing,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.fc.surface;
    final border = borderColor ?? context.fc.surfaceBorder;
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

    // Design v2 : surface pleine, filet fin, ombre courte. La v1 posait un
    // flou d'arrière-plan (BackdropFilter) et une ombre de 16 px sur CHAQUE
    // panneau : coûteux sur un téléphone d'atelier, et moins net à lire.
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border),
        boxShadow: FShadow.card(context.fc),
      ),
      child: content,
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: borderColor ?? context.fc.surfaceBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title!.toUpperCase(),
              style: FText.overline(context.fc).copyWith(color: context.fc.textPrimary),
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