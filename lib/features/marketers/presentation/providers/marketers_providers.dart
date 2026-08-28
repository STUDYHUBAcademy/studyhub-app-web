import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/marketers_remote_datasource.dart';
import '../../data/repositories/marketers_repository_impl.dart';
import '../../domain/entities/marketer.dart';
import '../../domain/repositories/marketers_repository.dart';

final marketersRemoteDatasourceProvider = Provider<MarketersRemoteDatasource>((
  ref,
) {
  return MarketersRemoteDatasource(AppSupabase.client);
});

final marketersRepositoryProvider = Provider<MarketersRepository>((ref) {
  return MarketersRepositoryImpl(ref.watch(marketersRemoteDatasourceProvider));
});

final marketersProvider = StreamProvider<List<Marketer>>((ref) {
  return ref.watch(marketersRepositoryProvider).watchMarketers();
});
