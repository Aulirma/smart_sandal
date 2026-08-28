import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { elderlyDevice, wali, unknown }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Dengarkan perubahan status login (login/logout) secara realtime
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Ambil role user dari collection `users` di Firestore.
  /// Dipanggil setelah tahu user sudah login.
  Future<UserRole> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return UserRole.unknown;

    final role = doc.data()?['role'] as String?;
    switch (role) {
      case 'elderly_device':
        return UserRole.elderlyDevice;
      case 'wali':
        return UserRole.wali;
      default:
        return UserRole.unknown;
    }
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}