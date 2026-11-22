import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final authProvider = Provider((ref) => FirebaseAuth.instance);
final storageProvider = Provider((ref) => FirebaseStorage.instance);

final googleSignInProvider = Provider((ref) => GoogleSignIn(
      serverClientId:
          '982939331481-38ns0134a4rvh0tp9eflhsknktbav9j0.apps.googleusercontent.com',
      scopes: [
        'email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ],
    ));
