import '../entities/student.dart';

abstract class StudentsRepository {
  Stream<List<Student>> watchStudents();
  Future<Student> addStudent({
    required String name,
    String? phoneWhatsapp,
    String? universityId,
    String acquisitionSource = 'direct',
    String? marketerName,
    double? commissionPct,
  });
  Future<void> updateStudent({
    required String id,
    required String name,
    String? phoneWhatsapp,
    String? universityId,
    required String acquisitionSource,
    String? marketerName,
    double? commissionPct,
  });
  Future<void> deleteStudent(String id);
}
