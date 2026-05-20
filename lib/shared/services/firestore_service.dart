import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/ciclo_config.dart';
import '../models/cliente.dart';
import '../../modules/cuarto_frio/models/rango.dart';
import '../../modules/cuarto_frio/models/ingreso.dart';
import '../../modules/cuarto_frio/models/salida.dart';
import '../../modules/cuarto_frio/models/vehiculo.dart';
import '../../modules/cuarto_frio/models/destino.dart';
import '../../modules/cuarto_frio/models/despacho.dart';
import '../models/empresa_config.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── Nombres de colecciones (prefijo cf_ = módulo Cuarto Frío) ────────────
  // Las colecciones sin prefijo son compartidas entre módulos.
  static const _colIngresos  = 'cf_ingresos';
  static const _colSalidas   = 'cf_salidas';
  static const _colDespachos = 'cf_despachos';
  static const _colVehiculos = 'cf_vehiculos';
  static const _colDestinos  = 'cf_destinos';
  static const _colClientes  = 'clientes';   // compartido

  /// Nickname del usuario autenticado (parte antes del @ del email interno).
  /// Ejemplo: 'supervisor@avima.cf' → 'supervisor'
  String get _creadoPor {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final idx = email.indexOf('@');
    return idx > 0 ? email.substring(0, idx) : email;
  }

  // ── Clientes ────────────────────────────────────────────────────────────

  Stream<List<Cliente>> clientesStream() => _db
      .collection(_colClientes)
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs
          .map(Cliente.fromDoc)
          .where((c) => c.activo)
          .toList());

  Future<void> addCliente(String nombre) => _db.collection(_colClientes).add({
        'nombre': nombre.trim(),
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> deleteCliente(String id) =>
      _db.collection(_colClientes).doc(id).update({'activo': false});

  // ── Rangos (subcollección de cliente) ───────────────────────────────────

  Stream<List<Rango>> rangosStream(String clienteId) => _db
      .collection(_colClientes)
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
          .collection(_colClientes)
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
      .collection(_colClientes)
      .doc(clienteId)
      .collection('rangos')
      .doc(rangoId)
      .update({'activo': false});

  // ── Ingresos ─────────────────────────────────────────────────────────────

  Stream<List<Ingreso>> ingresosStream() => _db
      .collection(_colIngresos)
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
      _db.collection(_colIngresos).add({
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
        if (_creadoPor.isNotEmpty) 'creadoPor': _creadoPor,
      });

  Future<void> updateIngreso(
    String id, {
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection(_colIngresos).doc(id).update({
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
      });

  Future<void> deleteIngreso(String id) =>
      _db.collection(_colIngresos).doc(id).delete();

  // ── Salidas ──────────────────────────────────────────────────────────────

  Stream<List<Salida>> salidasStream() => _db
      .collection(_colSalidas)
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
      _db.collection(_colSalidas).add({
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
        if (_creadoPor.isNotEmpty) 'creadoPor': _creadoPor,
      });

  Future<void> updateSalida(
    String id, {
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
  }) =>
      _db.collection(_colSalidas).doc(id).update({
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
      });

  Future<void> deleteSalida(String id) =>
      _db.collection(_colSalidas).doc(id).delete();

  // ── Vehículos ────────────────────────────────────────────────────────────

  Stream<List<Vehiculo>> vehiculosStream() => _db
      .collection(_colVehiculos)
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
      _db.collection(_colVehiculos).add({
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
      _db.collection(_colVehiculos).doc(id).update({
        'placa': placa.toUpperCase().trim(),
        'conductorNombre': conductorNombre.trim(),
        'conductorCedula': conductorCedula.trim(),
        'conductorCelular': conductorCelular.trim(),
        'capacidadKg': capacidadKg,
      });

  Future<void> deleteVehiculo(String id) =>
      _db.collection(_colVehiculos).doc(id).update({'activo': false});

  // ── Destinos ─────────────────────────────────────────────────────────────

  Stream<List<Destino>> destinosStream() => _db
      .collection(_colDestinos)
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
      _db.collection(_colDestinos).add({
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
      _db.collection(_colDestinos).doc(id).update({
        'nombre': nombre.trim(),
        'direccion': direccion.trim(),
        'municipio': municipio.trim(),
        'departamento': departamento.trim(),
      });

  Future<void> deleteDestino(String id) =>
      _db.collection(_colDestinos).doc(id).update({'activo': false});

  // ── Despachos ────────────────────────────────────────────────────────────

  Stream<List<Despacho>> despachosStream() => _db
      .collection(_colDespachos)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Despacho.fromDoc).toList());

  /// Genera un nuevo ID para un despacho sin crearlo aún.
  String newDespachoId() => _db.collection(_colDespachos).doc().id;

  /// Crea el documento de despacho y todas las salidas en un único batch.
  /// Si se pasa [predefinedId], usa ese ID en lugar de generar uno nuevo.
  /// Retorna el ID del documento creado.
  Future<String> addDespacho(Despacho despacho,
      {String? predefinedId}) async {
    final quien = _creadoPor;
    final batch = _db.batch();
    final despachoRef = predefinedId != null
        ? _db.collection(_colDespachos).doc(predefinedId)
        : _db.collection(_colDespachos).doc();
    // Inyectar creadoPor en el despacho
    final despachoMap = {
      ...despacho.toMap(),
      if (quien.isNotEmpty) 'creadoPor': quien,
    };
    batch.set(despachoRef, despachoMap);
    for (final linea in despacho.lineas) {
      final salidaRef = _db.collection(_colSalidas).doc();
      batch.set(salidaRef, linea.toSalidaMap(despachoRef.id, quien));
    }
    await batch.commit();
    return despachoRef.id;
  }

  Future<void> deleteDespacho(String despachoId) async {
    // Eliminar el documento de despacho y las salidas asociadas
    final batch = _db.batch();
    batch.delete(_db.collection(_colDespachos).doc(despachoId));
    final salidas = await _db
        .collection(_colSalidas)
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
