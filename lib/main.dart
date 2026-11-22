import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect/core/common/error_text.dart';
import 'package:campus_connect/core/common/loader.dart';
import 'package:campus_connect/core/constants/constants.dart';
import 'package:campus_connect/core/constants/firebase_constants.dart';
import 'package:campus_connect/features/auth/controlller/auth_controller.dart';
import 'package:campus_connect/models/user_model.dart';
import 'package:campus_connect/router.dart';
import 'package:campus_connect/theme/pallete.dart';
import 'package:routemaster/routemaster.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    }
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  UserModel? userModel;
  bool isFetching = false;

  void getData(WidgetRef ref, User data) async {
    if (isFetching) return;
    isFetching = true;
    try {
      final userDocRef = FirebaseFirestore.instance
          .collection(FirebaseConstants.usersCollection)
          .doc(data.uid);

      final docSnapshot =
          await userDocRef.get().timeout(const Duration(seconds: 8));

      UserModel resolvedUser;
      if (docSnapshot.exists && docSnapshot.data() != null) {
        resolvedUser = UserModel.fromMap(docSnapshot.data()!);
      } else {
        final email = data.email ?? '';
        final localPart = email.split('@').first;
        final isNumericId = RegExp(r'^\d+$').hasMatch(localPart);
        resolvedUser = UserModel(
          name:
              (data.displayName != null && data.displayName!.trim().isNotEmpty)
                  ? data.displayName!.trim()
                  : localPart,
          profilePic: data.photoURL ?? Constants.avatarDefault,
          banner: Constants.bannerDefault,
          uid: data.uid,
          isAuthenticated: true,
          karma: 0,
          awards: [],
          role: isNumericId ? 'Student' : 'Faculty',
        );
        await userDocRef.set(resolvedUser.toMap());
      }

      ref.read(userProvider.notifier).update((state) => resolvedUser);
      if (mounted) {
        setState(() {
          userModel = resolvedUser;
        });
      }
    } catch (e) {
      debugPrint('Error resolving user profile: $e');
      await FirebaseAuth.instance.signOut();
    } finally {
      isFetching = false;
    }
  }

  bool _isVerifiedInstitutionalUser(User? user) {
    if (user == null) return false;
    final email = user.email?.trim().toLowerCase() ?? '';
    final isEduDomain = email.endsWith('@eastdelta.edu.bd');
    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');
    return isEduDomain && (user.emailVerified || isGoogleUser);
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(authStateChangeProvider).when(
          data: (data) {
            final isVerified = _isVerifiedInstitutionalUser(data);
            if (!isVerified) {
              userModel = null;
            }

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'EDU Campus Connect',
              theme: ref.watch(themeNotifierProvider),
              routerDelegate: RoutemasterDelegate(
                routesBuilder: (context) {
                  if (data != null && isVerified) {
                    if (userModel != null) {
                      return loggedInRoute;
                    }
                    getData(ref, data);
                    return RouteMap(
                      routes: {
                        '/': (_) => const MaterialPage(child: Loader()),
                      },
                    );
                  }
                  return loggedOutRoute;
                },
              ),
              routeInformationParser: const RoutemasterParser(),
            );
          },
          error: (error, stackTrace) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ref.watch(themeNotifierProvider),
            home: Scaffold(body: ErrorText(error: error.toString())),
          ),
          loading: () => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ref.watch(themeNotifierProvider),
            home: const Scaffold(body: Loader()),
          ),
        );
  }
}
