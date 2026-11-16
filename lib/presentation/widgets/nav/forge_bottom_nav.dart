import 'package:flutter/material.dart';
import '../../../core/theme/forgeron_colors.dart';

/// Une destination de la barre de navigation mobile.
class ForgeNavDestination {
  final IconData icon;
  final String label;
  const ForgeNavDestination(this.icon, this.label);
}

/// Barre de navigation mobile premium « Forge Noire ».
///
/// Les destinations sont réparties 3 / 3 autour de l'encoche centrale qui
/// accueille le FAB E-STOP. L'onglet actif s'illumine (pilule + halo orange,
/// icône agrandie, label qui apparaît). Theme-aware via [context.fc].
class ForgeBottomNav extends StatelessWidget {
  final List<ForgeNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ForgeBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    // Répartition symétrique autour du FAB central.
    final half = (destinations.length / 2).ceil();
    final left = destinations.take(half).toList();
    final right = destinations.skip(half).toList();

    Widget itemsRow(List<ForgeNavDestination> group, int offset) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < group.length; i++)
            _NavItem(
              destination: group[i],
              selected: (offset + i) == selectedIndex,
              onTap: () => onTap(offset + i),
            ),
        ],
      );
    }

    return BottomAppBar(
      color: fc.surface,
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: fc.surfaceBorder)),
        ),
        child: Row(
          children: [
            Expanded(child: itemsRow(left, 0)),
            // Réserve l'espace de l'encoche du FAB E-STOP.
            const SizedBox(width: 64),
            Expanded(child: itemsRow(right, half)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ForgeNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final activeColor = fc.primary;
    final idleColor = fc.textDisabled;

    return Expanded(
      // Sur un petit écran (Galaxy A03s : 360 dp de large), chaque destination
      // ne dispose que de ~49 dp une fois l'encoche du FAB déduite. La pilule
      // d'icône débordait ; on adapte donc icône, marges et label à la place
      // réellement disponible plutôt que d'imposer des tailles fixes.
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final tight = w < 56;
        final iconSize = tight ? 19.0 : 22.0;
        final padH = selected ? (tight ? 7.0 : 12.0) : (tight ? 4.0 : 8.0);
        final showLabel = selected && w >= 48;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: activeColor.withValues(alpha: 0.06),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pilule illuminée derrière l'icône active.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    scale: selected ? 1.12 : 1.0,
                    child: Icon(
                      destination.icon,
                      size: iconSize,
                      color: selected ? activeColor : idleColor,
                    ),
                  ),
                ),
                // Label du seul onglet actif — masqué s'il n'y a pas la place.
                if (showLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
