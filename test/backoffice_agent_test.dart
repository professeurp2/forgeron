import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/backoffice_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// Faux modèle : rejoue des réponses scriptées.
class _FakeBackend implements AiBackend {
  _FakeBackend(this.model, this.script);
  final List<AiApiResponse> script;

  /// Doit être le modèle du réglage actif, sinon le contrôleur le remplace.
  @override
  final String model;
  @override
  int get historyBudgetChars => 100000;
  @override
  bool get usesCellular => false;
  @override
  Future<bool> isReachable() async => true;
  @override
  String get unreachableMessage => 'hors ligne';
  @override
  void dispose() {}

  AiApiResponse _next() => script.isEmpty
      ? const AiApiResponse(parts: [
          {'text': 'Voilà.'}
        ], finishReason: 'STOP')
      : script.removeAt(0);

  @override
  Future<AiApiResponse> sendMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt}) async =>
      _next();

  @override
  Future<AiApiResponse> streamMessages(
          {required List<Map<String, dynamic>> contents,
          required List<Map<String, dynamic>> functionDeclarations,
          String? systemPrompt,
          void Function(String partialText)? onDelta,
          bool Function()? shouldCancel}) async =>
      _next();
}

/// Un dépôt qui rejoue le trafic comme la vraie liaison : chaque envoi est
/// publié sur `trafficStream`, et la carte répond `ok`.
class _TalkativeRepository extends FakeMachineRepository {
  final _traffic = StreamController<String>.broadcast();

  @override
  Stream<String> get trafficStream => _traffic.stream;

  @override
  Future<void> sendGCode(String gcode) async {
    await super.sendGCode(gcode);
    _traffic.add('TX: $gcode\n');
    _traffic.add('RX: ok');
  }

  @override
  void sendRaw(String data) {
    super.sendRaw(data);
    _traffic.add('TX: $data');
  }

  /// Même séquence que le vrai dépôt : annulation du jog, puis `$J=…`.
  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    await super.jog(axis, distance, feedrate);
    sendRaw('\x85');
    sendRaw('\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feedrate.toStringAsFixed(0)}\n');
    _traffic.add('RX: ok');
  }

  void close() => _traffic.close();
}

AiApiResponse _call(String name, Map<String, dynamic> args) => AiApiResponse(parts: [
      {
        'functionCall': {'name': name, 'args': args}
      }
    ], finishReason: 'STOP', totalTokens: 321);

Future<void> _until(bool Function() ok, {String? what}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) fail('délai dépassé : ${what ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Ce que le backoffice voit de l'agent : message, tour du modèle, appel
/// d'outil, confirmation (et par qui), exécution, et la commande réellement
/// partie vers la carte, reliée au même appel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TalkativeRepository repo;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _TalkativeRepository();
    c = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(repo),
      backofficeBusProvider.overrideWith((ref) => BackofficeBus()),
      lexiconSourceProvider.overrideWithValue(
          () async => File('assets/lexicon/lexique.json').readAsString()),
    ]);
    addTearDown(() {
      c.dispose();
      repo.close();
    });
    // Les sondes de la carte : sans elles, aucun `firmware.*`.
    c.read(backofficeProbesProvider);
    await c.read(lexiconLoadProvider.future);
  });

  AiAgentController ctl() => c.read(aiAgentControllerProvider.notifier);
  _FakeBackend backend(List<AiApiResponse> script) =>
      _FakeBackend(c.read(aiModelProvider).active.id, script);
  List<BackofficeEvent> events() => c.read(backofficeBusProvider);
  List<String> kinds() => events().map((e) => e.kind).toList();
  BackofficeEvent one(String kind) => events().singleWhere((e) => e.kind == kind);

  test('lecture d\'état : message → tour → demande → exécution, sans la carte', () async {
    ctl().debugUseBackend(backend([_call('get_machine_state', const {})]));
    // « Donne-moi l'état » passerait par le lexique ; on force le modèle avec
    // une phrase qu'il ne connaît pas.
    await ctl().sendUserMessage('Peux-tu me dire comment va la fraiseuse aujourd\'hui ?');
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);

    expect(kinds(), containsAllInOrder([
      'ia.message',
      'ia.tour',
      'ia.outil.demande',
      'ia.outil.execute',
      'ia.tour',
    ]));
    final msg = one('ia.message');
    expect(msg.origin, BackofficeOrigin.local);
    expect(msg.turnId, 't1');
    expect(msg.details['apercu'], contains('fraiseuse'));

    final tours = events().where((e) => e.kind == 'ia.tour').toList();
    expect(tours.first.details['outils_demandes'], ['get_machine_state']);
    expect(tours.first.details['tokens'], 321);
    expect(tours.first.details['backend'], 'local');
    expect(tours.first.origin, BackofficeOrigin.modele);
    expect(tours.first.turnId, 't1');

    final ex = one('ia.outil.execute');
    expect(ex.details['outil'], 'get_machine_state');
    expect(ex.details['echec'], isFalse);
    expect(ex.callId, one('ia.outil.demande').callId);
    expect(events().where((e) => e.kind == 'ia.outil.attente'), isEmpty,
        reason: 'une lecture ne demande pas de confirmation');
  });

  test('un mouvement confirmé depuis le téléphone : la commande vers la carte porte l\'appel',
      () async {
    ctl().debugUseBackend(backend([
      _call('jog_axis', const {'axis': 'X', 'distance': 5.0, 'feedrate': 500}),
    ]));
    await ctl().sendUserMessage('Peux-tu déplacer un petit peu vers la droite ?',
        origin: BackofficeOrigin.relais);
    await _until(() => c.read(aiAgentControllerProvider).pendingConfirmation != null,
        what: 'carte de confirmation');

    final attente = one('ia.outil.attente');
    expect(attente.details['outil'], 'jog_axis');
    expect(attente.details['categorie'], 'movement');
    expect(one('ia.message').origin, BackofficeOrigin.relais);
    expect(repo.jogCalls, isEmpty, reason: 'rien ne part avant le geste');

    await ctl().confirmPendingAction(origin: BackofficeOrigin.relais);
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);
    await _until(() => events().any((e) => e.kind == 'firmware.tx'), what: 'trafic carte');

    final confirme = one('ia.outil.confirme');
    expect(confirme.origin, BackofficeOrigin.relais);
    expect(confirme.callId, attente.callId);

    final tx = events().where((e) => e.kind == 'firmware.tx').toList();
    expect(tx, isNotEmpty);
    expect(tx.map((e) => e.callId), everyElement(attente.callId),
        reason: 'la commande est attribuée à l\'appel que le téléphone a confirmé');
    expect(tx.map((e) => e.origin), everyElement(BackofficeOrigin.relais));
    expect(tx.last.summary, contains('Jog'));

    final chain = c.read(backofficeChainsProvider).singleWhere((ch) => ch.callId == attente.callId);
    expect(chain.tool, 'jog_axis');
    expect(chain.confirmation?.origin, BackofficeOrigin.relais);
    expect(chain.touchesFirmware, isTrue);
    expect(chain.status, BackofficeChainStatus.ok);

    final stats = c.read(backofficeStatsProvider);
    expect(stats.confirmationsRelais, 1);
    expect(stats.commandesIa, tx.length);
  });

  test('un refus est tracé, rien ne part', () async {
    ctl().debugUseBackend(backend([_call('home', const {})]));
    await ctl().sendUserMessage('Peux-tu lancer la prise des origines de la fraiseuse ?');
    await _until(() => c.read(aiAgentControllerProvider).pendingConfirmation != null);
    await ctl().rejectPendingAction();
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);

    expect(one('ia.outil.refuse').origin, BackofficeOrigin.local);
    expect(events().where((e) => e.kind == 'ia.outil.execute'), isEmpty);
    expect(events().where((e) => e.kind == 'firmware.tx'), isEmpty);
    expect(repo.homeCalls, isEmpty);
    expect(c.read(backofficeStatsProvider).refus, 1);
  });

  test('une commande \$ interdite est classée garde-fou, pas panne', () async {
    c.read(aiAgentSettingsProvider.notifier)
        .setAutonomy(AiActionCategory.streaming, AiAutonomyLevel.autoExecute);
    ctl().debugUseBackend(backend([
      _call('send_gcode', const {'gcode': r'$RST=*'}),
    ]));
    await ctl().sendUserMessage('Peux-tu remettre la configuration de la fraiseuse à zéro ?');
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);

    final garde = one('garde.outil');
    expect(garde.source, BackofficeSource.garde);
    expect(garde.severity, BackofficeSeverity.warning);
    expect(garde.details['outil'], 'send_gcode');
    expect(repo.sentGCode, isEmpty, reason: 'la commande n\'est jamais partie');
    expect(events().where((e) => e.kind == 'firmware.tx'), isEmpty);
    expect(c.read(backofficeStatsProvider).gardes, 1);
  });

  test('un arrêt d\'urgence tapé dans le chat est critique et attribué', () async {
    await ctl().sendUserMessage('Arrêt d\'urgence !');
    await _until(() => events().any((e) => e.kind == 'ia.urgence'));
    final u = one('ia.urgence');
    expect(u.severity, BackofficeSeverity.critical);
    expect(u.details['transmis'], isTrue);
    expect(u.callId, isNotNull);
    expect(repo.emergencyStopCalls, 1);
  });

  test('une photo va au modèle d\'images (gemma) : tour tracé à son nom, sans outils', () async {
    final main = backend([]);
    final vision = _FakeBackend('gemma3n:latest', [
      const AiApiResponse(parts: [{'text': 'Une pièce bridée.'}], finishReason: 'STOP', totalTokens: 900),
    ]);
    ctl().debugUseBackend(main);
    ctl().debugUseVisionBackend(vision);

    await ctl().sendUserMessage('Que vois-tu sur cette photo ?',
        imageBytes: Uint8List.fromList([1, 2, 3]));
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);

    expect(one('ia.message').details['image_octets'], 3);
    final v = one('ia.vision.tour');
    expect(v.details['modele_images'], 'gemma3n:latest');
    final tour = one('ia.tour');
    expect(tour.details['modele'], 'gemma3n:latest');
    expect(tour.details['role'], 'images');
    expect(tour.details['tokens'], 900);
    expect(events().where((e) => e.kind == 'ia.vision.relais'), isEmpty,
        reason: 'une simple question ne passe pas la main au pilote');
    final stats = c.read(backofficeStatsProvider);
    expect(stats.toursImages, 1);
    expect(stats.toursParModele['gemma3n:latest'], 1);
  });

  test('photo + ordre : le relais gemma → pilote est tracé', () async {
    final main = backend([]);
    final vision = _FakeBackend('gemma3n:latest', [
      const AiApiResponse(parts: [{'text': 'Une pièce sur le plateau.'}], finishReason: 'STOP'),
    ]);
    ctl().debugUseBackend(main);
    ctl().debugUseVisionBackend(vision);

    await ctl().sendUserMessage('Regarde cette pièce et lance le scan',
        imageBytes: Uint8List.fromList([1, 2, 3]));
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);

    final relais = one('ia.vision.relais');
    expect(relais.details['modele_images'], 'gemma3n:latest');
    expect(relais.details['pilote'], main.model);
    final tours = events().where((e) => e.kind == 'ia.tour').toList();
    expect(tours.map((e) => e.details['role']), ['images', 'pilote']);
    expect(c.read(backofficeStatsProvider).relaisVision, 1);
  });

  test('photo sans modèle d\'images branché : signalé comme problème', () async {
    ctl().debugUseBackend(backend([]));
    await ctl().sendUserMessage('Et ça ?', imageBytes: Uint8List.fromList([1, 2, 3]));
    await _until(() => !c.read(aiAgentControllerProvider).isProcessing);
    final a = one('ia.vision.absente');
    expect(a.severity, BackofficeSeverity.warning);
    expect(c.read(backofficeStatsProvider).imagesSansModele, 1);
  });

  test('le lexique fermé est tracé comme tel', () async {
    await ctl().sendUserMessage('État de la machine', allowModel: false);
    final lex = events().where((e) => e.kind == 'ia.lexique').toList();
    expect(lex, hasLength(1));
    expect(lex.single.origin, BackofficeOrigin.lexique);
    expect('${lex.single.details['decision']}', startsWith('lexique:direct'));
    expect(one('ia.outil.execute').origin, BackofficeOrigin.lexique);
  });
}
