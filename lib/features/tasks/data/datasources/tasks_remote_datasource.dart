import 'package:supabase_flutter/supabase_flutter.dart';

class TasksRemoteDatasource {
  TasksRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchTasks() {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('due_date', ascending: true);
  }

  Future<void> addTask({
    required String title,
    String? body,
    DateTime? dueDate,
    String? linkedCourseId,
  }) async {
    await _client.from('tasks').insert({
      'title': title,
      'body': body,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'linked_course_id': linkedCourseId,
    });
  }

  Future<void> updateTaskStatus(String id, String status) async {
    await _client.from('tasks').update({'status': status}).eq('id', id);
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? body,
    DateTime? dueDate,
    String? progressNote,
  }) async {
    await _client
        .from('tasks')
        .update({
          'title': title,
          'body': body,
          'due_date': dueDate?.toIso8601String().split('T').first,
          'progress_note': progressNote,
        })
        .eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}
