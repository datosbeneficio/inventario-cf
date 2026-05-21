import 'package:cloud_firestore/cloud_firestore.dart';

class Conductor {
  final String id;
  final String nombre;
  final String cedula;
  final bool activo;

  const Conductor({
    required this.id,
    required this.nombre,
    required this.cedula,
    required this.activo,
  });

  factory Conductor.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Conductor(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      cedula: d['cedula'] ?? '',
      activo: d['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'cedula': cedula.trim(),
        'activo': activo,
      };
}
