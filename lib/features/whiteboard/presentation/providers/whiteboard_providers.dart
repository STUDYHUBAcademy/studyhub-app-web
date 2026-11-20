import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/whiteboard_remote_datasource.dart';
import '../../data/repositories/whiteboard_repository_impl.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_question.dart';
import '../../domain/entities/wb_submission.dart';
import '../../domain/repositories/whiteboard_repository.dart';

final whiteboardRemoteDatasourceProvider = Provider<WhiteboardRemoteDatasource>(
  (ref) {
    return WhiteboardRemoteDatasource(AppSupabase.client);
  },
);

final whiteboardRepositoryProvider = Provider<WhiteboardRepository>((ref) {
  return WhiteboardRepositoryImpl(
    ref.watch(whiteboardRemoteDatasourceProvider),
    AppSupabase.client,
  );
});

final wbQuestionsProvider = StreamProvider<List<WbQuestion>>((ref) {
  return ref.watch(whiteboardRepositoryProvider).watchQuestions();
});

final wbAssignmentsProvider = StreamProvider<List<WbAssignment>>((ref) {
  return ref.watch(whiteboardRepositoryProvider).watchAssignments();
});

final wbSubmissionsProvider = StreamProvider.family<List<WbSubmission>, String>(
  (ref, assignmentId) {
    return ref
        .watch(whiteboardRepositoryProvider)
        .watchSubmissions(assignmentId);
  },
);
