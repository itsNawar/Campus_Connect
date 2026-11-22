import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect/core/utils.dart';
import 'package:campus_connect/features/auth/repository/auth_repository.dart';
import 'package:campus_connect/models/user_model.dart';

final userProvider = StateProvider<UserModel?>((ref) => null);

final authControllerProvider = StateNotifierProvider<AuthController, bool>(
  (ref) => AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  ),
);

final authStateChangeProvider = StreamProvider((ref) {
  final authController = ref.watch(authControllerProvider.notifier);
  return authController.authStateChange;
});

final getUserDataProvider = StreamProvider.family((ref, String uid) {
  final authController = ref.watch(authControllerProvider.notifier);
  return authController.getUserData(uid);
});

class AuthController extends StateNotifier<bool> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthController({
    required AuthRepository authRepository,
    required Ref ref,
  })  : _authRepository = authRepository,
        _ref = ref,
        super(false); // loading state

  Stream<User?> get authStateChange => _authRepository.authStateChange;

  void signInWithGoogle(BuildContext context, bool isFromLogin,
      {String? role}) async {
    state = true;
    final user =
        await _authRepository.signInWithGoogle(isFromLogin, selectedRole: role);
    state = false;
    user.fold(
      (l) => showSnackBar(context, l.message),
      (userModel) =>
          _ref.read(userProvider.notifier).update((state) => userModel),
    );
  }

  void signUpWithEmail({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
    required String role,
    required VoidCallback onSuccess,
  }) async {
    state = true;
    final res = await _authRepository.signUpWithEmail(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    state = false;
    res.fold(
      (l) => showSnackBar(context, l.message),
      (_) {
        showSnackBar(
          context,
          'Verification link sent to $email. Please verify your email before logging in.',
        );
        onSuccess();
      },
    );
  }

  void signInWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    state = true;
    final res = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    state = false;
    res.fold(
      (l) => showSnackBar(context, l.message),
      (userModel) =>
          _ref.read(userProvider.notifier).update((state) => userModel),
    );
  }

  void resetPassword(BuildContext context, String email) async {
    final res = await _authRepository.resetPassword(email);
    res.fold(
      (l) => showSnackBar(context, l.message),
      (_) => showSnackBar(context, 'Password reset email sent to $email.'),
    );
  }

  Stream<UserModel> getUserData(String uid) {
    return _authRepository.getUserData(uid);
  }

  void logout() async {
    _authRepository.logOut();
  }
}
