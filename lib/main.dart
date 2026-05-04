import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_scaffold.dart';

void main() {
  runApp(const ProviderScope(child: ForgeronApp()));
}

class ForgeronApp extends StatelessWidget {
  const ForgeronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forgeron — CNC 5 Axes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}
