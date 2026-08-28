import '../../domain/entities/student.dart';
import '../../domain/repositories/students_repository.dart';
import '../datasources/students_remote_datasource.dart';

class StudentsRepositoryImpl implements StudentsRepository {
  StudentsRepositoryImpl(this._remote);

  final StudentsRemoteDatasource _remote;

  @override
  Stream<List<Student>> watchStudents() {
    return _remote.watchStudents().map(
      (rows) => rows.map(Student.fromJson).toList(),
    );
  }

  @override
  Future<Student> addStudent({
    required String name,
    String? phoneWhatsapp,
    String? universityId,
    String acquisitionSource = 'direct',
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) async {
    final row = await _remote.addStudent(
      name: name,
      phoneWhatsapp: phoneWhatsapp,
      universityId: universityId,
      acquisitionSource: acquisitionSource,
      marketerName: marketerName,
      commissionPct: commissionPct,
      commissionAmount: commissionAmount,
    );
    return Student.fromJson(row);
  }

  @override
  Future<void> updateStudent({
    required String id,
    required String name,
    String? phoneWhatsapp,
    String? universityId,
    required String acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) {
    return _remote.updateStudent(id, {
      'name': name,
      'phone_whatsapp': phoneWhatsapp,
      'university_id': universityId,
      'acquisition_source': acquisitionSource,
      'marketer_name': marketerName,
      'commission_pct': commissionPct,
      'commission_amount': ?commissionAmount,
    });
  }

  @override
  Future<void> deleteStudent(String id) => _remote.deleteStudent(id);
}
