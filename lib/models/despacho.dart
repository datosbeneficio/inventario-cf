import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

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
      };

  /// Serializa esta línea como documento de `salidas` (con despachoId inyectado).
  Map<String, dynamic> toSalidaMap(String despachoId) => {
        ...toMap(),
        'despachoId': despachoId,
        'timestamp': FieldValue.serverTimestamp(),
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
  final String conductorNombre;
  final String conductorCedula;
  final String conductorCelular;
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
  final List<DespachoLinea> lineas;
  final DateTime timestamp;

  const Despacho({
    required this.id,
    required this.guiaNro,
    required this.fechaDespacho,
    required this.fechaBeneficio,
    required this.vehiculoId,
    required this.placa,
    required this.conductorNombre,
    required this.conductorCedula,
    required this.conductorCelular,
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
    required this.lineas,
    required this.timestamp,
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
      conductorNombre: d['conductorNombre'] ?? '',
      conductorCedula: d['conductorCedula'] ?? '',
      conductorCelular: d['conductorCelular'] ?? '',
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
      lineas: lineasRaw
          .map((l) => DespachoLinea.fromMap(l as Map<String, dynamic>))
          .toList(),
      timestamp: d['timestamp'] != null
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'guiaNro': guiaNro,
        'fechaDespacho': Timestamp.fromDate(fechaDespacho),
        'fechaBeneficio': Timestamp.fromDate(fechaBeneficio),
        'vehiculoId': vehiculoId,
        'placa': placa,
        'conductorNombre': conductorNombre,
        'conductorCedula': conductorCedula,
        'conductorCelular': conductorCelular,
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
        'lineas': lineas.map((l) => l.toMap()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      };

  // Totales calculados
  int get totalCanastillas => lineas.fold(0, (s, l) => s + l.canastillas);
  int get totalUnidades => lineas.fold(0, (s, l) => s + l.unidades);
  double get totalPeso => lineas.fold(0.0, (s, l) => s + l.peso);
}
