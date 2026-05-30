// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Gestiona el caché local de Firestore (IndexedDB en Flutter web).
///
/// Permite detectar cambios de ciclo originados en otro dispositivo y
/// limpiar el caché obsoleto para evitar inventarios fantasma.
class LocalCacheService {
  static const _kCicloIdKey = 'inventario_cf_ciclo_id';

  // ── Lectura/escritura del cicloId en localStorage ─────────────────────────

  static String get storedCicloId {
    if (!kIsWeb) return '';
    return html.window.localStorage[_kCicloIdKey] ?? '';
  }

  static void guardarCicloId(String cicloId) {
    if (!kIsWeb || cicloId.isEmpty) return;
    html.window.localStorage[_kCicloIdKey] = cicloId;
  }

  /// Elimina el cicloId guardado localmente.
  /// Llamar ANTES de iniciar un reset desde este dispositivo para que
  /// el nuevo cicloId no sea interpretado como un cambio externo.
  static void borrarCicloIdGuardado() {
    if (!kIsWeb) return;
    html.window.localStorage.remove(_kCicloIdKey);
  }

  /// Retorna true si el dispositivo tiene almacenado un cicloId distinto al
  /// que acaba de llegar de Firestore (señal de que el coordinador reinició
  /// el ciclo desde otro dispositivo mientras este estaba conectado).
  static bool cicloIdCambio(String nuevoCicloId) {
    if (!kIsWeb || nuevoCicloId.isEmpty) return false;
    final stored = storedCicloId;
    // Solo marcamos cambio si ya teníamos un cicloId guardado; la primera
    // vez (stored vacío) solo guardamos sin limpiar.
    return stored.isNotEmpty && stored != nuevoCicloId;
  }

  // ── Limpieza del caché ────────────────────────────────────────────────────

  /// Termina la instancia de Firestore, limpia su caché IndexedDB y recarga
  /// la página (equivale a un hard-reload que fuerza datos frescos del servidor).
  static Future<void> limpiarCacheYRecargar() async {
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // Si Firestore ya estaba terminado o la API no está disponible,
      // continuamos igual; la recarga forzará datos frescos.
    }
    if (kIsWeb) {
      html.window.location.reload();
    }
  }
}
