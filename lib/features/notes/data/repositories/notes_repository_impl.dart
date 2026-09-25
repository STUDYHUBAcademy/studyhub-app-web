import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_remote_datasource.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._remote);

  final NotesRemoteDatasource _remote;

  @override
  Stream<List<Note>> watchNotes() {
    return _remote.watchNotes().map((rows) => rows.map(Note.fromJson).toList());
  }

  @override
  Future<void> addNote({required String text, String? linkedCourseId}) {
    return _remote.addNote(text: text, linkedCourseId: linkedCourseId);
  }

  @override
  Future<void> updateNote({required String id, required String text}) {
    return _remote.updateNote(id: id, text: text);
  }

  @override
  Future<void> deleteNote(String id) => _remote.deleteNote(id);
}
