import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Web Client ID (from Google Cloud Console) ─────────────────────────────
  static const String _webClientId =
      '241665118590-dt9453qig25vvdtj90jiokgj32mqf11e.apps.googleusercontent.com';

  // ── Important: Use a NEW GoogleSignIn instance each time ──────────────────
  // Do NOT store it as a singleton — this causes sign-in to silently fail
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  // ── Helper: are we on a desktop/web platform? ─────────────────────────────
  bool get _usePopup =>
      kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));

  User? get currentUser => _auth.currentUser;

  // ── Check if profile is complete ──────────────────────────────────────────

  Future<bool> isProfileComplete(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['profileComplete'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Google Sign In / Sign Up ───────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      if (_usePopup) {
        // ── Web / Windows / macOS / Linux: use signInWithPopup ──────────────
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        final result = await _auth.signInWithPopup(googleProvider);
        return await _processFirebaseResult(result, 'google');
      } else {
        // ── Android / iOS: use google_sign_in package ────────────────────────
        final gsi = _googleSignIn;

        // Sign out first to force account picker every time
        await gsi.signOut();

        final googleUser = await gsi.signIn();
        if (googleUser == null) return AuthResult.cancelled();

        final googleAuth = await googleUser.authentication;

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          return AuthResult.error(
              'Google authentication failed. Please try again.');
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final result = await _auth.signInWithCredential(credential);
        return await _processFirebaseResult(result, 'google');
      }
    } on FirebaseAuthException catch (e) {
      print('🔴 FirebaseAuthException: code=${e.code} message=${e.message}');
      return AuthResult.error(_friendlyError(e.code));
    } catch (e, stack) {
      print('🔴 Google Sign-In Error: $e');
      print('🔴 Stack: $stack');
      return AuthResult.error(
          'Google sign-in failed: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}');
    }
  }

  // ── Facebook Sign In / Sign Up ────────────────────────────────────────────

  Future<AuthResult> signInWithFacebook() async {
    try {
      if (_usePopup) {
        // ── Web / Windows: use signInWithPopup ───────────────────────────────
        final facebookProvider = FacebookAuthProvider()
          ..addScope('email')
          ..addScope('public_profile');

        final result = await _auth.signInWithPopup(facebookProvider);
        return await _processFirebaseResult(result, 'facebook');
      } else {
        // ── Android / iOS: use flutter_facebook_auth package ─────────────────
        await FacebookAuth.instance.logOut();

        final fbResult = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
        );

        if (fbResult.status == LoginStatus.cancelled) {
          return AuthResult.cancelled();
        }

        if (fbResult.status != LoginStatus.success) {
          print('🔴 Facebook Login Status: ${fbResult.status}');
          print('🔴 Facebook Login Message: ${fbResult.message}');
          return AuthResult.error(
              'Facebook login failed: ${fbResult.message ?? "Please try again."}');
        }

        final credential = FacebookAuthProvider.credential(
          fbResult.accessToken!.tokenString,
        );

        final result = await _auth.signInWithCredential(credential);
        final user = result.user!;
        final isNew = result.additionalUserInfo?.isNewUser ?? false;

        if (isNew) {
          final userData = await FacebookAuth.instance.getUserData(
            fields: 'name,email,picture.type(large)',
          );
          await _createUserDoc(
            uid: user.uid,
            name: userData['name'] ?? user.displayName ?? '',
            email: userData['email'] ?? user.email ?? '',
            photoUrl:
            userData['picture']?['data']?['url'] ?? user.photoURL ?? '',
            phone: user.phoneNumber ?? '',
            provider: 'facebook',
          );
        }

        final profileComplete =
        isNew ? false : await isProfileComplete(user.uid);
        return AuthResult.success(
            user: user, isNewUser: isNew, profileComplete: profileComplete);
      }
    } on FirebaseAuthException catch (e) {
      print(
          '🔴 Facebook FirebaseAuthException: code=${e.code} message=${e.message}');
      return AuthResult.error(_friendlyError(e.code));
    } catch (e, stack) {
      print('🔴 Facebook Sign-In Error: $e');
      print('🔴 Stack: $stack');
      return AuthResult.error('Facebook sign-in failed. Please try again.');
    }
  }

  // ── Shared: process UserCredential from signInWithPopup or signInWithCredential
  Future<AuthResult> _processFirebaseResult(
      UserCredential result, String provider) async {
    final user = result.user!;
    final isNew = result.additionalUserInfo?.isNewUser ?? false;

    if (isNew) {
      await _createUserDoc(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        phone: user.phoneNumber ?? '',
        provider: provider,
      );
    }

    final profileComplete = isNew ? false : await isProfileComplete(user.uid);
    return AuthResult.success(
        user: user, isNewUser: isNew, profileComplete: profileComplete);
  }

  // ── Email/Password Sign Up ────────────────────────────────────────────────

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user!;

      await _createUserDoc(
        uid: user.uid,
        name: '',
        email: email,
        photoUrl: '',
        phone: '',
        provider: 'email',
      );

      return AuthResult.success(
          user: user, isNewUser: true, profileComplete: false);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.error('Sign-up failed. Please try again.');
    }
  }

  // ── Email/Password Sign In ────────────────────────────────────────────────

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user!;
      final profileComplete = await isProfileComplete(user.uid);
      return AuthResult.success(
          user: user, isNewUser: false, profileComplete: profileComplete);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.error('Sign-in failed. Please try again.');
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final futures = <Future>[_auth.signOut()];

    if (!_usePopup) {
      // Only call these on mobile — they don't exist on web/desktop
      futures.add(_googleSignIn.signOut());
      futures.add(FacebookAuth.instance.logOut());
    }

    await Future.wait(futures);
  }

  // ── Create user doc ───────────────────────────────────────────────────────

  Future<void> _createUserDoc({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    required String phone,
    required String provider,
  }) async {
    final ts = FieldValue.serverTimestamp();
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': name,
      'email': email,
      'photoUrl': photoUrl,
      'phone': phone,
      'provider': provider,
      'profileComplete': false,
      'locationSet': false,
      'createdAt': ts,
      'updatedAt': ts,
    });
  }

  // ── Friendly error messages ───────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Check SHA-1 in Firebase Console.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked. Please allow popups and try again.';
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled.';
      case 'cancelled-popup-request':
        return 'Another sign-in is already in progress.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}

// ── Auth Result ───────────────────────────────────────────────────────────────

class AuthResult {
  final User? user;
  final bool isNewUser;
  final bool profileComplete;
  final String? error;
  final bool cancelled;

  AuthResult._({
    this.user,
    this.isNewUser = false,
    this.profileComplete = false,
    this.error,
    this.cancelled = false,
  });

  factory AuthResult.success({
    required User user,
    required bool isNewUser,
    required bool profileComplete,
  }) =>
      AuthResult._(
          user: user, isNewUser: isNewUser, profileComplete: profileComplete);

  factory AuthResult.error(String message) => AuthResult._(error: message);
  factory AuthResult.cancelled() => AuthResult._(cancelled: true);

  bool get isSuccess => user != null && error == null && !cancelled;
}