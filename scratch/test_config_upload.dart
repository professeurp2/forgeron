import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

// Script pour uploader config.yaml vers FluidNC via WebSocket
// FluidNC 3.7+ supporte l'écriture de fichiers via $LocalFS/

void main() async {
  final wsUrl = 'ws://192.168.137.200:80/';
  
  print('[INFO] Connexion à $wsUrl...');
  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
  
  try {
    await channel.ready.timeout(const Duration(seconds: 5));
    print('[OK] Connecté !');
  } catch(e) {
    print('[ERREUR] Connexion échouée: $e');
    return;
  }
  
  final sub = channel.stream.listen((msg) {
    final str = msg is List<int> ? String.fromCharCodes(msg).trim() : msg.toString().trim();
    if (str.isNotEmpty) print('[RX] $str');
  });
  
  Future<void> send(String cmd) async {
    print('[TX] $cmd');
    channel.sink.add('$cmd\n');
    await Future.delayed(const Duration(milliseconds: 800));
  }
  
  // 1. Déverroiller l'alarme d'abord
  await send('\x18'); // Soft reset
  await Future.delayed(const Duration(seconds: 2));
  await send('\$X'); // Unlock alarm
  await Future.delayed(const Duration(milliseconds: 500));
  
  // 2. Lister les fichiers actuels
  await send('\$LocalFS/List');
  await Future.delayed(const Duration(milliseconds: 1000));
  
  // 3. Lire la config actuelle pour voir le format
  await send('\$Config/Dump');
  await Future.delayed(const Duration(milliseconds: 2000));
  
  // 4. Verifier les axes actifs
  await send('?');
  await Future.delayed(const Duration(milliseconds: 500));
  
  print('\n[INFO] Recherche du bon endpoint pour upload...');
  print('[INFO] La config 5-axes est dans: scratch/config_5axes.yaml');
  print('[INFO] Utiliser l\'interface web FluidNC: http://192.168.137.200');
  print('[INFO] Ou le terminal FluidNC (FluidTerm) pour uploader le fichier');
  
  await sub.cancel();
  await channel.sink.close();
}
