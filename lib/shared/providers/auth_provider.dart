import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gestiona la sesión del usuario vía Firebase Auth.
///
/// El rol se lee del documento `users/{uid}` en Firestore:
///   `{ rol: 'coordinador' | 'encargado' | 'supervisor' | 'supervisor_menudencias' }`
///
/// Para crear un usuario nuevo:
///   1. Firebase Console → Authentication → Add user (email + contraseña)
///   2. Firestore → colección `users` → documento con el UID del usuario
///      `{ "rol": "coordinador", "modulos": ["cuarto_frio"] }`
class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _role;
  bool _loading = true;

  String? get role => _role;
  bool get isLoggedIn => _user != null && _role != null;
  bool get isLoading => _loading;
  String? get uid => _user?.uid;
  String? get email => _user?.email;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        _role = doc.data()?['rol'] as String?;
      } catch (_) {
        _role = null;
      }
    } else {
      _role = null;
    }
    _loading = false;
    notifyListeners();
  }

  /// Devuelve `null` si el login fue exitoso, o un mensaje de error.
  Future<String?> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return 'Error inesperado. Intenta de nuevo.';
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  static String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      default:
        return 'Error al iniciar sesión ($code).';
    }
  }
}
