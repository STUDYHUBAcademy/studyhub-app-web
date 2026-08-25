import '../entities/task.dart';

abstract class TasksRepository {
  Stream<List<Task>> watchTasks();
  Future<void> addTask({
    required String title,
    String? body,
    DateTime? dueDate,
    String? linkedCourseId,
  });
  Future<void> updateTaskStatus(String id, String status);
  Future<void> updateTask({
    required String id,
    required String title,
    String? body,
    DateTime? dueDate,
    String? progressNote,
  });
  Future<void> deleteTask(String id);
}
