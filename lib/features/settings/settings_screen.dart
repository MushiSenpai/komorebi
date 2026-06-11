import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';

import '../../data/providers.dart';
import '../../design/tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final tokens = context.komorebi;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Meadow is a Totoro daytime theme; Twilight is a Spirited Away '
            'evening theme.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.inkSoft),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Meadow'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Twilight'),
                icon: Icon(Icons.nightlight_outlined),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setMode(selection.first);
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('Data', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Your data is one JSON file away — back it up anywhere, '
            'restore it anywhere. Importing merges by id.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.inkSoft),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Export everything'),
                onPressed: () async {
                  final dir =
                      '${Platform.environment['HOME']}/Documents';
                  final file = await BackupService(
                          ref.read(databaseProvider))
                      .exportTo(dir);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Saved ${file.path}')));
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Import backup…'),
                onPressed: () => _importBackup(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Komorebi · 木漏れ日 — sunlight filtering through leaves.\n'
            'Local-first. Your data never leaves this device unless you '
            'opt into Arena leaderboards.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
      text: '${Platform.environment['HOME']}/Documents/');
  final path = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import backup'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration:
            const InputDecoration(labelText: 'Path to backup .json'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Import')),
      ],
    ),
  );
  if (path == null || path.trim().isEmpty) return;
  try {
    final (tables, rows) =
        await BackupService(ref.read(databaseProvider)).importFrom(path.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $rows rows across $tables tables')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}
