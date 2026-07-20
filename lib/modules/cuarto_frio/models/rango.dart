import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/utils/constants.dart';

class Rango {
  final String id;
  final String clienteId;
  final String nombre;
  final String? descripcion;
  final double multiplicador;
  final String tipo;
  final String subtipo;
  final bool activo;
  final bool esEspecial;

  /// Posición para mostrar el rango en listas/formularios. Los rangos con
  /// [orden] explícito se muestran en ese orden; los que no lo tienen
  /// (datos previos a esta funcionalidad) se ordenan alfabéticamente al final.
  final int? orden;

  const Rango({
    required this.id,
    required this.clienteId,
    required this.nombre,
    this.descripcion,
    required this.multiplicador,
    required this.tipo,
    required this.subtipo,
    required this.activo,
    this.esEspecial = false,
    this.orden,
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
      esEspecial: d['esEspecial'] ?? false,
      orden: d['orden'] as int?,
    );
  }
}
