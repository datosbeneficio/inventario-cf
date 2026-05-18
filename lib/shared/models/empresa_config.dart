import 'package:cloud_firestore/cloud_firestore.dart';

class EmpresaConfig {
  final String nombre;
  final String subtitulo;
  final String direccion;
  final String nit;
  final String contacto;

  const EmpresaConfig({
    required this.nombre,
    required this.subtitulo,
    required this.direccion,
    required this.nit,
    required this.contacto,
  });

  factory EmpresaConfig.empty() => const EmpresaConfig(
        nombre: '',
        subtitulo: '',
        direccion: '',
        nit: '',
        contacto: '',
      );

  factory EmpresaConfig.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EmpresaConfig(
      nombre: d['nombre'] ?? '',
      subtitulo: d['subtitulo'] ?? '',
      direccion: d['direccion'] ?? '',
      nit: d['nit'] ?? '',
      contacto: d['contacto'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'subtitulo': subtitulo.trim(),
        'direccion': direccion.trim(),
        'nit': nit.trim(),
        'contacto': contacto.trim(),
      };
}
