import 'package:cloud_firestore/cloud_firestore.dart';

class Ingreso {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String rangoId;
  final String rangoNombre;
  final String rangoTipo;
  final int canastillas;
  final double peso;
  final bool esCola;
  final int unidades;
  final DateTime timestamp;
  /// Email del usuario que registró el movimiento.
  final String creadoPor;
  /// true si este ingreso fue creado automáticamente al reiniciar el ciclo
  /// para conservar producto del día anterior.
  final bool esRemanente;

  const Ingreso({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.rangoId,
    required this.rangoNombre,
    required this.rangoTipo,
    required this.canastillas,
    required this.peso,
    required this.esCola,
    required this.unidades,
    required this.timestamp,
    this.creadoPor = '',
    this.esRemanente = false,
  });

  factory Ingreso.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Ingreso(
      id: doc.id,
      clienteId: d['clienteId'] ?? '',
      clienteNombre: d['clienteNombre'] ?? '',
      rangoId: d['rangoId'] ?? '',
      rangoNombre: d['rangoNombre'] ?? '',
      rangoTipo: d['rangoTipo'] ?? 'aves',
      canastillas: d['canastillas'] ?? 0,
      peso: (d['peso'] ?? 0.0).toDouble(),
      esCola: d['esCola'] ?? false,
      unidades: d['unidades'] ?? 0,
      timestamp: d['timestamp'] != null
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      creadoPor: d['creadoPor'] ?? '',
      esRemanente: d['esRemanente'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'rangoId': rangoId,
        'rangoNombre': rangoNombre,
        'rangoTipo': rangoTipo,
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
        'timestamp': FieldValue.serverTimestamp(),
        if (creadoPor.isNotEmpty) 'creadoPor': creadoPor,
        if (esRemanente) 'esRemanente': true,
      };
}
