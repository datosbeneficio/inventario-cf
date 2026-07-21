import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/utils/constants.dart';

/// Un descarte registrado dentro del despacho.
class DespachoDescarte {
  /// Sigla del motivo: HG, SC, PC, PP, PD o OTRO.
  final String sigla;
  /// Descripción completa o texto libre (para OTRO).
  final String tipo;
  final int cantidad;

  const DespachoDescarte({
    required this.sigla,
    required this.tipo,
    required this.cantidad,
  });

  factory DespachoDescarte.fromMap(Map<String, dynamic> m) => DespachoDescarte(
        sigla: m['sigla'] ?? '',
        tipo: m['tipo'] ?? '',
        cantidad: m['cantidad'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'sigla': sigla,
        'tipo': tipo,
        'cantidad': cantidad,
      };
}

/// Una línea de producto dentro del despacho.
class DespachoLinea {
  final String clienteId;
  final String clienteNombre;
  final String rangoId;
  final String rangoNombre;
  final String rangoTipo;
  final int canastillas;
  final int unidades;
  final double peso;
  final bool esCola;
  /// true si esta línea corresponde a producto remanente del día anterior.
  final bool esRemanente;
  /// true si el rango fue marcado como "especial" por el coordinador.
  final bool esEspecial;

  const DespachoLinea({
    required this.clienteId,
    required this.clienteNombre,
    required this.rangoId,
    required this.rangoNombre,
    required this.rangoTipo,
    required this.canastillas,
    required this.unidades,
    required this.peso,
    required this.esCola,
    this.esRemanente = false,
    this.esEspecial = false,
  });

  factory DespachoLinea.fromMap(Map<String, dynamic> m) => DespachoLinea(
        clienteId: m['clienteId'] ?? '',
        clienteNombre: m['clienteNombre'] ?? '',
        rangoId: m['rangoId'] ?? '',
        rangoNombre: m['rangoNombre'] ?? '',
        rangoTipo: m['rangoTipo'] ?? kTipoAves,
        canastillas: m['canastillas'] ?? 0,
        unidades: m['unidades'] ?? 0,
        peso: (m['peso'] ?? 0.0).toDouble(),
        esCola: m['esCola'] ?? false,
        esRemanente: m['esRemanente'] ?? false,
        esEspecial: m['esEspecial'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'rangoId': rangoId,
        'rangoNombre': rangoNombre,
        'rangoTipo': rangoTipo,
        'canastillas': canastillas,
        'unidades': unidades,
        'peso': peso,
        'esCola': esCola,
        if (esRemanente) 'esRemanente': true,
        if (esEspecial) 'esEspecial': true,
      };

  /// Serializa esta línea como documento de `salidas` (con despachoId y creadoPor inyectados).
  Map<String, dynamic> toSalidaMap(String despachoId, String creadoPor) => {
        ...toMap(),
        'despachoId': despachoId,
        'timestamp': FieldValue.serverTimestamp(),
        if (creadoPor.isNotEmpty) 'creadoPor': creadoPor,
      };
}

/// Documento de despacho completo.
class Despacho {
  final String id;
  final String guiaNro;
  final DateTime fechaDespacho;
  final DateTime fechaBeneficio;
  final String vehiculoId;
  final String placa;
  final String plancha;
  final String conductorId;
  final String conductorNombre;
  final String conductorCedula;
  final double capacidadKg;
  final String horaSalida;
  final String destinoId;
  final String destinoNombre;
  final String direccion;
  final String municipio;
  final String departamento;
  final String precinto;
  final String tempCanal;
  final String tempMenudencias;
  final String tempPreEnfriamiento;
  // ── Lotes de producción y vencimientos ──────────────────────────────────
  final String lotePollo;
  final DateTime? vencimientoPollo;
  final String loteMenudencias;
  final DateTime? vencimientoMenudencias;
  final String loteEspecial;
  final DateTime? vencimientoEspecial;
  final List<DespachoLinea> lineas;
  /// Descartes registrados en este despacho (puede estar vacío).
  final List<DespachoDescarte> descartes;
  final DateTime timestamp;
  final String observaciones;
  /// Email del usuario que creó el despacho.
  final String creadoPor;
  /// Persona de la planta responsable de este despacho (no siempre coincide
  /// con [creadoPor], que es el login genérico usado en el dispositivo).
  final String encargadoNombre;
  final String encargadoCedula;
  /// 'aprobado' o 'aprobado_condicional'.
  final String dictamen;
  final bool liberado;

  const Despacho({
    required this.id,
    required this.guiaNro,
    required this.fechaDespacho,
    required this.fechaBeneficio,
    required this.vehiculoId,
    required this.placa,
    required this.plancha,
    this.conductorId = '',
    required this.conductorNombre,
    required this.conductorCedula,
    required this.capacidadKg,
    required this.horaSalida,
    required this.destinoId,
    required this.destinoNombre,
    required this.direccion,
    required this.municipio,
    required this.departamento,
    required this.precinto,
    required this.tempCanal,
    required this.tempMenudencias,
    required this.tempPreEnfriamiento,
    this.lotePollo = '',
    this.vencimientoPollo,
    this.loteMenudencias = '',
    this.vencimientoMenudencias,
    this.loteEspecial = '',
    this.vencimientoEspecial,
    // Nota: en el formulario estos campos son obligatorios (INVIMA).
    // Los defaults vacíos/null solo aplican a documentos históricos.
    required this.lineas,
    this.descartes = const [],
    required this.timestamp,
    this.observaciones = '',
    this.creadoPor = '',
    this.encargadoNombre = '',
    this.encargadoCedula = '',
    this.dictamen = 'aprobado',
    this.liberado = true,
  });

  factory Despacho.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final lineasRaw = (d['lineas'] as List<dynamic>? ?? []);
    return Despacho(
      id: doc.id,
      guiaNro: d['guiaNro'] ?? '',
      fechaDespacho: d['fechaDespacho'] != null
          ? (d['fechaDespacho'] as Timestamp).toDate()
          : DateTime.now(),
      fechaBeneficio: d['fechaBeneficio'] != null
          ? (d['fechaBeneficio'] as Timestamp).toDate()
          : DateTime.now(),
      vehiculoId: d['vehiculoId'] ?? '',
      placa: d['placa'] ?? '',
      plancha: d['plancha'] ?? d['conductorCelular'] ?? '',
      conductorId: d['conductorId'] ?? '',
      conductorNombre: d['conductorNombre'] ?? '',
      conductorCedula: d['conductorCedula'] ?? '',
      capacidadKg: (d['capacidadKg'] ?? 0.0).toDouble(),
      horaSalida: d['horaSalida'] ?? '',
      destinoId: d['destinoId'] ?? '',
      destinoNombre: d['destinoNombre'] ?? '',
      direccion: d['direccion'] ?? '',
      municipio: d['municipio'] ?? '',
      departamento: d['departamento'] ?? '',
      precinto: d['precinto'] ?? '',
      tempCanal: d['tempCanal'] ?? '',
      tempMenudencias: d['tempMenudencias'] ?? '',
      tempPreEnfriamiento: d['tempPreEnfriamiento'] ?? '',
      lotePollo: d['lotePollo'] ?? '',
      vencimientoPollo: d['vencimientoPollo'] != null
          ? (d['vencimientoPollo'] as Timestamp).toDate()
          : null,
      loteMenudencias: d['loteMenudencias'] ?? '',
      vencimientoMenudencias: d['vencimientoMenudencias'] != null
          ? (d['vencimientoMenudencias'] as Timestamp).toDate()
          : null,
      loteEspecial: d['loteEspecial'] ?? '',
      vencimientoEspecial: d['vencimientoEspecial'] != null
          ? (d['vencimientoEspecial'] as Timestamp).toDate()
          : null,
      lineas: lineasRaw
          .map((l) => DespachoLinea.fromMap(l as Map<String, dynamic>))
          .toList(),
      descartes: (d['descartes'] as List<dynamic>? ?? [])
          .map((e) => DespachoDescarte.fromMap(e as Map<String, dynamic>))
          .toList(),
      timestamp: d['timestamp'] != null
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      observaciones: d['observaciones'] ?? '',
      creadoPor: d['creadoPor'] ?? '',
      encargadoNombre: d['encargadoNombre'] ?? '',
      encargadoCedula: d['encargadoCedula'] ?? '',
      dictamen: d['dictamen'] ?? 'aprobado',
      liberado: d['liberado'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'guiaNro': guiaNro,
        'fechaDespacho': Timestamp.fromDate(fechaDespacho),
        'fechaBeneficio': Timestamp.fromDate(fechaBeneficio),
        'vehiculoId': vehiculoId,
        'placa': placa,
        'plancha': plancha,
        if (conductorId.isNotEmpty) 'conductorId': conductorId,
        'conductorNombre': conductorNombre,
        'conductorCedula': conductorCedula,
        'capacidadKg': capacidadKg,
        'horaSalida': horaSalida,
        'destinoId': destinoId,
        'destinoNombre': destinoNombre,
        'direccion': direccion,
        'municipio': municipio,
        'departamento': departamento,
        'precinto': precinto,
        'tempCanal': tempCanal,
        'tempMenudencias': tempMenudencias,
        'tempPreEnfriamiento': tempPreEnfriamiento,
        'lotePollo': lotePollo,
        if (vencimientoPollo != null)
          'vencimientoPollo': Timestamp.fromDate(vencimientoPollo!),
        'loteMenudencias': loteMenudencias,
        if (vencimientoMenudencias != null)
          'vencimientoMenudencias': Timestamp.fromDate(vencimientoMenudencias!),
        if (loteEspecial.isNotEmpty) 'loteEspecial': loteEspecial,
        if (vencimientoEspecial != null)
          'vencimientoEspecial': Timestamp.fromDate(vencimientoEspecial!),
        'lineas': lineas.map((l) => l.toMap()).toList(),
        if (descartes.isNotEmpty)
          'descartes': descartes.map((d) => d.toMap()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
        if (observaciones.isNotEmpty) 'observaciones': observaciones,
        if (creadoPor.isNotEmpty) 'creadoPor': creadoPor,
        'encargadoNombre': encargadoNombre,
        'encargadoCedula': encargadoCedula,
        'dictamen': dictamen,
        'liberado': liberado,
      };

  // Totales calculados
  int get totalCanastillas => lineas.fold(0, (s, l) => s + l.canastillas);
  int get totalUnidades => lineas.fold(0, (s, l) => s + l.unidades);
  double get totalPeso => lineas.fold(0.0, (s, l) => s + l.peso);
}
