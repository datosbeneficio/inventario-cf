import 'package:cloud_firestore/cloud_firestore.dart';

class Destino {
  final String id;
  final String nombre;
  final String direccion;
  final String municipio;
  final String departamento;
  final bool activo;

  const Destino({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.municipio,
    required this.departamento,
    required this.activo,
  });

  factory Destino.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Destino(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      direccion: d['direccion'] ?? '',
      municipio: d['municipio'] ?? '',
      departamento: d['departamento'] ?? '',
      activo: d['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'direccion': direccion.trim(),
        'municipio': municipio.trim(),
        'departamento': departamento.trim(),
        'activo': activo,
      };
}
