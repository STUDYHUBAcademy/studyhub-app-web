import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
