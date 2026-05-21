import 'package:cloud_firestore/cloud_firestore.dart';

class Vehiculo {
  final String id;
  final String placa;
  final String plancha;
  final double capacidadKg;
  final bool activo;

  const Vehiculo({
    required this.id,
    required this.placa,
    required this.plancha,
    required this.capacidadKg,
    required this.activo,
  });

  factory Vehiculo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Vehiculo(
      id: doc.id,
      placa: d['placa'] ?? '',
      plancha: d['plancha'] ?? d['conductorCelular'] ?? '',
      capacidadKg: (d['capacidadKg'] ?? 0.0).toDouble(),
      activo: d['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'placa': placa.toUpperCase().trim(),
        'plancha': plancha.trim(),
        'capacidadKg': capacidadKg,
        'activo': activo,
      };
}
