import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';
import 'user_model.dart';

enum AuthRequestStatus { initial, loading, success, failure }

class LoginController extends GetxController {
  LoginController({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  final currentAdmin = Rxn<UserModel>();
  final loginStatus = Rx<AuthRequestStatus>(AuthRequestStatus.initial);
  final createDoctorStatus = Rx<AuthRequestStatus>(AuthRequestStatus.initial);

  String? get adminId => currentAdmin.value?.uid;

  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    loginStatus.value = AuthRequestStatus.loading;

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Login completed without a user session.',
        );
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firebaseAuth.signOut();
        throw FirebaseAuthException(
          code: 'missing-profile',
          message: 'No profile found for this account.',
        );
      }

      final model = UserModel.fromJson(userDoc.data()!);
      if (!model.isAdmin) {
        await _firebaseAuth.signOut();
        throw FirebaseAuthException(
          code: 'unauthorized-role',
          message: 'Only admin accounts can access this dashboard.',
        );
      }

      currentAdmin.value = model;
      loginStatus.value = AuthRequestStatus.success;
      return true;
    } on FirebaseAuthException catch (error) {
      loginStatus.value = AuthRequestStatus.failure;
      throw Exception(_friendlyAuthMessage(error));
    } catch (_) {
      loginStatus.value = AuthRequestStatus.failure;
      throw Exception('Something went wrong while signing in.');
    }
  }

  Future<void> createDoctorAccount({
    required String fullName,
    required String email,
    required String password,
  }) async {
    createDoctorStatus.value = AuthRequestStatus.loading;

    FirebaseApp? secondaryApp;

    try {
      try {
        secondaryApp = Firebase.app('doctor-account-creator');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'doctor-account-creator',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final createdUser = credential.user;
      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Doctor account could not be created.',
        );
      }

      final doctor = UserModel(
        email: email.trim(),
        fullName: fullName.trim(),
        role: 'doctor',
        uid: createdUser.uid,
      );

      await _firestore.collection('users').doc(createdUser.uid).set(
            doctor.toJson(),
            SetOptions(merge: true),
          );

      await secondaryAuth.signOut();
      createDoctorStatus.value = AuthRequestStatus.success;
    } on FirebaseAuthException catch (error) {
      createDoctorStatus.value = AuthRequestStatus.failure;
      throw Exception(_friendlyDoctorCreateMessage(error));
    } catch (_) {
      createDoctorStatus.value = AuthRequestStatus.failure;
      throw Exception('Unable to create the doctor account right now.');
    }
  }

  Stream<List<UserModel>> watchUsers() {
    return _firestore.collection('users').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList(growable: false),
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLectures() {
    return _firestore
        .collection('lectures')
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    currentAdmin.value = null;
    loginStatus.value = AuthRequestStatus.initial;
  }

  String _friendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'missing-profile':
        return error.message ?? 'This account has no Firestore profile.';
      case 'unauthorized-role':
        return error.message ?? 'This account is not allowed here.';
      default:
        return error.message ?? 'Sign in failed. Please try again.';
    }
  }

  String _friendlyDoctorCreateMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email is already being used by another account.';
      case 'invalid-email':
        return 'Enter a valid email for the doctor account.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      default:
        return error.message ?? 'Doctor account creation failed.';
    }
  }
}
