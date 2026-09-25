import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/notes_remote_datasource.dart';
import '../../data/repositories/notes_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';

final notesRemoteDatasourceProvider = Provider<NotesRemoteDatasource>((ref) {
  return NotesRemoteDatasource(AppSupabase.client);
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(ref.watch(notesRemoteDatasourceProvider));
});

final notesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotes();
});
