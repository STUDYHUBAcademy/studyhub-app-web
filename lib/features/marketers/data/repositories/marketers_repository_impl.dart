import '../../domain/entities/marketer.dart';
import '../../domain/repositories/marketers_repository.dart';
import '../datasources/marketers_remote_datasource.dart';

class MarketersRepositoryImpl implements MarketersRepository {
  MarketersRepositoryImpl(this._remote);

  final MarketersRemoteDatasource _remote;

  @override
  Stream<List<Marketer>> watchMarketers() {
    return _remote.watchMarketers().map(
      (rows) => rows.map(Marketer.fromJson).toList(),
    );
  }

  @override
  Future<Marketer> addMarketer({
    required String name,
    String? phoneWhatsapp,
    double? defaultCommissionAmount,
    String? notes,
  }) async {
    final row = await _remote.addMarketer(
      name: name,
      phoneWhatsapp: phoneWhatsapp,
      defaultCommissionAmount: defaultCommissionAmount,
      notes: notes,
    );
    return Marketer.fromJson(row);
  }

  @override
  Future<void> updateMarketer({
    required String id,
    required String name,
    String? phoneWhatsapp,
    double? defaultCommissionAmount,
    String? notes,
  }) {
    return _remote.updateMarketer(id, {
      'name': name,
      'phone_whatsapp': phoneWhatsapp,
      'default_commission_amount': defaultCommissionAmount,
      'notes': notes,
    });
  }

  @override
  Future<void> deleteMarketer(String id) => _remote.deleteMarketer(id);
}
