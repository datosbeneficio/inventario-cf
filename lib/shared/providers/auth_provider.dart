import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Dominio ficticio que se añade al nickname para formar un email válido
/// en Firebase Auth. El usuario nunca lo ve — solo escribe su nickname.
const _kAuthDomain = '@avima.cf';

/// Convierte un nickname a la dirección interna de Firebase Auth.
/// Ejemplo: 'supervisor' → 'supervisor@avima.cf'
String nicknameToEmail(String nickname) =>
    '${nickname.trim().toLowerCase()}$_kAuthDomain';

/// Gestiona la sesión del usuario vía Firebase Auth.
///
/// Los usuarios se crean en Firebase Auth con la dirección
/// `nickname@avima.cf` (generada internamente; el usuario solo escribe
/// su nickname). El rol se almacena en Firestore:
/// `users/{uid}` → `{ "rol": "coordinador", "modulos": ["cuarto_frio"] }`
///
/// Para crear un usuario nuevo:
///   1. Firebase Console → Authentication → Add user
///      Email: supervisor@avima.cf  |  Contraseña: la que elijas
///   2. Firestore → colección `users` → doc con el UID obtenido en el paso 1
///      `{ "rol": "supervisor", "modulos": ["cuarto_frio"] }`
class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _role;
  bool _loading = true;

  String? get role => _role;
  bool get isLoggedIn => _user != null && _role != null;
  bool get isLoading => _loading;
  String? get uid => _user?.uid;

  /// Nickname legible (la parte del email antes del @).
  String? get nickname {
    final email = _user?.email ?? '';
    final idx = email.indexOf('@');
    return idx > 0 ? email.substring(0, idx) : (email.isNotEmpty ? email : null);
  }

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

  /// [nickname] es el nombre de usuario (sin @dominio).
  /// Devuelve `null` si el login fue exitoso, o un mensaje de error.
  Future<String?> login(String nickname, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: nicknameToEmail(nickname),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (_) {
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
        return 'Usuario o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      default:
        return 'Error al iniciar sesión ($code).';
    }
  }
}
