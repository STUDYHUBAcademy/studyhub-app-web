import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/tutors_remote_datasource.dart';
import '../../data/repositories/tutors_repository_impl.dart';
import '../../domain/entities/tutor.dart';
import '../../domain/entities/tutor_application.dart';
import '../../domain/entities/tutor_finance_summary.dart';
import '../../domain/entities/tutor_status_period.dart';
import '../../domain/repositories/tutors_repository.dart';

final tutorsRemoteDatasourceProvider = Provider<TutorsRemoteDatasource>((ref) {
  return TutorsRemoteDatasource(AppSupabase.client);
});

final tutorsRepositoryProvider = Provider<TutorsRepository>((ref) {
  return TutorsRepositoryImpl(ref.watch(tutorsRemoteDatasourceProvider));
});

final applicationsProvider = StreamProvider<List<TutorApplication>>((ref) {
  return ref.watch(tutorsRepositoryProvider).watchApplications();
});

final tutorsProvider = StreamProvider<List<Tutor>>((ref) {
  return ref.watch(tutorsRepositoryProvider).watchTutors();
});

final tutorStatusHistoryProvider =
    FutureProvider.family<List<TutorStatusPeriod>, String>((ref, tutorId) {
      return ref.watch(tutorsRepositoryProvider).getStatusHistory(tutorId);
    });

final tutorFinanceSummaryProvider =
    FutureProvider.family<TutorFinanceSummary, String>((ref, tutorId) {
      return ref.watch(tutorsRepositoryProvider).getFinanceSummary(tutorId);
    });
