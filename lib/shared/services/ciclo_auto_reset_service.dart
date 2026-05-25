import 'dart:async';
import '../models/ciclo_config.dart';
import 'firestore_service.dart';

/// Servicio que detecta automáticamente cuando el ciclo activo
/// corresponde a un día anterior y ejecuta el reinicio sin intervención
/// del coordinador.
///
/// El coordinador puede reiniciar manualmente en cualquier momento;
/// este servicio solo actúa como fallback cuando se olvidó hacerlo.
///
/// Inicializar con [start()] después de Firebase.initializeApp().
/// Se detiene solo con [stop()] (normalmente innecesario).
class CicloAutoResetService {
  static StreamSubscription<CicloConfig>? _sub;

  /// Lanza el listener. Llamar una sola vez en main().
  static void start() {
    _sub?.cancel();
    _sub = FirestoreService.instance
        .cicloConfigStream()
        .listen((ciclo) async {
      // Ignorar el estado inicial (cicloId vacío = nunca se configuró).
      if (ciclo.cicloId.isEmpty) return;

      final hoy = DateTime.now();
      final esDeHoy = ciclo.inicio.year == hoy.year &&
          ciclo.inicio.month == hoy.month &&
          ciclo.inicio.day == hoy.day;

      if (!esDeHoy) {
        // El ciclo quedó del día anterior → auto-reset silencioso.
        await FirestoreService.instance.resetCiclo();
      }
    });
  }

  /// Cancela el listener (útil en tests o si se quiere deshabilitar).
  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
