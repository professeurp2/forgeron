import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/providers/backoffice_provider.dart';
import '../../application/services/chat_relay.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forge_tokens.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/forge_ui.dart';
import '../../core/widgets/responsive_layout.dart';
import 'remote_chat_screen.dart';

/// Coworking : une session de travail partagée entre le PC et une tablette
/// (ou un téléphone) du même réseau.
///
/// - **Héberger** (le PC) : ouvre la session, affiche le code et l'adresse,
///   montre qui est relié et ce que chacun fait.
/// - **Rejoindre** (la tablette) : voit l'état de la machine du PC, pilote
///   son simulateur, parle au même agent IA, confirme ses actions — et garde
///   un bouton STOP qui agit par deux chemins.
///
/// Ce qu'un invité ne fait jamais par ce lien : commander un axe. Il passe
/// par l'agent (carte de confirmation) ou par le simulateur.
class CoworkScreen extends ConsumerStatefulWidget {
  const CoworkScreen({super.key, this.standalone = false, this.forceGuest});

  /// Poussé seul (mobile) : l'écran porte alors sa barre.
  final bool standalone;

  /// Force la vue (tests). `null` : hôte sur un poste, invité ailleurs.
  final bool? forceGuest;

  @override
  ConsumerState<CoworkScreen> createState() => _CoworkScreenState();
}

/// Adresses IPv4 de ce poste, à dicter à la tablette.
final coworkLocalAddressesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    return [for (final i in ifaces) for (final a in i.addresses) a.address];
  } catch (_) {
    return const [];
  }
});

class _CoworkScreenState extends ConsumerState<CoworkScreen> {
  late bool _guest =
      widget.forceGuest ?? !ResponsiveLayout.isDesktopPlatform;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final joined = ref.watch(remoteChatClientProvider
        .select((s) => s.status == RemoteChatStatus.connected));
    final hosting = ref.watch(chatRelayHostProvider.select((s) => s.running));

    final body = Column(children: [
      // On ne change pas de rôle en pleine session.
      if (!joined && !hosting && widget.forceGuest == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(FSpace.lg, FSpace.lg, FSpace.lg, 0),
          child: _RoleSwitch(
            guest: _guest,
            onChanged: (g) => setState(() => _guest = g),
          ),
        ),
      Expanded(
        child: AnimatedSwitcher(
          duration: FMotion.of(context, FMotion.base),
          switchInCurve: FMotion.curve,
          child: _guest
              ? const _GuestView(key: ValueKey('invite'))
              : const _HostView(key: ValueKey('hote')),
        ),
      ),
    ]);

    if (!widget.standalone) return Container(color: fc.background, child: body);
    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(title: Text(tr('COWORKING'))),
      body: SafeArea(child: body),
    );
  }
}

class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.guest, required this.onChanged});
  final bool guest;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    Widget seg(bool value, IconData icon, String label) {
      final selected = guest == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: FMotion.of(context, FMotion.fast),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? fc.primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(FRadius.sm),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: selected ? fc.primary : fc.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FText.body(fc).copyWith(
                        color: selected ? fc.primary : fc.textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: fc.surface,
            borderRadius: BorderRadius.circular(FRadius.md),
            border: Border.all(color: fc.surfaceBorder),
          ),
          child: Row(children: [
            seg(false, Icons.desktop_windows_outlined, tr('Héberger (ce poste)')),
            seg(true, Icons.tablet_mac_outlined, tr('Rejoindre un PC')),
          ]),
        ),
      ),
    );
  }
}

IconData _kindIcon(String kind) => switch (kind) {
      CoworkKind.host => Icons.desktop_windows_rounded,
      CoworkKind.tablet => Icons.tablet_mac_rounded,
      CoworkKind.desktop => Icons.laptop_mac_rounded,
      _ => Icons.smartphone_rounded,
    };

String _kindLabel(String kind) => switch (kind) {
      CoworkKind.host => tr('PC hôte'),
      CoworkKind.tablet => tr('Tablette'),
      CoworkKind.desktop => tr('PC'),
      _ => tr('Téléphone'),
    };

Color _participantColor(ForgeronColorPalette fc, int i) =>
    [fc.secondary, fc.success, fc.warning, fc.info, fc.axisA][i % 5];

// ═══════════════════════════════ HÔTE ═══════════════════════════════════════

class _HostView extends ConsumerWidget {
  const _HostView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final host = ref.watch(chatRelayHostProvider);
    final ctl = ref.read(chatRelayHostProvider.notifier);
    final addresses = ref.watch(coworkLocalAddressesProvider).valueOrNull ?? const [];
    final activity = ref
        .watch(backofficeBusProvider)
        .where((e) => e.source == BackofficeSource.relais)
        .toList()
        .reversed
        .take(30)
        .toList();

    final session = ForgeCard(
      title: tr('Session'),
      icon: Icons.hub_outlined,
      accent: host.running ? fc.success : null,
      trailing: StatusPill(
        label: host.running ? tr('OUVERTE') : tr('FERMÉE'),
        color: host.running ? fc.success : fc.textDisabled,
        pulse: host.running,
        dense: true,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (host.error != null) ...[
          Text(host.error!, style: FText.caption(fc).copyWith(color: fc.danger)),
          const SizedBox(height: FSpace.md),
        ],
        AnimatedSwitcher(
          duration: FMotion.of(context, FMotion.base),
          child: host.running
              ? Column(
                  key: const ValueKey('code'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Code de liaison'), style: FText.caption(fc)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        (host.code ?? '').split('').join(' '),
                        style: FText.data(fc, size: 40, color: fc.primary)
                            .copyWith(fontWeight: FontWeight.w700, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(height: FSpace.md),
                    Text(tr('Adresse de ce PC'), style: FText.caption(fc)),
                    const SizedBox(height: 4),
                    if (addresses.isEmpty)
                      Text(tr('aucune adresse réseau trouvée'),
                          style: FText.caption(fc).copyWith(color: fc.warning))
                    else
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final a in addresses)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: fc.surfaceBright,
                              borderRadius: BorderRadius.circular(FRadius.sm),
                              border: Border.all(color: fc.surfaceBorder),
                            ),
                            child: SelectableText(a, style: FText.data(fc)),
                          ),
                      ]),
                  ],
                )
              : Text(
                  key: const ValueKey('ferme'),
                  tr('Ouvre la session pour qu\'une tablette ou un téléphone du même réseau rejoigne ce poste. Un code à 6 chiffres protège la liaison.'),
                  style: FText.body(fc).copyWith(color: fc.textSecondary),
                ),
        ),
        const SizedBox(height: FSpace.lg),
        ForgeButton(
          label: host.running ? tr('Fermer la session') : tr('Ouvrir la session'),
          icon: host.running ? Icons.link_off_rounded : Icons.play_arrow_rounded,
          kind: host.running ? ForgeButtonKind.ghost : ForgeButtonKind.primary,
          expand: true,
          onPressed: () {
            HapticFeedback.selectionClick();
            host.running ? ctl.stop() : ctl.start();
          },
        ),
      ]),
    );

    final people = ForgeCard(
      title: tr('Participants'),
      icon: Icons.groups_2_outlined,
      trailing: Text('${host.participants.length}', style: FText.data(fc, color: fc.textSecondary)),
      child: host.participants.isEmpty
          ? Text(
              host.running
                  ? tr('Personne pour l\'instant. Sur la tablette : Coworking → Rejoindre un PC.')
                  : tr('La session est fermée.'),
              style: FText.caption(fc))
          : Column(children: [
              for (var i = 0; i < host.participants.length; i++)
                AppearIn(
                  key: ValueKey(host.participants[i].id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      PresenceAvatar(
                        name: host.participants[i].name,
                        color: _participantColor(fc, i),
                        icon: _kindIcon(host.participants[i].kind),
                        size: 34,
                      ),
                      const SizedBox(width: FSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(host.participants[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FText.body(fc).copyWith(fontWeight: FontWeight.w700)),
                          Text(_kindLabel(host.participants[i].kind), style: FText.caption(fc)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
    );

    final rules = ForgeCard(
      title: tr('Ce qu\'un invité peut faire'),
      icon: Icons.verified_user_outlined,
      child: Column(children: [
        for (final r in [
          (Icons.visibility_outlined, tr('Voir l\'état de la machine et l\'avancement, en direct'), fc.success),
          (Icons.forum_outlined, tr('Parler au même agent IA et confirmer ses actions'), fc.success),
          (Icons.view_in_ar_outlined, tr('Piloter le simulateur et le jumeau de ce PC'), fc.success),
          (Icons.dangerous_outlined, tr('Arrêter d\'urgence : chez lui d\'abord, puis par ce PC'), fc.success),
          (Icons.block_outlined, tr('Commander un axe par le lien : jamais'), fc.danger),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(r.$1, size: 16, color: r.$3),
              const SizedBox(width: FSpace.sm),
              Expanded(child: Text(r.$2, style: FText.caption(fc).copyWith(color: fc.textPrimary))),
            ]),
          ),
      ]),
    );

    final feed = ForgeCard(
      title: tr('Activité de la session'),
      icon: Icons.history_rounded,
      expand: true,
      padding: const EdgeInsets.fromLTRB(FSpace.lg, FSpace.sm, FSpace.lg, FSpace.md),
      child: activity.isEmpty
          ? Center(child: Text(tr('Rien encore.'), style: FText.caption(fc)))
          : ListView.builder(
              itemCount: activity.length,
              itemBuilder: (_, i) {
                final e = activity[i];
                final color = switch (e.severity) {
                  BackofficeSeverity.critical => fc.danger,
                  BackofficeSeverity.warning => fc.warning,
                  BackofficeSeverity.notice => fc.info,
                  _ => fc.textDisabled,
                };
                return AppearIn(
                  key: ValueKey(e.seq),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: FSpace.sm),
                      Expanded(
                        child: Text(e.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FText.caption(fc).copyWith(color: fc.textPrimary)),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 960) {
        return Padding(
          padding: const EdgeInsets.all(FSpace.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(children: [
                  StaggerIn(index: 0, child: session),
                  const SizedBox(height: FSpace.lg),
                  StaggerIn(index: 1, child: rules),
                ]),
              ),
            ),
            const SizedBox(width: FSpace.lg),
            Expanded(
              child: Column(children: [
                StaggerIn(index: 2, child: people),
                const SizedBox(height: FSpace.lg),
                Expanded(child: StaggerIn(index: 3, child: feed)),
              ]),
            ),
          ]),
        );
      }
      return ListView(padding: const EdgeInsets.all(FSpace.lg), children: [
        StaggerIn(index: 0, child: session),
        const SizedBox(height: FSpace.lg),
        StaggerIn(index: 1, child: people),
        const SizedBox(height: FSpace.lg),
        StaggerIn(index: 2, child: rules),
        const SizedBox(height: FSpace.lg),
        SizedBox(height: 320, child: StaggerIn(index: 3, child: feed)),
      ]);
    });
  }
}

// ═══════════════════════════════ INVITÉ ═════════════════════════════════════

class _GuestView extends ConsumerStatefulWidget {
  const _GuestView({super.key});

  @override
  ConsumerState<_GuestView> createState() => _GuestViewState();
}

class _GuestViewState extends ConsumerState<_GuestView> {
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _code = TextEditingController();
  bool? _localStop;

  static const _kName = 'cowork_device_name';
  static const _kHost = 'cowork_last_host';

  @override
  void initState() {
    super.initState();
    final client = ref.read(remoteChatClientProvider.notifier);
    _host.text = ref.read(remoteChatClientProvider).host ?? client.defaultHost();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final name = prefs.getString(_kName);
      final host = prefs.getString(_kHost);
      if (name != null && _name.text.isEmpty) _name.text = name;
      if (host != null && _host.text.isEmpty) _host.text = host;
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _code.dispose();
    super.dispose();
  }

  String _kind(BuildContext context) => ResponsiveLayout.isDesktopPlatform
      ? CoworkKind.desktop
      : (MediaQuery.sizeOf(context).shortestSide >= 600 ? CoworkKind.tablet : CoworkKind.phone);

  Future<void> _join() async {
    final kind = _kind(context);
    final name = _name.text.trim().isEmpty ? _kindLabel(kind) : _name.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kName, name);
      await prefs.setString(_kHost, _host.text.trim());
    } catch (_) {}
    await ref
        .read(remoteChatClientProvider.notifier)
        .connect(_host.text.trim(), _code.text.trim(), name: name, kind: kind);
  }

  Future<void> _stop() async {
    HapticFeedback.heavyImpact();
    final local = await ref.read(remoteChatClientProvider.notifier).stopEverywhere();
    if (mounted) setState(() => _localStop = local);
  }

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(remoteChatClientProvider);
    if (remote.status != RemoteChatStatus.connected) return _joinForm(context, remote);
    return _session(context, remote);
  }

  Widget _joinForm(BuildContext context, RemoteChatState remote) {
    final fc = context.fc;
    final busy = remote.status == RemoteChatStatus.connecting;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: StaggerIn(
            index: 0,
            child: ForgeCard(
              title: tr('Rejoindre un PC'),
              icon: Icons.tablet_mac_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  tr('Sur le PC : Coworking → « Ouvrir la session ». Il affiche son adresse et un code à 6 chiffres.'),
                  style: FText.body(fc).copyWith(color: fc.textSecondary),
                ),
                const SizedBox(height: FSpace.lg),
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('Nom de cet appareil'),
                    hintText: _kindLabel(_kind(context)),
                    prefixIcon: Icon(_kindIcon(_kind(context)), size: 18),
                  ),
                ),
                const SizedBox(height: FSpace.md),
                TextField(
                  controller: _host,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('Adresse du PC'),
                    hintText: '192.168.0.10',
                    prefixIcon: const Icon(Icons.lan_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: FSpace.md),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => busy ? null : _join(),
                  style: FText.data(fc, size: 22).copyWith(letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: tr('Code de liaison'),
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                  ),
                ),
                AnimatedSize(
                  duration: FMotion.of(context, FMotion.base),
                  child: remote.error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: FSpace.md),
                          child: Text(remote.error!,
                              style: FText.caption(fc).copyWith(color: fc.danger)),
                        ),
                ),
                const SizedBox(height: FSpace.lg),
                ForgeButton(
                  label: busy ? tr('Liaison…') : tr('Rejoindre'),
                  icon: Icons.link_rounded,
                  kind: ForgeButtonKind.primary,
                  expand: true,
                  onPressed: busy ? null : _join,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _session(BuildContext context, RemoteChatState remote) {
    final fc = context.fc;
    final client = ref.read(remoteChatClientProvider.notifier);

    // Sur téléphone, la pastille de liaison passe sous les avatars : dans la
    // rangée, elle serait coupée par le bouton STOP.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final linked = StatusPill(
      label: tr('Relié à {}', [remote.hostName ?? remote.host ?? 'PC']),
      color: fc.success,
      pulse: true,
      dense: true,
    );
    final barRow = Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < remote.participants.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PresenceAvatar(
                    name: remote.participants[i].name +
                        (remote.participants[i].id == remote.selfId ? tr(' (moi)') : ''),
                    color: remote.participants[i].isHost
                        ? fc.primary
                        : _participantColor(fc, i),
                    icon: _kindIcon(remote.participants[i].kind),
                    size: 32,
                  ),
                ),
              if (!narrow) ...[const SizedBox(width: 4), linked],
            ]),
          ),
        ),
        const SizedBox(width: FSpace.sm),
        IconButton(
          tooltip: tr('Quitter la session'),
          icon: Icon(Icons.logout_rounded, color: fc.textSecondary, size: 20),
          onPressed: client.disconnect,
        ),
        const SizedBox(width: 4),
        ForgeButton(
          label: tr('STOP'),
          icon: Icons.dangerous_rounded,
          kind: ForgeButtonKind.danger,
          onPressed: _stop,
        ),
    ]);
    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: FSpace.lg, vertical: FSpace.sm),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              barRow,
              const SizedBox(height: 6),
              linked,
            ])
          : barRow,
    );

    final stopBanner = _StopBanner(local: _localStop, relayed: remote.estopRelayed);
    final workspace = _WorkspacePanel(workspace: remote.workspace, onSim: client.sim);
    const chat = RemoteChatScreen(embedded: true);

    return Column(children: [
      bar,
      stopBanner,
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 11, child: workspace),
              Container(width: 1, color: fc.surfaceBorder),
              const Expanded(flex: 9, child: chat),
            ]);
          }
          return DefaultTabController(
            length: 2,
            child: Column(children: [
              TabBar(tabs: [
                Tab(text: tr('POSTE')),
                Tab(text: tr('DISCUSSION')),
              ]),
              Expanded(child: TabBarView(children: [workspace, chat])),
            ]),
          );
        }),
      ),
    ]);
  }
}

/// Ce que les deux chemins de l'arrêt d'urgence ont donné. Affiché tant
/// qu'un arrêt a été demandé : l'opérateur doit savoir si la machine est
/// réellement arrêtée, pas le supposer.
class _StopBanner extends StatelessWidget {
  const _StopBanner({required this.local, required this.relayed});
  final bool? local;
  final bool? relayed;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final asked = local != null;
    final ok = local == true || relayed == true;
    final text = !asked
        ? ''
        : ok
            ? (relayed == true
                ? tr('Arrêt d\'urgence transmis à la carte par le PC.')
                : tr('Arrêt d\'urgence transmis par cet appareil. Réponse du PC en attente.'))
            : (relayed == false
                ? tr('ARRÊT NON TRANSMIS : ni cet appareil ni le PC n\'ont joint la carte. Coupe l\'alimentation.')
                : tr('Cet appareil n\'a pas de liaison à la carte : arrêt demandé au PC, réponse en attente…'));
    final color = ok ? fc.success : (relayed == false ? fc.danger : fc.warning);
    return AnimatedSize(
      duration: FMotion.of(context, FMotion.base),
      curve: FMotion.curve,
      child: !asked
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: FSpace.lg, vertical: FSpace.sm),
              color: color.withValues(alpha: 0.14),
              child: Row(children: [
                Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 16, color: color),
                const SizedBox(width: FSpace.sm),
                Expanded(
                  child: Text(text,
                      style: FText.caption(fc)
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
    );
  }
}

/// Le poste du PC, vu de l'invité : cotes, programme, simulateur.
class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({required this.workspace, required this.onSim});
  final CoworkWorkspace? workspace;
  final void Function(String action, [num? value]) onSim;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final w = workspace;
    if (w == null) {
      // Le PC n'a encore rien envoyé (ou ne parle que le chat) : des
      // squelettes, pas des zéros qui passeraient pour des cotes.
      return ListView(padding: const EdgeInsets.all(FSpace.lg), children: [
        ForgeCard(
          title: tr('Machine'),
          icon: Icons.precision_manufacturing_outlined,
          child: Column(children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: ForgeSkeleton(height: 26),
              ),
            const SizedBox(height: FSpace.sm),
            Text(tr('En attente de l\'état du poste…'), style: FText.caption(fc)),
          ]),
        ),
      ]);
    }

    final statusColor = switch (w.status) {
      'alarm' => fc.danger,
      'run' || 'home' => fc.success,
      'hold' => fc.warning,
      'offline' => fc.textDisabled,
      _ => fc.info,
    };
    final axes = [
      ('X', fc.axisX, false),
      ('Y', fc.axisY, false),
      ('Z', fc.axisZ, false),
      ('A', fc.axisA, true),
      ('C', fc.axisC, true),
    ];
    final live = w.simStatus == 'live';
    final playing = w.simStatus == 'playing';

    return ListView(padding: const EdgeInsets.all(FSpace.lg), children: [
      StaggerIn(
        index: 0,
        child: ForgeCard(
          title: tr('Machine du PC'),
          icon: Icons.precision_manufacturing_outlined,
          trailing: StatusPill(
            label: w.status.toUpperCase() + (w.alarm != null ? ' ${w.alarm}' : ''),
            color: statusColor,
            pulse: w.status == 'run' || w.status == 'alarm',
            dense: true,
          ),
          child: Column(children: [
            for (var i = 0; i < axes.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: fc.background,
                  borderRadius: BorderRadius.circular(FRadius.sm),
                  border: Border(left: BorderSide(color: axes[i].$2, width: 3)),
                ),
                child: Row(children: [
                  Text(axes[i].$1,
                      style: FText.data(fc, size: 20, color: axes[i].$2)
                          .copyWith(fontWeight: FontWeight.w700)),
                  Expanded(
                    child: AnimatedNumberText(
                      w.wPos[i],
                      decimals: axes[i].$3 ? 2 : 3,
                      suffix: axes[i].$3 ? '°' : '',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      duration: const Duration(milliseconds: 240),
                      style: FText.data(fc, size: 24, color: w.online ? fc.textPrimary : fc.textDisabled)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _Metric(label: tr('Avance'), value: '${w.feed.round()}', unit: 'mm/min')),
              const SizedBox(width: FSpace.sm),
              Expanded(child: _Metric(label: tr('Broche'), value: '${w.spindle.round()}', unit: 'tr/min')),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: FSpace.lg),
      StaggerIn(
        index: 1,
        child: ForgeCard(
          title: tr('Programme'),
          icon: Icons.description_outlined,
          trailing: w.streaming
              ? StatusPill(label: tr('EN COURS'), color: fc.success, pulse: true, dense: true)
              : null,
          child: !w.hasProgram
              ? Text(tr('Aucun programme chargé sur le PC.'), style: FText.caption(fc))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(tr('Ligne {} / {}', [w.line, w.totalLines]), style: FText.data(fc)),
                    const Spacer(),
                    Text('${(w.programFraction * 100).round()} %',
                        style: FText.data(fc, color: fc.primary)),
                  ]),
                  const SizedBox(height: FSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FRadius.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: w.programFraction),
                      duration: FMotion.of(context, FMotion.slow),
                      curve: FMotion.curve,
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
                    ),
                  ),
                ]),
        ),
      ),
      const SizedBox(height: FSpace.lg),
      StaggerIn(
        index: 2,
        child: ForgeCard(
          title: tr('Simulateur du PC'),
          icon: Icons.view_in_ar_outlined,
          accent: live ? fc.success : null,
          trailing: StatusPill(
            label: switch (w.simStatus) {
              'live' => tr('JUMEAU'),
              'playing' => tr('LECTURE'),
              'paused' => tr('PAUSE'),
              'completed' => tr('TERMINÉ'),
              _ => tr('ARRÊTÉ'),
            },
            color: live ? fc.success : (playing ? fc.primary : fc.textDisabled),
            pulse: live || playing,
            dense: true,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              tr('Tu pilotes le simulateur affiché sur le PC. Rien de ce qui suit ne fait bouger un axe.'),
              style: FText.caption(fc),
            ),
            const SizedBox(height: FSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(FRadius.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: w.simProgress / 100),
                duration: FMotion.of(context, FMotion.base),
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4),
              ),
            ),
            if (w.simDeviation != null) ...[
              const SizedBox(height: FSpace.sm),
              Text(tr('Écart parcours ↔ position réelle : {} mm', [w.simDeviation!.toStringAsFixed(2)]),
                  style: FText.caption(fc).copyWith(
                      color: w.simDeviation! > 2 ? fc.warning : fc.textSecondary)),
            ],
            const SizedBox(height: FSpace.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ForgeButton(
                label: live ? tr('Arrêter le jumeau') : tr('Jumeau'),
                icon: Icons.sensors_rounded,
                color: fc.success,
                dense: true,
                onPressed: w.online ? () => onSim(live ? 'stop_follow' : 'follow') : null,
              ),
              ForgeButton(
                label: playing ? tr('Pause') : tr('Simuler'),
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                dense: true,
                onPressed: w.hasProgram ? () => onSim(playing ? 'pause' : 'play') : null,
              ),
              ForgeButton(
                label: tr('Remettre à zéro'),
                icon: Icons.replay_rounded,
                kind: ForgeButtonKind.ghost,
                dense: true,
                onPressed: () => onSim('reset'),
              ),
              for (final s in const [1, 10, 50])
                ForgeButton(
                  label: '×$s',
                  kind: w.simSpeed == s ? ForgeButtonKind.tonal : ForgeButtonKind.ghost,
                  dense: true,
                  onPressed: () => onSim('speed', s),
                ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});
  final String label, value, unit;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        borderRadius: BorderRadius.circular(FRadius.sm),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: FText.overline(fc).copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            AnimatedSwapText(value, style: FText.data(fc, size: 18)),
            const SizedBox(width: 4),
            Text(unit, style: FText.caption(fc)),
          ]),
        ),
      ]),
    );
  }
}
