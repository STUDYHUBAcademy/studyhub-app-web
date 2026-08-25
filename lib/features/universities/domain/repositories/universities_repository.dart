import '../entities/term.dart';
import '../entities/university.dart';

abstract class UniversitiesRepository {
  Stream<List<University>> watchUniversities();
  Stream<List<Term>> watchTerms();

  Future<University> addUniversity(String name);
  Future<void> renameUniversity(String id, String name);
  Future<void> deleteUniversity(String id);

  Future<Term> addTerm({
    required String semester,
    required String academicYear,
    DateTime? startDate,
    DateTime? endDate,
    required String status,
  });
  Future<void> updateTerm(
    String id, {
    required String semester,
    required String academicYear,
    DateTime? startDate,
    DateTime? endDate,
    required String status,
  });
  Future<void> deleteTerm(String id);
}
