import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../design/theme.dart';
import 'router.dart';

class KomorebiApp extends ConsumerWidget {
  const KomorebiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Komorebi',
      debugShowCheckedModeBanner: false,
      theme: meadowTheme(),
      darkTheme: twilightTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
