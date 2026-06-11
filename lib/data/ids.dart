import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Time-ordered UUIDv7 — sortable by creation time and safe to merge across
/// devices, which is what makes the schema sync-ready (SPEC §2).
String newId() => _uuid.v7();
