import '../entities/note.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchNotes();
  Future<void> addNote({required String text, String? linkedCourseId});
  Future<void> updateNote({required String id, required String text});
  Future<void> deleteNote(String id);
}
