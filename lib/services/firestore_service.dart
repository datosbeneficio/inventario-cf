import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../models/rango.dart';
import '../models/ingreso.dart';
import '../models/salida.dart';
class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── Clientes ────────────────────────────────────────────────────────────

  Stream<List<Cliente>> clientesStream() => _db
      .collection('clientes')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs
          .map(Cliente.fromDoc)
          .where((c) => c.activo)
          .toList());

  Future<void> addCliente(String nombre) => _db.collection('clientes').add({
        'nombre': nombre.trim(),
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> deleteCliente(String id) =>
      _db.collection('clientes').doc(id).update({'activo': false});

  // ── Rangos (subcollección de cliente) ───────────────────────────────────

  Stream<List<Rango>> rangosStream(String clienteId) => _db
      .collection('clientes')
      .doc(clienteId)
      .collection('rangos')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs
          .map((doc) => Rango.fromDoc(clienteId, doc))
          .where((r) => r.activo)
          .toList());

  Future<void> addRango(
    String clienteId,
    String nombre,
    double multiplicador,
    String tipo,
  ) =>
      _db
          .collection('clientes')
          .doc(clienteId)
          .collection('rangos')
          .add({
        'nombre': nombre.trim(),
        'multiplicador': multiplicador,
        'tipo': tipo,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> deleteRango(String clienteId, String rangoId) => _db
      .collection('clientes')
      .doc(clienteId)
      .collection('rangos')
      .doc(rangoId)
      .update({'activo': false});

  // ── Ingresos ─────────────────────────────────────────────────────────────

  Stream<List<Ingreso>> ingresosStream() => _db
      .collection('ingresos')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Ingreso.fromDoc).toList());

  Future<void> addIngreso({
    required String clienteId,
    required String clienteNombre,
    required String rangoId,
    required String rangoNombre,
    required String rangoTipo,
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection('ingresos').add({
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'rangoId': rangoId,
        'rangoNombre': rangoNombre,
        'rangoTipo': rangoTipo,
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
        'timestamp': FieldValue.serverTimestamp(),
      });

  Future<void> updateIngreso(
    String id, {
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection('ingresos').doc(id).update({
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
      });

  Future<void> deleteIngreso(String id) =>
      _db.collection('ingresos').doc(id).delete();

  // ── Salidas ──────────────────────────────────────────────────────────────

  Stream<List<Salida>> salidasStream() => _db
      .collection('salidas')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Salida.fromDoc).toList());

  Future<void> addSalida({
    required String clienteId,
    required String clienteNombre,
    required String rangoId,
    required String rangoNombre,
    required String rangoTipo,
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection('salidas').add({
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'rangoId': rangoId,
        'rangoNombre': rangoNombre,
        'rangoTipo': rangoTipo,
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
        'timestamp': FieldValue.serverTimestamp(),
      });

  Future<void> updateSalida(
    String id, {
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection('salidas').doc(id).update({
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
      });

  Future<void> deleteSalida(String id) =>
      _db.collection('salidas').doc(id).delete();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int calcularUnidades(bool esCola, int inputValue, double mult) {
    if (esCola) return inputValue;
    return (inputValue * mult).round();
  }
}
