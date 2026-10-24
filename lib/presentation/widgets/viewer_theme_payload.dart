import 'package:flutter/material.dart';
import '../../core/theme/forgeron_colors.dart';

/// Construit la palette envoyée à la page three.js du visualiseur 3D.
///
/// Le viewer ne recevait qu'un booléen `isDark`, dont il ne faisait qu'une
/// chose : remplacer la couleur de fond. Tout le reste restait figé dans le
/// HTML — arêtes noires, plateau anthracite, parcours rouge/vert, outil
/// orange — si bien qu'en thème clair la scène gardait son habillage sombre.
///
/// On envoie donc les couleurs de la palette active. Ce qui suit le thème :
/// le fond, le plateau, la pièce, les arêtes, l'outil, le parcours et
/// l'enveloppe de course. Ce qui ne le suit PAS : les matériaux qui
/// représentent de la matière réelle (extrusions aluminium, acier, moteurs) —
/// une machine reste métallique dans les deux thèmes, c'est son habillage qui
/// change.
Map<String, dynamic> viewerThemePayload(ForgeronColorPalette fc, bool isDark) {
  String h(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  return {
    'isDark': isDark,
    'background': h(fc.background),
    'surface': h(fc.surface),
    'surfaceBright': h(fc.surfaceBright),
    'surfaceBorder': h(fc.surfaceBorder),
    // Les arêtes doivent contraster avec les pièces, pas avec le fond : noires
    // en thème clair, claires en thème sombre. Figées en noir, elles
    // disparaissaient dans le sombre et salissaient le clair.
    'edge': h(isDark ? fc.textPrimary : const Color(0xFF000000)),
    'primary': h(fc.primary),
    'success': h(fc.success),
    'error': h(fc.error),
    'info': h(fc.info),
    'textSecondary': h(fc.textSecondary),
    'axisX': h(fc.axisX),
    'axisY': h(fc.axisY),
    'axisZ': h(fc.axisZ),
  };
}
