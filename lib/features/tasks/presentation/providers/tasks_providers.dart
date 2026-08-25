import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/tasks_remote_datasource.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';

final tasksRemoteDatasourceProvider = Provider<TasksRemoteDatasource>((ref) {
  return TasksRemoteDatasource(AppSupabase.client);
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(ref.watch(tasksRemoteDatasourceProvider));
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchTasks();
});
