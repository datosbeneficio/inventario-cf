import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  String? _role;
  String? get role => _role;
  bool get isLoggedIn => _role != null;

  bool login(String code) {
    switch (code.trim()) {
      case kCodigoCoordinador:
        _role = kRolCoordinador;
        break;
      case kCodigoEncargado:
        _role = kRolEncargado;
        break;
      case kCodigoSupervisor:
        _role = kRolSupervisor;
        break;
      default:
        return false;
    }
    notifyListeners();
    return true;
  }

  void logout() {
    _role = null;
    notifyListeners();
  }
}
