import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:campus_connect/core/constants/constants.dart';
import 'package:campus_connect/core/constants/firebase_constants.dart';
import 'package:campus_connect/core/failure.dart';
import 'package:campus_connect/core/providers/firebase_providers.dart';
import 'package:campus_connect/core/type_defs.dart';
import 'package:campus_connect/models/user_model.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(authProvider),
    googleSignIn: ref.read(googleSignInProvider),
  ),
);

class AuthRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required GoogleSignIn googleSignIn,
  })  : _auth = auth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  Stream<User?> get authStateChange => _auth.authStateChanges();

  bool _isEduEmail(String email) {
    return email.trim().toLowerCase().endsWith('@eastdelta.edu.bd');
  }

  /// Auto-detects role if not explicitly selected:
  /// Numeric local-parts (e.g., 233032312@eastdelta.edu.bd) map to 'Student';
  /// alphabetic local-parts default to 'Faculty' unless 'Staff' is chosen.
  String _inferRoleFromEmail(String email, {String? selectedRole}) {
    if (selectedRole != null && selectedRole.isNotEmpty) return selectedRole;
    final localPart = email.split('@').first;
    final isNumericId = RegExp(r'^\d+$').hasMatch(localPart);
    return isNumericId ? 'Student' : 'Faculty';
  }

  FutureEither<UserModel> signInWithGoogle(
    bool isFromLogin, {
    String? selectedRole,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return left(Failure('Sign-in cancelled.'));
      }

      if (!_isEduEmail(googleUser.email)) {
        await _googleSignIn.signOut();
        return left(
          Failure('Access denied: Only @eastdelta.edu.bd emails are allowed.'),
        );
      }

      final googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;
      if (isFromLogin) {
        userCredential = await _auth.signInWithCredential(credential);
      } else {
        userCredential =
            await _auth.currentUser!.linkWithCredential(credential);
      }

      UserModel userModel;
      final existingDoc = await _users.doc(userCredential.user!.uid).get();

      if ((userCredential.additionalUserInfo?.isNewUser ?? false) ||
          !existingDoc.exists) {
        userModel = UserModel(
          name: userCredential.user!.displayName ??
              googleUser.email.split('@').first,
          profilePic: userCredential.user!.photoURL ?? Constants.avatarDefault,
          banner: Constants.bannerDefault,
          uid: userCredential.user!.uid,
          isAuthenticated: true,
          karma: 0,
          awards: [],
          role: _inferRoleFromEmail(
            googleUser.email,
            selectedRole: selectedRole,
          ),
        );
        await _users.doc(userCredential.user!.uid).set(userModel.toMap());
      } else {
        userModel = await getUserData(userCredential.user!.uid).first;
      }
      return right(userModel);
    } on FirebaseException catch (e) {
      return left(Failure(e.message ?? 'Firebase authentication error.'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (!_isEduEmail(cleanEmail)) {
        return left(
          Failure('Only @eastdelta.edu.bd institutional emails can register.'),
        );
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = userCredential.user!;
      await user.updateDisplayName(name.trim());

      final userModel = UserModel(
        name: name.trim(),
        profilePic: Constants.avatarDefault,
        banner: Constants.bannerDefault,
        uid: user.uid,
        isAuthenticated: true,
        karma: 0,
        awards: [],
        role: role,
      );

      await _users.doc(user.uid).set(userModel.toMap());

      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Verification email send warning: $e');
      }

      await _auth.signOut();
      return right(null);
    } on FirebaseAuthException catch (e) {
      return left(Failure(e.message ?? 'Registration failed.'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureEither<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (!_isEduEmail(cleanEmail)) {
        return left(Failure('Only @eastdelta.edu.bd emails are allowed.'));
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = userCredential.user!;
      await user.reload();

      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (e) {
          debugPrint('Verification email resend warning: $e');
        }
        await _auth.signOut();
        return left(
          Failure(
            'Verification link sent to $cleanEmail. Check Inbox/Spam, then Sign In.',
          ),
        );
      }

      final existingDoc = await _users.doc(user.uid).get();
      if (!existingDoc.exists) {
        final fallbackUser = UserModel(
          name: user.displayName ?? cleanEmail.split('@').first,
          profilePic: Constants.avatarDefault,
          banner: Constants.bannerDefault,
          uid: user.uid,
          isAuthenticated: true,
          karma: 0,
          awards: [],
          role: _inferRoleFromEmail(cleanEmail),
        );
        await _users.doc(user.uid).set(fallbackUser.toMap());
        return right(fallbackUser);
      }

      final userModel = await getUserData(user.uid).first;
      return right(userModel);
    } on FirebaseAuthException catch (e) {
      return left(Failure(e.message ?? 'Login failed.'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  FutureVoid resetPassword(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (!_isEduEmail(cleanEmail)) {
        return left(Failure('Enter a valid @eastdelta.edu.bd email address.'));
      }
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return right(null);
    } on FirebaseAuthException catch (e) {
      return left(Failure(e.message ?? 'Could not send reset email.'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  Stream<UserModel> getUserData(String uid) {
    return _users.doc(uid).snapshots().map(
          (event) => UserModel.fromMap(event.data() as Map<String, dynamic>),
        );
  }

  void logOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
