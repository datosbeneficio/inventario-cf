import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuración del ciclo de producción activo.
/// Se almacena en `config/ciclo` como documento único.
class CicloConfig {
  /// Momento en que se inició el ciclo actual.
  /// Solo se cuentan ingresos/salidas con timestamp >= [inicio].
  final DateTime inicio;

  /// Identificador del ciclo (para referencia en reportes).
  final String cicloId;

  const CicloConfig({required this.inicio, required this.cicloId});

  /// Config vacío: incluye TODOS los registros históricos
  /// (usado como valor inicial hasta que Firestore responda).
  factory CicloConfig.initial() => CicloConfig(
        inicio: DateTime(2000),
        cicloId: '',
      );

  factory CicloConfig.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CicloConfig(
      // Si el timestamp es null, significa que Firestore aún no confirmó el
      // serverTimestamp (escritura pendiente en Flutter web). Usamos DateTime.now()
      // para que el inventario quede en cero mientras se confirma, en lugar de
      // DateTime(2000) que mostraría TODO el historial y dispararía el loop de reset.
      inicio: d['inicio'] != null
          ? (d['inicio'] as Timestamp).toDate()
          : DateTime.now(),
      cicloId: d['cicloId'] ?? '',
    );
  }
}
