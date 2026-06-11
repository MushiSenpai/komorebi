import 'dart:io';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';

/// A resolved `[[wiki-link]]` target.
typedef WikiTarget = ({String kind, String id, String title});

/// Data access for the notes module (SPEC §5.4): markdown notes, folders,
/// [[wiki-links]] materialized into NoteLinks, backlinks, search, export.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;

  /// Matches `[[target]]`; `task:` prefix links to a task by title.
  static final wikiLinkPattern = RegExp(r'\[\[([^\[\]]+)\]\]');

  /// Matches a checklist line: `- [ ] text` or `- [x] text`.
  static final checklistPattern = RegExp(r'^(\s*)- \[( |x|X)\] (.*)$');

  /// Flips the checkbox on [lineIndex] of [body]; returns body unchanged if
  /// that line is not a checklist item.
  static String toggleChecklistLine(String body, int lineIndex) {
    final lines = body.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return body;
    final match = checklistPattern.firstMatch(lines[lineIndex]);
    if (match == null) return body;
    final checked = match.group(2)!.toLowerCase() == 'x';
    lines[lineIndex] =
        '${match.group(1)}- [${checked ? ' ' : 'x'}] ${match.group(3)}';
    return lines.join('\n');
  }

  // ---- Notes ---------------------------------------------------------------

  /// Pinned first, then most recently updated. [query] filters on title and
  /// body (case-insensitive substring; FTS5 is on the roadmap for big vaults).
  Stream<List<Note>> watchNotes({String? folderId, String query = ''}) {
    final select = _db.select(_db.notes)
      ..where((n) => n.deletedAt.isNull())
      ..orderBy([
        (n) => OrderingTerm.desc(n.pinned),
        (n) => OrderingTerm.desc(n.updatedAt),
      ]);
    if (folderId != null) {
      select.where((n) => n.folderId.equals(folderId));
    }
    if (query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      select.where((n) => n.title.like(like) | n.body.like(like));
    }
    return select.watch();
  }

  Future<Note> getNote(String id) =>
      (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingle();

  Future<String> createNote({
    String title = 'Untitled',
    String body = '',
    String? folderId,
  }) async {
    final id = newId();
    await _db.into(_db.notes).insert(NotesCompanion.insert(
          id: id,
          title: title,
          body: Value(body),
          folderId: Value(folderId),
        ));
    await _syncLinks(id, body);
    return id;
  }

  /// Saves note changes and re-extracts wiki links when the body changed.
  Future<void> updateNote(String id, NotesCompanion changes) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(DateTime.now())));
    if (changes.body.present) {
      await _syncLinks(id, changes.body.value);
    }
  }

  Future<void> deleteNote(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
          NotesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.noteLinks)
            ..where((l) => l.sourceNoteId.equals(id)))
          .write(NoteLinksCompanion(
              deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  // ---- Folders ---------------------------------------------------------------

  Stream<List<Folder>> watchFolders() {
    return (_db.select(_db.folders)
          ..where((f) => f.deletedAt.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .watch();
  }

  Future<String> ensureFolder(String name) async {
    final existing = await (_db.select(_db.folders)
          ..where((f) =>
              f.deletedAt.isNull() & f.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await _db
        .into(_db.folders)
        .insert(FoldersCompanion.insert(id: id, name: name));
    return id;
  }

  // ---- Wiki links & backlinks -------------------------------------------------

  /// Resolves a raw wiki target ("Garden ideas" or "task:Water the plants")
  /// to an existing note/task, or null when nothing matches.
  Future<WikiTarget?> resolveTarget(String raw) async {
    final target = raw.trim();
    if (target.toLowerCase().startsWith('task:')) {
      final title = target.substring(5).trim();
      final task = await (_db.select(_db.tasks)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.title.lower().equals(title.toLowerCase()))
            ..limit(1))
          .getSingleOrNull();
      return task == null
          ? null
          : (kind: 'task', id: task.id, title: task.title);
    }
    final note = await (_db.select(_db.notes)
          ..where((n) =>
              n.deletedAt.isNull() &
              n.title.lower().equals(target.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    return note == null
        ? null
        : (kind: 'note', id: note.id, title: note.title);
  }

  /// Re-materializes NoteLinks rows for [sourceNoteId] from its body.
  /// Unresolved targets are skipped (re-resolved on the next save).
  Future<void> _syncLinks(String sourceNoteId, String body) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.noteLinks)
            ..where((l) =>
                l.deletedAt.isNull() &
                l.sourceNoteId.equals(sourceNoteId)))
          .write(NoteLinksCompanion(
              deletedAt: Value(now), updatedAt: Value(now)));

      final seen = <String>{};
      for (final match in wikiLinkPattern.allMatches(body)) {
        final resolved = await resolveTarget(match.group(1)!);
        if (resolved == null || resolved.id == sourceNoteId) continue;
        if (!seen.add('${resolved.kind}/${resolved.id}')) continue;
        await _db.into(_db.noteLinks).insert(NoteLinksCompanion.insert(
              id: newId(),
              sourceNoteId: sourceNoteId,
              targetKind: resolved.kind,
              targetId: resolved.id,
            ));
      }
    });
  }

  /// Notes whose bodies link to the given target ("referenced in…").
  Stream<List<Note>> watchBacklinks(String targetKind, String targetId) {
    final query = _db.select(_db.noteLinks).join([
      innerJoin(_db.notes, _db.notes.id.equalsExp(_db.noteLinks.sourceNoteId)),
    ])
      ..where(_db.noteLinks.deletedAt.isNull() &
          _db.notes.deletedAt.isNull() &
          _db.noteLinks.targetKind.equals(targetKind) &
          _db.noteLinks.targetId.equals(targetId));
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(_db.notes)).toList());
  }

  // ---- Onboarding ---------------------------------------------------------

  static const _welcomeFlag = 'notes_welcome_created';

  /// The pinned starter guide (SPEC §5.4 onboarding). Created once, ever —
  /// deleting it does not bring it back.
  Future<void> ensureWelcomeNote() async {
    if (await _db.getSetting(_welcomeFlag) != null) return;
    await _db.setSetting(_welcomeFlag, '1');
    final id = await createNote(
      title: 'How to write notes',
      body: welcomeBody,
    );
    await updateNote(id, const NotesCompanion(pinned: Value(true)));
  }

  static const welcomeBody = '''
Welcome! Notes are written in *markdown* — plain text with a few simple
marks. **Switch between Edit and Preview** (top right) while reading this
note and the syntax will explain itself. This note is yours: change it,
or delete it once you feel at home.

## Headings

Start a line with # for a big heading, ## for a smaller one (this section
is a ##), ### for smaller still.

## Emphasis

Wrap words in one star for *italic*, two for **bold**. The toolbar buttons
above do this for you.

## Lists

Start lines with a dash for bullets:

- like this
- and this

Number lines for an ordered list:

1. first
2. second

## Things to do

Type `- [ ]` to make a checkbox. In **Preview**, tap the box to tick it —
done items get crossed out:

- [ ] water the plants
- [ ] morning run
- [x] this one is already done

## Linking your thinking

Wrap a note title in double square brackets to link it, like
[[How to write notes]] (that one points right back here). Link a task with
[[task:Task title]]. In Preview, links are tappable, and linked notes and
tasks show a "Linked from" / "Referenced in" trail back to this note.

## One more thing

Everything saves by itself as you type. Happy writing 🌿
''';

  // ---- Export -----------------------------------------------------------------

  /// Writes every live note as a markdown file; returns the file count.
  Future<int> exportMarkdown(String directory) async {
    final dir = Directory(directory)..createSync(recursive: true);
    final notes = await (_db.select(_db.notes)
          ..where((n) => n.deletedAt.isNull()))
        .get();
    for (final note in notes) {
      final safe = note.title
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
          .trim();
      final name = safe.isEmpty ? note.id : safe;
      File('${dir.path}/$name.md')
          .writeAsStringSync('# ${note.title}\n\n${note.body}\n');
    }
    return notes.length;
  }
}
