import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/universities_remote_datasource.dart';
import '../../data/repositories/universities_repository_impl.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/university.dart';
import '../../domain/repositories/universities_repository.dart';

final universitiesRemoteDatasourceProvider =
    Provider<UniversitiesRemoteDatasource>((ref) {
      return UniversitiesRemoteDatasource(AppSupabase.client);
    });

final universitiesRepositoryProvider = Provider<UniversitiesRepository>((ref) {
  return UniversitiesRepositoryImpl(
    ref.watch(universitiesRemoteDatasourceProvider),
  );
});

final universitiesProvider = StreamProvider<List<University>>((ref) {
  return ref.watch(universitiesRepositoryProvider).watchUniversities();
});

final termsProvider = StreamProvider<List<Term>>((ref) {
  return ref.watch(universitiesRepositoryProvider).watchTerms();
});
