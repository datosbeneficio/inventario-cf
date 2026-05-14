import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class Rango {
  final String id;
  final String clienteId;
  final String nombre;
  final String? descripcion;
  final double multiplicador;
  final String tipo;
  final String subtipo;
  final bool activo;

  const Rango({
    required this.id,
    required this.clienteId,
    required this.nombre,
    this.descripcion,
    required this.multiplicador,
    required this.tipo,
    required this.subtipo,
    required this.activo,
  });

  bool get esAves => tipo == kTipoAves;
  bool get esMenudencias => tipo == kTipoMenudencias;

  /// Menudencias con multiplicador: cada canastilla = N paquetes
  bool get esPaquetes =>
      tipo == kTipoMenudencias && subtipo == kSubtipoPaquetes;

  factory Rango.fromDoc(String clienteId, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Rango(
      id: doc.id,
      clienteId: clienteId,
      nombre: d['nombre'] ?? '',
      descripcion: d['descripcion'] as String?,
      multiplicador: (d['multiplicador'] ?? 1.0).toDouble(),
      tipo: d['tipo'] ?? kTipoAves,
      subtipo: d['subtipo'] ?? kSubtipoCanastillas,
      activo: d['activo'] ?? true,
    );
  }
}
