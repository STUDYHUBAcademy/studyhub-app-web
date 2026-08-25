import '../../domain/entities/term.dart';
import '../../domain/entities/university.dart';
import '../../domain/repositories/universities_repository.dart';
import '../datasources/universities_remote_datasource.dart';

class UniversitiesRepositoryImpl implements UniversitiesRepository {
  UniversitiesRepositoryImpl(this._remote);

  final UniversitiesRemoteDatasource _remote;

  String? _dateStr(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Stream<List<University>> watchUniversities() {
    return _remote.watchUniversities().map(
      (rows) => rows.map(University.fromJson).toList(),
    );
  }

  @override
  Stream<List<Term>> watchTerms() {
    return _remote.watchTerms().map((rows) => rows.map(Term.fromJson).toList());
  }

  @override
  Future<University> addUniversity(String name) async {
    final row = await _remote.addUniversity(name);
    return University.fromJson(row);
  }

  @override
  Future<void> renameUniversity(String id, String name) =>
      _remote.renameUniversity(id, name);

  @override
  Future<void> deleteUniversity(String id) => _remote.deleteUniversity(id);

  String _computeName(String semester, String academicYear) {
    return '${semesterLabels[semester] ?? semester} $academicYear';
  }

  @override
  Future<Term> addTerm({
    required String semester,
    required String academicYear,
    DateTime? startDate,
    DateTime? endDate,
    required String status,
  }) async {
    final row = await _remote.addTerm({
      'name': _computeName(semester, academicYear),
      'semester': semester,
      'academic_year': academicYear,
      'start_date': _dateStr(startDate),
      'end_date': _dateStr(endDate),
      'status': status,
    });
    return Term.fromJson(row);
  }

  @override
  Future<void> updateTerm(
    String id, {
    required String semester,
    required String academicYear,
    DateTime? startDate,
    DateTime? endDate,
    required String status,
  }) {
    return _remote.updateTerm(id, {
      'name': _computeName(semester, academicYear),
      'semester': semester,
      'academic_year': academicYear,
      'start_date': _dateStr(startDate),
      'end_date': _dateStr(endDate),
      'status': status,
    });
  }

  @override
  Future<void> deleteTerm(String id) => _remote.deleteTerm(id);
}
