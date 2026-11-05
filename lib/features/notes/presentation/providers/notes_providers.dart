import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
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

/// Watched once from the app root — fires an instant local notification
/// when the OTHER owner adds a note while this device is running (never
/// for the owner's own notes, and never replays the backlog that already
/// existed when the app launched).
final noteCreationAlertProvider = Provider<void>((ref) {
  final sessionStart = DateTime.now();
  final notified = <String>{};
  ref.listen<AsyncValue<List<Note>>>(notesProvider, (previous, next) {
    final notes = next.valueOrNull;
    if (notes == null) return;
    final myId = AppSupabase.client.auth.currentUser?.id;
    final owners = ref.read(ownerProfilesProvider).valueOrNull ?? [];
    for (final n in notes) {
      if (!notified.add(n.id)) continue;
      if (!n.createdAt.isAfter(sessionStart)) continue;
      if (n.createdBy == null || n.createdBy == myId) continue;
      final creatorName = owners
          .where((o) => o.id == n.createdBy)
          .firstOrNull
          ?.name;
      NotificationService.instance.showInstant(
        id: ('new_note_${n.id}').hashCode & 0x7fffffff,
        title: '🗒️ ملاحظة جديدة',
        body: creatorName != null
            ? '$creatorName كتب ملاحظة: ${n.text}'
            : 'ملاحظة جديدة: ${n.text}',
      );
    }
  });
});
