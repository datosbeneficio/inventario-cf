import 'dart:async';
import '../models/ciclo_config.dart';
import 'firestore_service.dart';
import 'local_cache_service.dart';

/// Servicio que detecta automáticamente cuando el ciclo activo
/// corresponde a un día anterior y ejecuta el reinicio sin intervención
/// del coordinador.
///
/// También detecta cuando el cicloId cambió en Firestore (coordinador
/// reinició desde otro dispositivo) y limpia el caché local IndexedDB
/// para que todos los dispositivos vean datos frescos.
///
/// Inicializar con [start()] después de Firebase.initializeApp().
class CicloAutoResetService {
  static StreamSubscription<CicloConfig>? _sub;

  /// Fecha (año-mes-día) en que ya se ejecutó el auto-reset en esta sesión.
  /// Previene que el listener dispare el reset más de una vez por día,
  /// incluso si el stream emite varios eventos antes de que Firestore
  /// confirme el serverTimestamp.
  static DateTime? _resetFecha;

  /// Lanza el listener. Llamar una sola vez en main().
  static void start() {
    _sub?.cancel();
    _sub = FirestoreService.instance
        .cicloConfigStream()
        .listen((ciclo) async {
      // Ignorar el estado inicial (cicloId vacío = nunca se configuró).
      if (ciclo.cicloId.isEmpty) return;

      // ── Detección de cambio de ciclo desde otro dispositivo ──────────────
      // Si el coordinador reinició el ciclo (o limpió datos de prueba) desde
      // otro dispositivo, el cicloId de Firestore será distinto al guardado
      // en localStorage. En ese caso limpiamos el IndexedDB y recargamos para
      // que este dispositivo trabaje con datos frescos.
      if (LocalCacheService.cicloIdCambio(ciclo.cicloId)) {
        LocalCacheService.guardarCicloId(ciclo.cicloId);
        await LocalCacheService.limpiarCacheYRecargar();
        return; // La página se recargará; el código de abajo no se ejecuta.
      }
      LocalCacheService.guardarCicloId(ciclo.cicloId);

      // ── Auto-reset por cambio de día ─────────────────────────────────────
      final hoy = DateTime.now();
      final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);

      // Protección adicional: si ya reseteamos hoy en esta sesión, salir.
      if (_resetFecha == hoyFecha) return;

      final esDeHoy = ciclo.inicio.year == hoy.year &&
          ciclo.inicio.month == hoy.month &&
          ciclo.inicio.day == hoy.day;

      if (!esDeHoy) {
        // Marcar ANTES del await para bloquear re-entrada si el stream
        // emitiera otro evento durante la escritura en Firestore.
        _resetFecha = hoyFecha;
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
