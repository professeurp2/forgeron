import 'package:flutter/material.dart';

import '../theme/forge_tokens.dart';
import '../theme/forgeron_colors.dart';

/// Composants du design v2 : carte, étiquette de section, pastille d'état,
/// bouton, entrée en cascade, squelette de chargement, avatar de présence.
///
/// Tous lisent la palette (`context.fc`) et les jetons (`forge_tokens.dart`) ;
/// aucun ne porte de couleur ou de durée en dur.

// ───────────────────────────── Carte ────────────────────────────────────────

/// La surface de base de la v2 : fond plein, filet fin, ombre courte. Au
/// survol (souris), elle se soulève d'un rien — sur PC, on pointe avant de
/// cliquer, et une surface qui répond se lit comme un objet.
class ForgeCard extends StatefulWidget {
  const ForgeCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(FSpace.lg),
    this.accent,
    this.onTap,
    this.expand = false,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Couleur d'état de la carte (filet et icône). `null` = neutre.
  final Color? accent;
  final VoidCallback? onTap;

  /// La carte remplit la hauteur qu'on lui donne (son contenu prend le reste).
  final bool expand;

  @override
  State<ForgeCard> createState() => _ForgeCardState();
}

class _ForgeCardState extends State<ForgeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final accent = widget.accent;
    final interactive = widget.onTap != null;
    final lifted = interactive && _hover;

    final header = widget.title == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(FSpace.lg, FSpace.md, FSpace.md, 0),
            child: Row(children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 15, color: accent ?? fc.primary),
                const SizedBox(width: FSpace.sm),
              ],
              Expanded(
                child: Text(widget.title!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FText.overline(fc)),
              ),
              ?widget.trailing,
            ]),
          );

    final body = Padding(padding: widget.padding, child: widget.child);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ?header,
        if (widget.expand) Expanded(child: body) else body,
      ],
    );

    final card = AnimatedContainer(
      duration: FMotion.of(context, FMotion.fast),
      curve: FMotion.curve,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(FRadius.lg),
        border: Border.all(
          color: accent != null
              ? accent.withValues(alpha: lifted ? 0.7 : 0.45)
              : (lifted ? fc.textDisabled : fc.surfaceBorder),
        ),
        boxShadow: lifted ? FShadow.raised(fc) : FShadow.card(fc),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (!interactive) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}

/// Surtitre de section, hors carte.
class ForgeSectionLabel extends StatelessWidget {
  const ForgeSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Row(children: [
      Container(
        width: 3,
        height: 12,
        decoration: BoxDecoration(color: fc.primary, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: FSpace.sm),
      Expanded(
        child: Text(text.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: FText.overline(fc)),
      ),
      ?trailing,
    ]);
  }
}

// ───────────────────────────── Pastille d'état ──────────────────────────────

/// État en un coup d'œil : un point (qui respire quand [pulse]) et un mot.
class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.pulse = false,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool pulse;
  final IconData? icon;
  final bool dense;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant StatusPill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final want = widget.pulse && !FMotion.reduced(context);
    if (want && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!want && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return AnimatedContainer(
      duration: FMotion.of(context, FMotion.base),
      padding: EdgeInsets.symmetric(
          horizontal: widget.dense ? 8 : 10, vertical: widget.dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.icon != null)
          Icon(widget.icon, size: 12, color: color)
        else
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  if (widget.pulse)
                    BoxShadow(
                        color: color.withValues(alpha: 0.25 + 0.5 * _c.value),
                        blurRadius: 4 + 6 * _c.value),
                ],
              ),
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: FText.ui,
                  color: color,
                  fontSize: widget.dense ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ),
      ]),
    );
  }
}

// ───────────────────────────── Bouton ───────────────────────────────────────

enum ForgeButtonKind { primary, tonal, ghost, danger }

/// Bouton v2 : il s'enfonce d'un rien à l'appui, et se grise proprement quand
/// il est inactif. Quatre genres, pas davantage.
class ForgeButton extends StatefulWidget {
  const ForgeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ForgeButtonKind.tonal,
    this.color,
    this.dense = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ForgeButtonKind kind;

  /// Teinte du bouton (défaut : la couleur primaire, ou le rouge pour danger).
  final Color? color;
  final bool dense;
  final bool expand;

  @override
  State<ForgeButton> createState() => _ForgeButtonState();
}

class _ForgeButtonState extends State<ForgeButton> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final enabled = widget.onPressed != null;
    final tint = widget.color ??
        (widget.kind == ForgeButtonKind.danger ? fc.danger : fc.primary);
    final (Color bg, Color fg, Color border) = switch (widget.kind) {
      ForgeButtonKind.primary || ForgeButtonKind.danger => (
          enabled ? tint : fc.surfaceHigh,
          enabled ? Colors.white : fc.textDisabled,
          Colors.transparent,
        ),
      ForgeButtonKind.tonal => (
          enabled ? tint.withValues(alpha: _hover ? 0.22 : 0.14) : fc.surfaceBright,
          enabled ? tint : fc.textDisabled,
          enabled ? tint.withValues(alpha: 0.5) : fc.surfaceBorder,
        ),
      ForgeButtonKind.ghost => (
          _hover && enabled ? fc.textPrimary.withValues(alpha: 0.06) : Colors.transparent,
          enabled ? fc.textSecondary : fc.textDisabled,
          fc.surfaceBorder,
        ),
    };

    final child = AnimatedScale(
      duration: FMotion.of(context, FMotion.fast),
      scale: _down && enabled ? 0.97 : 1,
      child: AnimatedContainer(
        duration: FMotion.of(context, FMotion.fast),
        padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 12 : 16, vertical: widget.dense ? 7 : 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(FRadius.md),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.dense ? 14 : 16, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: FText.ui,
                      color: fg,
                      fontSize: widget.dense ? 12 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: child,
        ),
      ),
    );
  }
}

// ───────────────────────────── Entrée en cascade ────────────────────────────

/// Fait entrer son enfant en fondu-glissé, après [index] × le décalage de
/// cascade. Une page dont les cartes arrivent l'une après l'autre se lit dans
/// l'ordre ; une page qui apparaît d'un bloc se subit.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.from = const Offset(0, 12)});

  final int index;
  final Widget child;
  final Offset from;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: FMotion.slow);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (FMotion.reduced(context)) {
      _c.value = 1;
      return;
    }
    // Le délai est porté par l'animation elle-même (un intervalle), pas par
    // une minuterie : rien ne reste en attente si la page est quittée.
    final delay = (FMotion.stagger * widget.index.clamp(0, 12)).inMilliseconds;
    final total = delay + FMotion.slow.inMilliseconds;
    _c.duration = Duration(milliseconds: total);
    _curve = CurvedAnimation(
        parent: _c, curve: Interval(delay / total, 1, curve: FMotion.emphasized));
    _c.forward();
  }

  Animation<double>? _curve;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = _curve ?? _c;
    return AnimatedBuilder(
      animation: anim,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: anim.value.clamp(0, 1),
        child: Transform.translate(offset: widget.from * (1 - anim.value), child: child),
      ),
    );
  }
}

// ───────────────────────────── Squelette ────────────────────────────────────

/// Bloc de chargement : une lueur qui traverse, à la place d'une roue qui
/// tourne au milieu d'un rectangle noir.
class ForgeSkeleton extends StatefulWidget {
  const ForgeSkeleton({super.key, this.width, this.height = 14, this.radius = FRadius.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  State<ForgeSkeleton> createState() => _ForgeSkeletonState();
}

class _ForgeSkeletonState extends State<ForgeSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 0.6, 0),
              end: Alignment(t + 0.6, 0),
              colors: [fc.surfaceBright, fc.surfaceHigh, fc.surfaceBright],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── Présence ─────────────────────────────────────

/// Pastille d'un participant : son initiale sur sa couleur, un point vert
/// s'il est relié. Sert au coworking (qui est dans la session ?).
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.name,
    required this.color,
    this.icon,
    this.online = true,
    this.size = 28,
  });

  final String name;
  final Color color;
  final IconData? icon;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Tooltip(
      message: name,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: icon != null
                ? Icon(icon, size: size * 0.5, color: color)
                : Text(initial,
                    style: TextStyle(
                        fontFamily: FText.ui,
                        color: color,
                        fontSize: size * 0.46,
                        fontWeight: FontWeight.w700,
                        height: 1)),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: online ? fc.success : fc.textDisabled,
                shape: BoxShape.circle,
                border: Border.all(color: fc.surface, width: 1.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Transition de page partagée par toutes les plateformes : fondu et léger
/// glissement vers le haut. La transition par défaut de Windows (zoom) et
/// celle d'Android (glissement latéral) juraient dans la même application.
class ForgePageTransitionsBuilder extends PageTransitionsBuilder {
  const ForgePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (FMotion.reduced(context)) return child;
    final enter = CurvedAnimation(parent: animation, curve: FMotion.emphasized);
    final leave = CurvedAnimation(parent: secondaryAnimation, curve: FMotion.curve);
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(enter),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.6).animate(leave),
          child: child,
        ),
      ),
    );
  }
}
