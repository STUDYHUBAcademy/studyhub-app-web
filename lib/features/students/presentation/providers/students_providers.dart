import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/students_remote_datasource.dart';
import '../../data/repositories/students_repository_impl.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/students_repository.dart';

final studentsRemoteDatasourceProvider = Provider<StudentsRemoteDatasource>((
  ref,
) {
  return StudentsRemoteDatasource(AppSupabase.client);
});

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  return StudentsRepositoryImpl(ref.watch(studentsRemoteDatasourceProvider));
});

final studentsProvider = StreamProvider<List<Student>>((ref) {
  return ref.watch(studentsRepositoryProvider).watchStudents();
});
