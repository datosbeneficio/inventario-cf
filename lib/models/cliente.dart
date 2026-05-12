import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String nombre;
  final bool activo;
  final DateTime creadoEn;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.creadoEn,
  });

  factory Cliente.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Cliente(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      activo: d['activo'] ?? true,
      creadoEn: d['creadoEn'] != null
          ? (d['creadoEn'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
