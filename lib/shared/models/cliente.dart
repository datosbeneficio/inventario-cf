import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String nombre;
  final bool activo;
  final DateTime creadoEn;

  /// Marca corta usada para armar el número de lote de sus despachos
  /// (ej. "A" para Andino → lote "200726A"). Por defecto la primera
  /// inicial del nombre, pero se puede personalizar por cliente.
  final String marcaLote;

  /// Días entre la fecha de despacho y el vencimiento, por tipo de
  /// producto. Cada cliente puede manejar plazos distintos (ej. Andino:
  /// 12 días canal, 10 días menudencias).
  final int diasVencimientoAves;
  final int diasVencimientoMenudencias;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.creadoEn,
    this.marcaLote = '',
    this.diasVencimientoAves = 30,
    this.diasVencimientoMenudencias = 30,
  });

  /// Marca efectiva a usar en el lote: la configurada, o si no hay
  /// ninguna, la primera inicial del nombre.
  String get marcaLoteEfectiva => marcaLote.isNotEmpty
      ? marcaLote
      : (nombre.isNotEmpty ? nombre[0].toUpperCase() : '');

  factory Cliente.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Cliente(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      activo: d['activo'] ?? true,
      creadoEn: d['creadoEn'] != null
          ? (d['creadoEn'] as Timestamp).toDate()
          : DateTime.now(),
      marcaLote: d['marcaLote'] ?? '',
      diasVencimientoAves: d['diasVencimientoAves'] ?? 30,
      diasVencimientoMenudencias: d['diasVencimientoMenudencias'] ?? 30,
    );
  }
}
