import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDatasource _remote;

  AppUser? _toAppUser(dynamic user) {
    if (user == null) return null;
    return AppUser(
      id: user.id as String,
      email: (user.email as String?) ?? '',
      name: user.userMetadata?['name'] as String?,
    );
  }

  @override
  AppUser? get currentUser => _toAppUser(_remote.currentUser);

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _remote.authStateChanges.map((state) => _toAppUser(state.session?.user));
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _remote.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _remote.signOut();
}
