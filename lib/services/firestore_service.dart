import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/ciclo_config.dart';
import '../models/cliente.dart';
import '../models/rango.dart';
import '../models/ingreso.dart';
import '../models/salida.dart';
import '../models/vehiculo.dart';
import '../models/destino.dart';
import '../models/despacho.dart';
import '../models/empresa_config.dart';

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
    String tipo, {
    String subtipo = 'canastillas',
    String? descripcion,
  }) =>
      _db
          .collection('clientes')
          .doc(clienteId)
          .collection('rangos')
          .add({
        'nombre': nombre.trim(),
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        'multiplicador': multiplicador,
        'tipo': tipo,
        'subtipo': subtipo,
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

  // ── Vehículos ────────────────────────────────────────────────────────────

  Stream<List<Vehiculo>> vehiculosStream() => _db
      .collection('vehiculos')
      .orderBy('placa')
      .snapshots()
      .map((s) => s.docs
          .map(Vehiculo.fromDoc)
          .where((v) => v.activo)
          .toList());

  Future<void> addVehiculo({
    required String placa,
    required String conductorNombre,
    required String conductorCedula,
    required String conductorCelular,
    required double capacidadKg,
  }) =>
      _db.collection('vehiculos').add({
        'placa': placa.toUpperCase().trim(),
        'conductorNombre': conductorNombre.trim(),
        'conductorCedula': conductorCedula.trim(),
        'conductorCelular': conductorCelular.trim(),
        'capacidadKg': capacidadKg,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> updateVehiculo(
    String id, {
    required String placa,
    required String conductorNombre,
    required String conductorCedula,
    required String conductorCelular,
    required double capacidadKg,
  }) =>
      _db.collection('vehiculos').doc(id).update({
        'placa': placa.toUpperCase().trim(),
        'conductorNombre': conductorNombre.trim(),
        'conductorCedula': conductorCedula.trim(),
        'conductorCelular': conductorCelular.trim(),
        'capacidadKg': capacidadKg,
      });

  Future<void> deleteVehiculo(String id) =>
      _db.collection('vehiculos').doc(id).update({'activo': false});

  // ── Destinos ─────────────────────────────────────────────────────────────

  Stream<List<Destino>> destinosStream() => _db
      .collection('destinos')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs
          .map(Destino.fromDoc)
          .where((d) => d.activo)
          .toList());

  Future<void> addDestino({
    required String nombre,
    required String direccion,
    required String municipio,
    required String departamento,
  }) =>
      _db.collection('destinos').add({
        'nombre': nombre.trim(),
        'direccion': direccion.trim(),
        'municipio': municipio.trim(),
        'departamento': departamento.trim(),
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> updateDestino(
    String id, {
    required String nombre,
    required String direccion,
    required String municipio,
    required String departamento,
  }) =>
      _db.collection('destinos').doc(id).update({
        'nombre': nombre.trim(),
        'direccion': direccion.trim(),
        'municipio': municipio.trim(),
        'departamento': departamento.trim(),
      });

  Future<void> deleteDestino(String id) =>
      _db.collection('destinos').doc(id).update({'activo': false});

  // ── Despachos ────────────────────────────────────────────────────────────

  Stream<List<Despacho>> despachosStream() => _db
      .collection('despachos')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Despacho.fromDoc).toList());

  /// Genera un nuevo ID para un despacho sin crearlo aún.
  String newDespachoId() => _db.collection('despachos').doc().id;

  /// Crea el documento de despacho y todas las salidas en un único batch.
  /// Si se pasa [predefinedId], usa ese ID en lugar de generar uno nuevo.
  /// Retorna el ID del documento creado.
  Future<String> addDespacho(Despacho despacho,
      {String? predefinedId}) async {
    final batch = _db.batch();
    final despachoRef = predefinedId != null
        ? _db.collection('despachos').doc(predefinedId)
        : _db.collection('despachos').doc();
    batch.set(despachoRef, despacho.toMap());
    for (final linea in despacho.lineas) {
      final salidaRef = _db.collection('salidas').doc();
      batch.set(salidaRef, linea.toSalidaMap(despachoRef.id));
    }
    await batch.commit();
    return despachoRef.id;
  }

  Future<void> deleteDespacho(String despachoId) async {
    // Eliminar el documento de despacho y las salidas asociadas
    final batch = _db.batch();
    batch.delete(_db.collection('despachos').doc(despachoId));
    final salidas = await _db
        .collection('salidas')
        .where('despachoId', isEqualTo: despachoId)
        .get();
    for (final doc in salidas.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Config empresa ────────────────────────────────────────────────────────

  Stream<EmpresaConfig> empresaConfigStream() => _db
      .collection('config')
      .doc('empresa')
      .snapshots()
      .map((doc) =>
          doc.exists ? EmpresaConfig.fromDoc(doc) : EmpresaConfig.empty());

  Future<void> updateEmpresaConfig(EmpresaConfig config) =>
      _db.collection('config').doc('empresa').set(config.toMap());

  // ── Ciclo de producción ───────────────────────────────────────────────────

  Stream<CicloConfig> cicloConfigStream() => _db
      .collection('config')
      .doc('ciclo')
      .snapshots()
      .map((doc) =>
          doc.exists ? CicloConfig.fromDoc(doc) : CicloConfig.initial());

  /// Inicia un nuevo ciclo: a partir de este momento el inventario
  /// visible empieza desde cero. Los registros anteriores se conservan.
  Future<void> resetCiclo() => _db.collection('config').doc('ciclo').set({
        'inicio': FieldValue.serverTimestamp(),
        'cicloId': const Uuid().v4(),
      });

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int calcularUnidades(bool esCola, int inputValue, double mult) {
    if (esCola) return inputValue;
    return (inputValue * mult).round();
  }
}
