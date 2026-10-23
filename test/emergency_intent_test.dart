import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/emergency_intent.dart';

/// Arrêter à tort coûte une pièce ; ne pas arrêter coûte plus. Mais une
/// reconnaissance trop large rendrait l'assistant inutilisable (« pourquoi
/// l'arrêt d'urgence… ? » ne doit pas arrêter la machine). Ces tests tiennent
/// les deux bouts.
void main() {
  group('ordres reconnus', () {
    const orders = [
      // français
      'Arrêt d\'urgence',
      'ARRÊT D\'URGENCE !!!',
      'arret urgence',
      'Arrête tout, c\'est urgent !',
      'Arrête tout',
      'arrête tout de suite',
      'Stop',
      'STOP !',
      'stop tout',
      'Stoppe tout',
      'Stoppe la machine',
      'Arrête la machine',
      'Vite, arrête tout',
      'Urgence !',
      'URGENCE',
      'Au secours',
      'stop, vite !',
      'Arrête !',
      // anglais
      'Stop everything now!',
      'stop right now',
      'Emergency stop',
      'emergency stop now!',
      'E-stop',
      'estop',
      'Halt',
      'halt everything',
      'Please stop',
      'kill it',
      // swahili, amharique — indicatif
      'Simamisha kila kitu sasa hivi!',
      'simamisha',
      'ሁሉንም አቁም!',
      'አቁም',
    ];
    for (final o in orders) {
      test('« $o »', () => expect(isEmergencyStopRequest(o), isTrue));
    }
  });

  group('jamais déclenché par erreur', () {
    const notOrders = [
      // questions
      'Pourquoi l\'arrêt d\'urgence ne marche pas ?',
      'Comment fonctionne l\'arrêt d\'urgence ?',
      'Est-ce que tu peux arrêter tout ?',
      'Why does the emergency stop not work?',
      // le mot est dans une phrase
      'Comment fonctionne l\'arrêt d\'urgence',
      'Je veux comprendre l\'arrêt d\'urgence de cette machine',
      'Explique-moi ce que fait stop dans un programme',
      'Il y a un arrêt d\'urgence sur la carte',
      // d'autres arrêts, pas l'urgence
      'Arrête le programme',
      'Arrête la broche',
      'Stop le programme à la ligne 40',
      'Mets le programme en pause',
      'Stop la broche',
      'Ne t\'arrête pas',
      'Arrête de parler',
      'Stop, je me suis trompé de fichier',
      'Éteins la broche',
      'stop the spindle',
      'Stop the program at line 40',
      // sans rapport
      '',
      '   ',
      'Donne-moi l\'état de la machine.',
      'Avance X de 5 mm.',
      'Urgence ou pas, je veux voir la position',
      // trop long même si le mot y figure
      'stop stop stop stop stop stop stop',
    ];
    for (final n in notOrders) {
      test('« $n »', () => expect(isEmergencyStopRequest(n), isFalse));
    }
  });

  group('normalisation', () {
    test('accents, casse, ponctuation et apostrophes', () {
      expect(normalizeForIntent('  ARRÊT   D\'URGENCE !!  '), 'arret d urgence');
      expect(normalizeForIntent('Œuvre à côté'), 'oeuvre a cote');
      expect(normalizeForIntent('e-stop'), 'e stop');
    });

    test('les lettres non latines sont conservées', () {
      expect(normalizeForIntent('ሁሉንም አቁም!'), 'ሁሉንም አቁም');
    });
  });
}
