import 'package:cloud_firestore/cloud_firestore.dart';

class Vehiculo {
  final String id;
  final String placa;
  final String conductorNombre;
  final String conductorCedula;
  final String conductorCelular;
  final double capacidadKg;
  final bool activo;

  const Vehiculo({
    required this.id,
    required this.placa,
    required this.conductorNombre,
    required this.conductorCedula,
    required this.conductorCelular,
    required this.capacidadKg,
    required this.activo,
  });

  factory Vehiculo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Vehiculo(
      id: doc.id,
      placa: d['placa'] ?? '',
      conductorNombre: d['conductorNombre'] ?? '',
      conductorCedula: d['conductorCedula'] ?? '',
      conductorCelular: d['conductorCelular'] ?? '',
      capacidadKg: (d['capacidadKg'] ?? 0.0).toDouble(),
      activo: d['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'placa': placa.toUpperCase().trim(),
        'conductorNombre': conductorNombre.trim(),
        'conductorCedula': conductorCedula.trim(),
        'conductorCelular': conductorCelular.trim(),
        'capacidadKg': capacidadKg,
        'activo': activo,
      };
}
