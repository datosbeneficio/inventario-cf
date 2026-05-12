import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class Rango {
  final String id;
  final String clienteId;
  final String nombre;
  final double multiplicador;
  final String tipo;
  final bool activo;

  const Rango({
    required this.id,
    required this.clienteId,
    required this.nombre,
    required this.multiplicador,
    required this.tipo,
    required this.activo,
  });

  bool get esAves => tipo == kTipoAves;
  bool get esMenudencias => tipo == kTipoMenudencias;

  factory Rango.fromDoc(String clienteId, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Rango(
      id: doc.id,
      clienteId: clienteId,
      nombre: d['nombre'] ?? '',
      multiplicador: (d['multiplicador'] ?? 1.0).toDouble(),
      tipo: d['tipo'] ?? kTipoAves,
      activo: d['activo'] ?? true,
    );
  }
}
