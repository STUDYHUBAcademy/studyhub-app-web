import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../datasources/tasks_remote_datasource.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl(this._remote);

  final TasksRemoteDatasource _remote;

  @override
  Stream<List<Task>> watchTasks() {
    return _remote.watchTasks().map((rows) => rows.map(Task.fromJson).toList());
  }

  @override
  Future<void> addTask({
    required String title,
    String? body,
    DateTime? dueDate,
    String? linkedCourseId,
  }) {
    return _remote.addTask(
      title: title,
      body: body,
      dueDate: dueDate,
      linkedCourseId: linkedCourseId,
    );
  }

  @override
  Future<void> updateTaskStatus(String id, String status) {
    return _remote.updateTaskStatus(id, status);
  }

  @override
  Future<void> updateTask({
    required String id,
    required String title,
    String? body,
    DateTime? dueDate,
    String? progressNote,
  }) {
    return _remote.updateTask(
      id: id,
      title: title,
      body: body,
      dueDate: dueDate,
      progressNote: progressNote,
    );
  }

  @override
  Future<void> deleteTask(String id) => _remote.deleteTask(id);
}
