import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/doc_search.dart';
import '../../core/utils/fingerprint.dart';
import '../../core/utils/grbl_alarm_catalog.dart';

/// Emplacement des fiches dans les ressources de l'application.
const kDocsAsset = 'assets/docs/fiches.json';

/// Le corpus et son index, avec de quoi dire QUELLE version a répondu.
class DocCorpus {
  DocCorpus(this.index, {required this.version, required this.fingerprint});

  final DocIndex index;
  final String version;
  final String fingerprint;
  int get size => index.chunks.length;
}

/// Une fiche par code d'alarme, générée depuis le catalogue de l'application :
/// une seule source de vérité, jamais deux textes à tenir d'accord.
List<DocChunk> alarmChunks() {
  final out = <DocChunk>[];
  for (var code = 0; code <= 40; code++) {
    if (!GrblAlarmCatalog.isKnown(code)) continue;
    final a = GrblAlarmCatalog.lookup(code)!;
    out.add(DocChunk(
      id: 'alarme-$code',
      title: 'Alarme $code : ${a.title}',
      keywords: ['alarme', 'alarm', 'alarm:$code', 'code', '$code'],
      text: 'Cause : ${a.cause} Conduite à tenir : ${a.action}'
          '${a.positionLost ? ' La position machine n\'est plus fiable : refaire la prise d\'origine avant tout mouvement programmé.' : ''}'
          '${a.unlockable ? ' Peut être levée avec « \$X ».' : ''}',
      source: 'catalogue d\'alarmes FluidNC de l\'application (Alarm.h)',
    ));
  }
  return out;
}

/// Construit le corpus depuis le TEXTE du fichier de fiches. Un fichier illisible
/// ne laisse que les fiches d'alarme : la recherche reste utile, jamais
/// d'exception vers l'assistant.
DocCorpus buildCorpus(String source) {
  var chunks = <DocChunk>[...alarmChunks()];
  var version = '0';
  var print = fingerprint('');
  try {
    final json = (jsonDecode(source) as Map).cast<String, dynamic>();
    version = '${json['version'] ?? '0'}';
    print = fingerprint(jsonEncode(json));
    final ids = <String>{for (final c in chunks) c.id};
    for (final raw in (json['fiches'] as List)) {
      final c = DocChunk.fromJson((raw as Map).cast<String, dynamic>());
      if (c.id.isEmpty || c.text.trim().isEmpty || !ids.add(c.id)) continue;
      chunks.add(c);
    }
  } catch (e) {
    debugPrint('Fiches indisponibles, alarmes seules : $e');
  }
  return DocCorpus(DocIndex(chunks), version: version, fingerprint: print);
}

final docsSourceProvider = Provider<Future<String> Function()>(
    (ref) => () => rootBundle.loadString(kDocsAsset));

/// Le corpus indexé, une seule fois par exécution.
final docCorpusProvider = FutureProvider<DocCorpus>((ref) async {
  String source;
  try {
    source = await ref.read(docsSourceProvider)();
  } catch (_) {
    source = '{}';
  }
  return buildCorpus(source);
});
