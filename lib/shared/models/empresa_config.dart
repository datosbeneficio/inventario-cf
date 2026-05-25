import 'package:cloud_firestore/cloud_firestore.dart';

class EmpresaConfig {
  final String nombre;
  final String subtitulo;
  final String direccion;
  final String nit;
  final String contacto;

  /// Código numérico para desbloquear la eliminación de registros.
  /// Si está vacío, el botón de guard no se muestra (feature desactivada).
  final String codigoEliminacion;

  const EmpresaConfig({
    required this.nombre,
    required this.subtitulo,
    required this.direccion,
    required this.nit,
    required this.contacto,
    this.codigoEliminacion = '',
  });

  factory EmpresaConfig.empty() => const EmpresaConfig(
        nombre: '',
        subtitulo: '',
        direccion: '',
        nit: '',
        contacto: '',
        codigoEliminacion: 'huevos',
      );

  factory EmpresaConfig.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EmpresaConfig(
      nombre: d['nombre'] ?? '',
      subtitulo: d['subtitulo'] ?? '',
      direccion: d['direccion'] ?? '',
      nit: d['nit'] ?? '',
      contacto: d['contacto'] ?? '',
      codigoEliminacion: d['codigoEliminacion'] ?? 'huevos',
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'subtitulo': subtitulo.trim(),
        'direccion': direccion.trim(),
        'nit': nit.trim(),
        'contacto': contacto.trim(),
        'codigoEliminacion': codigoEliminacion.trim(),
      };
}
