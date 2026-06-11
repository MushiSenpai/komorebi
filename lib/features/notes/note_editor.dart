import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repos/note_repository.dart';
import '../../design/tokens.dart';
import '../today/widgets/task_editor.dart';
import 'providers.dart';

/// Markdown editor pane: title, toolbar, edit/preview toggle, autosave,
/// tappable [[wiki-links]] in preview, and a backlinks panel (SPEC §5.4).
class NoteEditorPane extends ConsumerStatefulWidget {
  const NoteEditorPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorPane> createState() => _NoteEditorPaneState();
}

class _NoteEditorPaneState extends ConsumerState<NoteEditorPane> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Timer? _debounce;
  Note? _note;
  var _preview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final note =
        await ref.read(noteRepositoryProvider).getNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _note = note;
      _title.text = note.title;
      _body.text = note.body;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flush();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush() {
    final note = _note;
    if (note == null) return;
    if (_title.text == note.title && _body.text == note.body) return;
    _note = note.copyWith(title: _title.text, body: _body.text);
    ref.read(noteRepositoryProvider).updateNote(
          note.id,
          NotesCompanion(
            title: Value(
                _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim()),
            body: Value(_body.text),
          ),
        );
  }

  void _wrapSelection(String prefix, [String? suffix]) {
    final sel = _body.selection;
    final text = _body.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final after = suffix ?? prefix;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, '$prefix$selected$after'),
      selection:
          TextSelection.collapsed(offset: end + prefix.length + after.length),
    );
    _scheduleSave();
  }

  void _insertAtLineStart(String marker) {
    final sel = _body.selection;
    final text = _body.text;
    final offset = sel.isValid ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    _body.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, marker),
      selection: TextSelection.collapsed(offset: offset + marker.length),
    );
    _scheduleSave();
  }

  Future<void> _insertWikiLink() async {
    final target = await _pickWikiTarget(context, ref);
    if (target == null) return;
    final sel = _body.selection;
    final offset = sel.isValid ? sel.start : _body.text.length;
    final link =
        target.kind == 'task' ? '[[task:${target.title}]]' : '[[${target.title}]]';
    _body.value = TextEditingValue(
      text: _body.text.replaceRange(offset, offset, link),
      selection: TextSelection.collapsed(offset: offset + link.length),
    );
    _scheduleSave();
  }

  /// Rewrites `[[X]]` to markdown links on a `wiki:` scheme so the preview
  /// renders them as tappable links.
  String _preprocess(String markdown) {
    return markdown.replaceAllMapped(
      NoteRepository.wikiLinkPattern,
      (m) => '[${m.group(1)}](wiki:${Uri.encodeComponent(m.group(1)!)})',
    );
  }

  Future<void> _openWikiTarget(String raw) async {
    final repo = ref.read(noteRepositoryProvider);
    final resolved = await repo.resolveTarget(raw);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nothing named "$raw" yet'),
        action: raw.toLowerCase().startsWith('task:')
            ? null
            : SnackBarAction(
                label: 'Create note',
                onPressed: () async {
                  final id = await repo.createNote(title: raw);
                  ref.read(selectedNoteIdProvider.notifier).set(id);
                },
              ),
      ));
      return;
    }
    if (resolved.kind == 'task') {
      await showTaskEditor(context, taskId: resolved.id);
    } else {
      _flush();
      ref.read(selectedNoteIdProvider.notifier).set(resolved.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    final note = _note;
    if (note == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final backlinks =
        ref.watch(backlinksProvider(('note', widget.noteId))).value ??
            const <Note>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                      hintText: 'Title', border: InputBorder.none),
                  onChanged: (_) => _scheduleSave(),
                ),
              ),
              IconButton(
                tooltip: note.pinned ? 'Unpin' : 'Pin',
                icon: Icon(note.pinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined),
                onPressed: () async {
                  await ref.read(noteRepositoryProvider).updateNote(
                      note.id, NotesCompanion(pinned: Value(!note.pinned)));
                  _note = note.copyWith(pinned: !note.pinned);
                  setState(() {});
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Note menu',
                onSelected: (action) async {
                  final repo = ref.read(noteRepositoryProvider);
                  switch (action) {
                    case 'delete':
                      await repo.deleteNote(note.id);
                      ref.read(selectedNoteIdProvider.notifier).set(null);
                    case 'unfile':
                      await repo.updateNote(note.id,
                          const NotesCompanion(folderId: Value(null)));
                    case String a when a.startsWith('folder:'):
                      await repo.updateNote(
                          note.id,
                          NotesCompanion(
                              folderId: Value(a.substring(7))));
                    case 'newfolder':
                      final name = await _promptText(context, 'New folder');
                      if (name != null && name.trim().isNotEmpty) {
                        final id = await repo.ensureFolder(name.trim());
                        await repo.updateNote(note.id,
                            NotesCompanion(folderId: Value(id)));
                      }
                  }
                },
                itemBuilder: (context) => [
                  for (final f in folders)
                    PopupMenuItem(
                        value: 'folder:${f.id}',
                        child: Text('Move to ${f.name}')),
                  const PopupMenuItem(
                      value: 'newfolder', child: Text('Move to new folder…')),
                  if (note.folderId != null)
                    const PopupMenuItem(
                        value: 'unfile', child: Text('Remove from folder')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete note')),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Bold',
                icon: const Icon(Icons.format_bold, size: 20),
                onPressed: _preview ? null : () => _wrapSelection('**'),
              ),
              IconButton(
                tooltip: 'Italic',
                icon: const Icon(Icons.format_italic, size: 20),
                onPressed: _preview ? null : () => _wrapSelection('*'),
              ),
              IconButton(
                tooltip: 'Heading',
                icon: const Icon(Icons.title, size: 20),
                onPressed: _preview ? null : () => _insertAtLineStart('## '),
              ),
              IconButton(
                tooltip: 'Bullet list',
                icon: const Icon(Icons.format_list_bulleted, size: 20),
                onPressed: _preview ? null : () => _insertAtLineStart('- '),
              ),
              IconButton(
                tooltip: 'Insert wiki-link',
                icon: const Icon(Icons.add_link, size: 20),
                onPressed: _preview ? null : _insertWikiLink,
              ),
              const Spacer(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Edit')),
                  ButtonSegment(value: true, label: Text('Preview')),
                ],
                selected: {_preview},
                onSelectionChanged: (s) {
                  _flush();
                  setState(() => _preview = s.first);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _preview
              ? Markdown(
                  data: _preprocess(_body.text),
                  padding: const EdgeInsets.all(16),
                  onTapLink: (text, href, title) {
                    if (href != null && href.startsWith('wiki:')) {
                      _openWikiTarget(
                          Uri.decodeComponent(href.substring(5)));
                    }
                  },
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.6),
                    decoration: const InputDecoration(
                      hintText:
                          'Write in markdown… link with [[Note title]] or '
                          '[[task:Task title]]',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _scheduleSave(),
                  ),
                ),
        ),
        if (backlinks.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Linked from',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: tokens.inkSoft)),
                for (final source in backlinks)
                  ActionChip(
                    label: Text(source.title),
                    avatar: const Icon(Icons.north_west, size: 14),
                    onPressed: () {
                      _flush();
                      ref
                          .read(selectedNoteIdProvider.notifier)
                          .set(source.id);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Future<WikiTarget?> _pickWikiTarget(BuildContext context, WidgetRef ref) {
  final notes = ref.read(notesListProvider).value ?? const <Note>[];
  return showDialog<WikiTarget>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Link to…'),
      children: [
        for (final note in notes.take(12))
          SimpleDialogOption(
            child: Row(children: [
              const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(note.title)),
            ]),
            onPressed: () => Navigator.of(context)
                .pop((kind: 'note', id: note.id, title: note.title)),
          ),
        const SimpleDialogOption(
          child: Row(children: [
            Icon(Icons.check_circle_outline, size: 16),
            SizedBox(width: 8),
            Expanded(
                child: Text('Tip: link a task by typing '
                    '[[task:Task title]] directly')),
          ]),
        ),
      ],
    ),
  );
}

Future<String?> _promptText(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK')),
      ],
    ),
  );
}
