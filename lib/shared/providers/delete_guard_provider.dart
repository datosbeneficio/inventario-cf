import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controla el permiso temporal para eliminar registros.
///
/// El coordinador configura un código en [EmpresaConfig.codigoEliminacion].
/// Cuando un supervisor ingresa ese código, se abre una ventana de [_unlockDuration]
/// durante la cual los botones de eliminación son visibles.
/// Al vencer el timer, el permiso se revoca automáticamente.
class DeleteGuardProvider extends ChangeNotifier {
  static const _unlockDuration = Duration(minutes: 5);

  DateTime? _unlockedUntil;
  Timer? _timer;

  // ── Consulta de estado ──────────────────────────────────────────────────────

  bool get isUnlocked {
    if (_unlockedUntil == null) return false;
    return DateTime.now().isBefore(_unlockedUntil!);
  }

  /// Minutos completos que quedan (0 si está bloqueado).
  int get minutosRestantes {
    if (!isUnlocked) return 0;
    return _unlockedUntil!.difference(DateTime.now()).inMinutes;
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  /// Intenta desbloquear comparando [codigoIngresado] con [codigoCorrecto].
  /// Devuelve true si el código coincide (o si [codigoCorrecto] está vacío
  /// — feature desactivada — en cuyo caso siempre devuelve true).
  /// Si el código ya está activo se renueva el timer.
  bool intentarDesbloquear(String codigoIngresado, String codigoCorrecto) {
    if (codigoCorrecto.isEmpty || codigoIngresado == codigoCorrecto) {
      _activar();
      return true;
    }
    return false;
  }

  /// Bloquea inmediatamente sin esperar al timer.
  void bloquear() {
    _timer?.cancel();
    _timer = null;
    _unlockedUntil = null;
    notifyListeners();
  }

  // ── Interno ────────────────────────────────────────────────────────────────

  void _activar() {
    _timer?.cancel();
    _unlockedUntil = DateTime.now().add(_unlockDuration);
    _timer = Timer(_unlockDuration, () {
      _unlockedUntil = null;
      _timer = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
