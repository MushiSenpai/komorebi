import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Gentle illustrated empty state used by module stubs until each phase
/// lands its real screen. Empty states get a tiny scene, not gray text
/// (SPEC §3).
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.phase,
  });

  final String title;
  final String message;
  final IconData icon;

  /// Which build-plan phase delivers this module (SPEC §7).
  final String? phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Icon(icon, size: 44, color: tokens.ink),
                ),
                const SizedBox(height: 24),
                Text(title, style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(color: tokens.inkSoft),
                  textAlign: TextAlign.center,
                ),
                if (phase != null) ...[
                  const SizedBox(height: 20),
                  Chip(label: Text('Coming in $phase')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
