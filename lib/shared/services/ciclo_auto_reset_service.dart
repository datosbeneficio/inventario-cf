import 'dart:async';
import '../models/ciclo_config.dart';
import 'firestore_service.dart';
import 'local_cache_service.dart';

/// Servicio que detecta automáticamente cuando el ciclo activo
/// corresponde a un día anterior y ejecuta el reinicio sin intervención
/// del coordinador.
///
/// También detecta cuando el cicloId cambió en Firestore porque otro
/// dispositivo reinició el ciclo, y limpia el IndexedDB local para que
/// todos los dispositivos trabajen con datos frescos.
///
/// Inicializar con [start()] después de Firebase.initializeApp().
class CicloAutoResetService {
  static StreamSubscription<CicloConfig>? _sub;

  /// Fecha (año-mes-día) en que ya se ejecutó el auto-reset en esta sesión.
  static DateTime? _resetFecha;

  /// True mientras ESTE dispositivo está en medio de un resetCiclo().
  /// Durante ese lapso ignoramos el cambio de cicloId en el stream para
  /// no tratar nuestro propio reset como un "cambio externo".
  static bool _reseteandoDesdeEsteDispositivo = false;

  // ── API pública ───────────────────────────────────────────────────────────

  /// Ejecuta [fn] protegido: borra el cicloId guardado y activa el flag
  /// para que ningún evento del stream dispare una limpieza de caché
  /// durante el reset.
  ///
  /// Usar siempre que ESTE dispositivo vaya a llamar resetCiclo() o
  /// resetCicloConRemanente(), ya sea por auto-reset o por acción manual
  /// del coordinador.
  ///
  /// Ejemplo:
  /// ```dart
  /// await CicloAutoResetService.ejecutarReset(
  ///   () => FirestoreService.instance.resetCiclo(),
  /// );
  /// ```
  static Future<T> ejecutarReset<T>(Future<T> Function() fn) async {
    _reseteandoDesdeEsteDispositivo = true;
    // Al borrar el cicloId guardado, el nuevo cicloId que genere el reset
    // llegará con storedCicloId vacío → cicloIdCambio() devolverá false.
    LocalCacheService.borrarCicloIdGuardado();
    try {
      return await fn();
    } finally {
      // El stream puede dispararse durante el await (Dart event-loop).
      // Dejamos el flag en false solo cuando ya terminó el reset.
      _reseteandoDesdeEsteDispositivo = false;
    }
  }

  /// Lanza el listener. Llamar una sola vez en main().
  static void start() {
    _sub?.cancel();
    _sub = FirestoreService.instance
        .cicloConfigStream()
        .listen((ciclo) async {
      if (ciclo.cicloId.isEmpty) return;

      // ── Detección de cambio de ciclo desde OTRO dispositivo ──────────────
      // Ignorar si ESTE dispositivo está ejecutando el reset (el flag
      // _reseteandoDesdeEsteDispositivo lo indica) o si el storedCicloId
      // quedó vacío porque borramos antes del reset propio.
      if (!_reseteandoDesdeEsteDispositivo &&
          LocalCacheService.cicloIdCambio(ciclo.cicloId)) {
        LocalCacheService.guardarCicloId(ciclo.cicloId);
        await LocalCacheService.limpiarCacheYRecargar();
        return; // La página se recargará.
      }
      LocalCacheService.guardarCicloId(ciclo.cicloId);

      // ── Auto-reset por cambio de día ─────────────────────────────────────
      final hoy = DateTime.now();
      final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);

      if (_resetFecha == hoyFecha) return;
      _resetFecha = hoyFecha;

      // Código de eliminación: se regenera solo (aleatorio) una vez al día,
      // independiente del estado del ciclo. La transacción interna es
      // idempotente entre dispositivos.
      unawaited(FirestoreService.instance.regenerarCodigoEliminacionSiNecesario());

      final esDeHoy = ciclo.inicio.year == hoy.year &&
          ciclo.inicio.month == hoy.month &&
          ciclo.inicio.day == hoy.day;

      if (!esDeHoy) {
        await ejecutarReset(FirestoreService.instance.resetCiclo);
      }
    });
  }

  /// Cancela el listener.
  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
