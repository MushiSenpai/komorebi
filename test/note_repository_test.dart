import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/note_repository.dart';
import 'package:komorebi/data/repos/task_repository.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late TaskRepository tasks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    tasks = TaskRepository(db);
  });
  tearDown(() => db.close());

  group('notes & folders', () {
    test('pinned notes float, search filters title and body', () async {
      await repo.createNote(title: 'Garden ideas', body: 'plant tomatoes');
      final pinnedId =
          await repo.createNote(title: 'Inbox', body: 'fleeting thought');
      await repo.updateNote(pinnedId, const NotesCompanion(pinned: Value(true)));

      var notes = await repo.watchNotes().first;
      expect(notes.first.title, 'Inbox', reason: 'pinned first');

      notes = await repo.watchNotes(query: 'tomato').first;
      expect(notes.single.title, 'Garden ideas');
    });

    test('folders are idempotent and filter the list', () async {
      final folder = await repo.ensureFolder('Recipes');
      expect(await repo.ensureFolder('recipes'), folder);
      await repo.createNote(title: 'Miso soup', folderId: folder);
      await repo.createNote(title: 'Unfiled');

      final inFolder = await repo.watchNotes(folderId: folder).first;
      expect(inFolder.single.title, 'Miso soup');
    });
  });

  group('wiki links', () {
    test('note links resolve by title and power backlinks', () async {
      final garden =
          await repo.createNote(title: 'Garden ideas', body: 'soil, light');
      final journal = await repo.createNote(
          title: 'Journal', body: 'Thinking about [[Garden ideas]] today.');

      final backlinks = await repo.watchBacklinks('note', garden).first;
      expect(backlinks.single.id, journal);
    });

    test('task links use the task: prefix', () async {
      final taskId = await tasks.createTask(title: 'Water the plants');
      final note = await repo.createNote(
          title: 'Watering log', body: 'See [[task:Water the plants]].');

      final backlinks = await repo.watchBacklinks('task', taskId).first;
      expect(backlinks.single.id, note);

      final resolved = await repo.resolveTarget('task:water the plants');
      expect((resolved!.kind, resolved.id), ('task', taskId));
    });

    test('editing the body re-syncs links; unresolved links are skipped',
        () async {
      final garden = await repo.createNote(title: 'Garden ideas');
      final note = await repo.createNote(
          title: 'Journal', body: '[[Garden ideas]] and [[No such note]]');
      expect((await repo.watchBacklinks('note', garden).first), hasLength(1));

      await repo.updateNote(
          note, const NotesCompanion(body: Value('rewritten, no links')));
      expect(await repo.watchBacklinks('note', garden).first, isEmpty);
    });

    test('self-links and duplicates collapse', () async {
      final garden = await repo.createNote(title: 'Garden ideas');
      await repo.updateNote(
          garden,
          const NotesCompanion(
              body: Value('[[Garden ideas]] [[Garden ideas]]')));
      expect(await repo.watchBacklinks('note', garden).first, isEmpty);
    });

    test('deleting a note removes its outgoing links', () async {
      final garden = await repo.createNote(title: 'Garden ideas');
      final journal =
          await repo.createNote(title: 'Journal', body: '[[Garden ideas]]');
      await repo.deleteNote(journal);
      expect(await repo.watchBacklinks('note', garden).first, isEmpty);
    });
  });

  group('checklists & onboarding', () {
    test('toggleChecklistLine flips only checklist lines', () {
      const body = 'intro\n- [ ] water\n- [x] Run\nplain - [ ] not at start';
      expect(NoteRepository.toggleChecklistLine(body, 1),
          'intro\n- [x] water\n- [x] Run\nplain - [ ] not at start');
      expect(NoteRepository.toggleChecklistLine(body, 2),
          'intro\n- [ ] water\n- [ ] Run\nplain - [ ] not at start');
      expect(NoteRepository.toggleChecklistLine(body, 0), body);
      expect(NoteRepository.toggleChecklistLine(body, 3), body,
          reason: 'mid-line checkbox text is not a checklist item');
      expect(NoteRepository.toggleChecklistLine(body, 99), body);
    });

    test('welcome note is created once, ever', () async {
      await repo.ensureWelcomeNote();
      final first = await repo.watchNotes().first;
      expect(first.single.title, 'How to write notes');
      expect(first.single.pinned, isTrue);

      await repo.deleteNote(first.single.id);
      await repo.ensureWelcomeNote();
      expect(await repo.watchNotes().first, isEmpty,
          reason: 'deleting the guide must not resurrect it');
    });
  });

  test('export writes one markdown file per note', () async {
    await repo.createNote(title: 'Garden ideas', body: 'tomatoes');
    await repo.createNote(title: 'Trip: plan?', body: 'pack light');
    final dir =
        Directory.systemTemp.createTempSync('komorebi-export').path;
    addTearDown(() => Directory(dir).deleteSync(recursive: true));

    final count = await repo.exportMarkdown(dir);
    expect(count, 2);
    expect(File('$dir/Garden ideas.md').readAsStringSync(),
        contains('tomatoes'));
    expect(File('$dir/Trip_ plan_.md').existsSync(), isTrue,
        reason: 'unsafe filename characters replaced');
  });
}
