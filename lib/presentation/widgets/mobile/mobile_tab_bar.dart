import 'package:flutter/material.dart';
import '../../../core/theme/forgeron_colors.dart';

/// Barre d'onglets compacte pour les sous-écrans mobiles.
///
/// Un `Tab(icon: …, text: …)` Material fait **72 px** de haut : sur un écran de
/// 800 dp déjà amputé de l'AppBar, de la nav basse et du contenu, ça se voit —
/// c'est ce qui donnait aux sous-menus leur allure « desktop ».
/// Ici : icône + label empilés dans **48 px**.
class MobileTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<MobileTab> tabs;

  const MobileTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      color: fc.surface,
      child: TabBar(
        controller: controller,
        isScrollable: false,
        indicatorColor: fc.primary,
        indicatorWeight: 2.5,
        labelColor: fc.primary,
        unselectedLabelColor: fc.textDisabled,
        labelPadding: EdgeInsets.zero,
        tabs: [
          for (final t in tabs)
            Tab(
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 17),
                  const SizedBox(height: 2),
                  Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MobileTab {
  final IconData icon;
  final String label;
  const MobileTab(this.icon, this.label);
}
