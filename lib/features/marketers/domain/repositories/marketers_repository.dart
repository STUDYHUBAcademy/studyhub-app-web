import '../entities/marketer.dart';

abstract class MarketersRepository {
  Stream<List<Marketer>> watchMarketers();
  Future<Marketer> addMarketer({
    required String name,
    String? phoneWhatsapp,
    double? defaultCommissionAmount,
    String? notes,
  });
  Future<void> updateMarketer({
    required String id,
    required String name,
    String? phoneWhatsapp,
    double? defaultCommissionAmount,
    String? notes,
  });
  Future<void> deleteMarketer(String id);
}
