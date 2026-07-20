import 'package:cloud_firestore/cloud_firestore.dart';

class EmpresaConfig {
  final String nombre;
  final String subtitulo;
  final String direccion;
  final String nit;
  final String contacto;

  /// Código numérico para desbloquear la eliminación de registros.
  /// Si está vacío, el botón de guard no se muestra (feature desactivada).
  /// Se regenera automáticamente cada día (ver [CicloAutoResetService]).
  final String codigoEliminacion;

  /// Fecha (sin hora) en que se generó [codigoEliminacion] por última vez.
  /// Se usa para decidir si toca regenerarlo al cambiar el día.
  final DateTime? codigoEliminacionFecha;

  /// Consecutivo actual para lotes de rangos especiales.
  /// Cada despacho con líneas especiales toma este valor y lo incrementa.
  final int loteEspecialConsecutivo;

  /// Días de vida útil para calcular el vencimiento del lote especial.
  /// vencimientoEspecial = fechaDespacho + diasVencimientoEspecial.
  final int diasVencimientoEspecial;

  const EmpresaConfig({
    required this.nombre,
    required this.subtitulo,
    required this.direccion,
    required this.nit,
    required this.contacto,
    this.codigoEliminacion = '',
    this.codigoEliminacionFecha,
    this.loteEspecialConsecutivo = 1,
    this.diasVencimientoEspecial = 30,
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
      codigoEliminacionFecha: d['codigoEliminacionFecha'] != null
          ? (d['codigoEliminacionFecha'] as Timestamp).toDate()
          : null,
      loteEspecialConsecutivo: d['loteEspecialConsecutivo'] ?? 1,
      diasVencimientoEspecial: d['diasVencimientoEspecial'] ?? 30,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'subtitulo': subtitulo.trim(),
        'direccion': direccion.trim(),
        'nit': nit.trim(),
        'contacto': contacto.trim(),
        'codigoEliminacion': codigoEliminacion.trim(),
        if (codigoEliminacionFecha != null)
          'codigoEliminacionFecha': Timestamp.fromDate(codigoEliminacionFecha!),
        'loteEspecialConsecutivo': loteEspecialConsecutivo,
        'diasVencimientoEspecial': diasVencimientoEspecial,
      };
}
