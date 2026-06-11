import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../design/tokens.dart';
import 'note_editor.dart';
import 'providers.dart';

/// The notes module (SPEC §5.4): searchable list with folders and pins on
/// the left, markdown editor with preview and backlinks on the right
/// (stacked on narrow layouts).
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(welcomeNoteProvider); // seed the guide on first visit
    final selected = ref.watch(selectedNoteIdProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              const SizedBox(width: 340, child: _NotesListPane()),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const _NoNoteSelected()
                    : NoteEditorPane(
                        key: ValueKey(selected), noteId: selected),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: selected == null
            ? const _NotesListPane()
            : Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back to notes',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () =>
                          ref.read(selectedNoteIdProvider.notifier).set(null),
                    ),
                  ),
                  Expanded(
                    child: NoteEditorPane(
                        key: ValueKey(selected), noteId: selected),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotesListPane extends ConsumerWidget {
  const _NotesListPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final notes = ref.watch(notesListProvider).value ?? const <Note>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folderFilter = ref.watch(noteFolderFilterProvider);
    final repo = ref.read(noteRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Notes',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              PopupMenuButton<String>(
                tooltip: 'Notes menu',
                onSelected: (action) async {
                  if (action == 'export') {
                    final stamp =
                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final dir =
                        '${Platform.environment['HOME']}/Documents/komorebi-notes-$stamp';
                    final count = await repo.exportMarkdown(dir);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Exported $count notes to $dir')));
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'export',
                      child: Text('Export all as markdown')),
                ],
              ),
              IconButton(
                tooltip: 'New note',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final id = await repo.createNote(
                      folderId: ref.read(noteFolderFilterProvider));
                  ref.read(selectedNoteIdProvider.notifier).set(id);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search notes…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (q) => ref.read(noteSearchProvider.notifier).set(q),
          ),
        ),
        if (folders.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: folderFilter == null,
                    onSelected: (_) =>
                        ref.read(noteFolderFilterProvider.notifier).set(null),
                  ),
                ),
                for (final folder in folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(folder.name),
                      selected: folderFilter == folder.id,
                      onSelected: (sel) => ref
                          .read(noteFolderFilterProvider.notifier)
                          .set(sel ? folder.id : null),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'A library in the forest, still empty.\n'
                      'Tap + to write the first page.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.inkSoft),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final note in notes) _NoteTile(note: note),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final selected = ref.watch(selectedNoteIdProvider) == note.id;
    final snippet = note.body
        .replaceAll(RegExp(r'[#*\[\]`>-]'), '')
        .trim()
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');

    return Card(
      color: selected ? tokens.accentSoft : null,
      child: ListTile(
        dense: true,
        leading: note.pinned
            ? Icon(Icons.push_pin, size: 16, color: tokens.accent)
            : const Icon(Icons.description_outlined, size: 16),
        title: Text(note.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: snippet.isEmpty
            ? null
            : Text(snippet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.inkSoft)),
        trailing: Text(
          DateFormat.MMMd().format(note.updatedAt),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: tokens.inkSoft),
        ),
        onTap: () =>
            ref.read(selectedNoteIdProvider.notifier).set(note.id),
      ),
    );
  }
}

class _NoNoteSelected extends StatelessWidget {
  const _NoNoteSelected();

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 32, color: tokens.ink),
          ),
          const SizedBox(height: 16),
          Text('Pick a note, or write a new one',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Link your thinking with [[wiki-links]] — notes to notes,\n'
            'notes to tasks. Backlinks find their way home.',
            textAlign: TextAlign.center,
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
