import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/ciclo_config.dart';
import '../models/cliente.dart';
import '../../modules/cuarto_frio/models/rango.dart';
import '../../modules/cuarto_frio/models/ingreso.dart';
import '../../modules/cuarto_frio/models/salida.dart';
import '../../modules/cuarto_frio/models/conductor.dart';
import '../../modules/cuarto_frio/models/vehiculo.dart';
import '../../modules/cuarto_frio/models/destino.dart';
import '../../modules/cuarto_frio/models/despacho.dart';
import '../models/empresa_config.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  /// Notifica errores de escrituras "fire-and-forget" (addIngreso, addSalida)
  /// que no bloquean la UI pero cuyo fallo (permisos, red) debe verse en
  /// pantalla en vez de desaparecer en silencio.
  final _writeErrors = StreamController<String>.broadcast();
  Stream<String> get writeErrors => _writeErrors.stream;

  void _reportWriteError(String accion, Object e) {
    _writeErrors.add('No se pudo guardar $accion: $e');
  }

  // ── Nombres de colecciones (prefijo cf_ = módulo Cuarto Frío) ────────────
  // Las colecciones sin prefijo son compartidas entre módulos.
  static const _colIngresos  = 'cf_ingresos';
  static const _colSalidas   = 'cf_salidas';
  static const _colDespachos = 'cf_despachos';
  static const _colVehiculos   = 'cf_vehiculos';
  static const _colConductores = 'cf_conductores';
  static const _colDestinos    = 'cf_destinos';
  static const _colClientes    = 'clientes';   // compartido

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

  /// Orden: los rangos con [Rango.orden] explícito van primero (según ese
  /// valor); los que no lo tienen (datos previos a esta funcionalidad) se
  /// muestran después, ordenados alfabéticamente entre sí.
  Stream<List<Rango>> rangosStream(String clienteId) => _db
      .collection(_colClientes)
      .doc(clienteId)
      .collection('rangos')
      .snapshots()
      .map((s) {
        final rangos = s.docs
            .map((doc) => Rango.fromDoc(clienteId, doc))
            .where((r) => r.activo)
            .toList();
        rangos.sort((a, b) {
          final ao = a.orden ?? 999999;
          final bo = b.orden ?? 999999;
          if (ao != bo) return ao.compareTo(bo);
          return a.nombre.compareTo(b.nombre);
        });
        return rangos;
      });

  Future<void> addRango(
    String clienteId,
    String nombre,
    double multiplicador,
    String tipo, {
    String subtipo = 'canastillas',
    String? descripcion,
  }) async {
    final rangosRef =
        _db.collection(_colClientes).doc(clienteId).collection('rangos');
    final existentes = await rangosRef.get();
    await rangosRef.add({
      'nombre': nombre.trim(),
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
      'multiplicador': multiplicador,
      'tipo': tipo,
      'subtipo': subtipo,
      'activo': true,
      'orden': existentes.size,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// [esEspecial] es una decisión propia de cada cliente: el mismo nombre de
  /// rango puede ser especial para un cliente y no para otro.
  Future<void> updateRango(
          String clienteId, String rangoId, Map<String, dynamic> data) =>
      _db
          .collection(_colClientes)
          .doc(clienteId)
          .collection('rangos')
          .doc(rangoId)
          .update(data);

  Future<void> deleteRango(String clienteId, String rangoId) => _db
      .collection(_colClientes)
      .doc(clienteId)
      .collection('rangos')
      .doc(rangoId)
      .update({'activo': false});

  /// Guarda el nuevo orden de los rangos de un cliente. [rangoIdsEnOrden]
  /// debe traer TODOS los ids visibles, en el orden final deseado.
  Future<void> reordenarRangos(
      String clienteId, List<String> rangoIdsEnOrden) async {
    final ref =
        _db.collection(_colClientes).doc(clienteId).collection('rangos');
    final batch = _db.batch();
    for (var i = 0; i < rangoIdsEnOrden.length; i++) {
      batch.update(ref.doc(rangoIdsEnOrden[i]), {'orden': i});
    }
    await batch.commit();
  }

  // ── Ingresos ─────────────────────────────────────────────────────────────

  Stream<List<Ingreso>> ingresosStream() => _db
      .collection(_colIngresos)
      // Sin orderBy: en Flutter web los documentos con serverTimestamp pendiente
      // quedan excluidos de queries ordenadas por ese campo hasta que el servidor
      // confirma, retrasando la actualización del inventario. Los widgets ordenan
      // los datos por su cuenta (por día, bloque, cliente, etc.).
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
    bool esRemanente = false,
    int bloqueNro = 1,
  }) {
    // Fire-and-forget: con persistencia offline activa el dato queda en el
    // caché local de forma inmediata y el stream lo refleja al instante.
    // No hay que esperar el ACK del servidor para desbloquear el formulario.
    // Si el servidor termina rechazando la escritura (permisos, red), se
    // reporta por `writeErrors` en vez de desaparecer en silencio.
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
      if (esRemanente) 'esRemanente': true,
      'bloqueNro': bloqueNro,
    }).then((_) {}, onError: (e) => _reportWriteError('el ingreso', e));
    return Future.value();
  }

  Future<void> updateIngreso(
    String id, {
    required int canastillas,
    required double peso,
    required bool esCola,
    required int unidades,
    String? clienteId,
    String? clienteNombre,
    String? rangoId,
    String? rangoNombre,
  }) =>
      _db.collection(_colIngresos).doc(id).update({
        'canastillas': canastillas,
        'peso': peso,
        'esCola': esCola,
        'unidades': unidades,
        if (clienteId != null) 'clienteId': clienteId,
        if (clienteNombre != null) 'clienteNombre': clienteNombre,
        if (rangoId != null) 'rangoId': rangoId,
        if (rangoNombre != null) 'rangoNombre': rangoNombre,
      });

  Future<void> deleteIngreso(String id) =>
      _db.collection(_colIngresos).doc(id).delete();

  // ── Salidas ──────────────────────────────────────────────────────────────

  Stream<List<Salida>> salidasStream() => _db
      .collection(_colSalidas)
      // Sin orderBy: misma razón que ingresosStream (serverTimestamp pendiente
      // excluye documentos de queries ordenadas en Flutter web).
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
  }) {
    // Fire-and-forget: mismo patron que addIngreso (ver comentario ahí).
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
    }).then((_) {}, onError: (e) => _reportWriteError('la salida', e));
    return Future.value();
  }

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
    required String plancha,
    required double capacidadKg,
  }) =>
      _db.collection(_colVehiculos).add({
        'placa': placa.toUpperCase().trim(),
        'plancha': plancha.trim(),
        'capacidadKg': capacidadKg,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> updateVehiculo(
    String id, {
    required String placa,
    required String plancha,
    required double capacidadKg,
  }) =>
      _db.collection(_colVehiculos).doc(id).update({
        'placa': placa.toUpperCase().trim(),
        'plancha': plancha.trim(),
        'capacidadKg': capacidadKg,
      });

  // ── Conductores ──────────────────────────────────────────────────────────

  Stream<List<Conductor>> conductoresStream() => _db
      .collection(_colConductores)
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs
          .map(Conductor.fromDoc)
          .where((c) => c.activo)
          .toList());

  Future<void> addConductor({
    required String nombre,
    required String cedula,
  }) =>
      _db.collection(_colConductores).add({
        'nombre': nombre.trim(),
        'cedula': cedula.trim(),
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });

  Future<void> updateConductor(
    String id, {
    required String nombre,
    required String cedula,
  }) =>
      _db.collection(_colConductores).doc(id).update({
        'nombre': nombre.trim(),
        'cedula': cedula.trim(),
      });

  Future<void> deleteConductor(String id) =>
      _db.collection(_colConductores).doc(id).update({'activo': false});

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

  /// Lee el documento de configuración de empresa directamente del servidor
  /// (sin pasar por el StreamProvider global). Usar al abrir pantallas de
  /// edición para evitar mostrar datos vacíos si el stream aún no entregó
  /// su primer valor.
  Future<EmpresaConfig> getEmpresaConfigOnce() async {
    final doc = await _db.collection('config').doc('empresa').get();
    return doc.exists ? EmpresaConfig.fromDoc(doc) : EmpresaConfig.empty();
  }

  Future<void> updateEmpresaConfig(EmpresaConfig config) => _db
      .collection('config')
      .doc('empresa')
      .set(config.toMap(), SetOptions(merge: true));

  Future<void> updateEmpresaField(String field, dynamic value) =>
      _db.collection('config').doc('empresa').update({field: value});

  /// Genera un nuevo código de eliminación numérico (4 dígitos) si el
  /// guardado corresponde a un día anterior. Idempotente entre dispositivos
  /// vía transacción (igual patrón que [resetCiclo]).
  Future<void> regenerarCodigoEliminacionSiNecesario() async {
    final ref = _db.collection('config').doc('empresa');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final hoy = DateTime.now();
      DateTime? fechaCodigo;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final f = data['codigoEliminacionFecha'];
        if (f is Timestamp) fechaCodigo = f.toDate();
      }
      final esDeHoy = fechaCodigo != null &&
          fechaCodigo.year == hoy.year &&
          fechaCodigo.month == hoy.month &&
          fechaCodigo.day == hoy.day;
      if (esDeHoy) return; // Ya se generó uno hoy (este u otro dispositivo).

      final nuevoCodigo = (1000 + Random().nextInt(9000)).toString();
      tx.set(
        ref,
        {
          'codigoEliminacion': nuevoCodigo,
          'codigoEliminacionFecha': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  // ── Ciclo de producción ───────────────────────────────────────────────────

  Stream<CicloConfig> cicloConfigStream() => _db
      .collection('config')
      .doc('ciclo')
      .snapshots()
      // Se incluyen escrituras pendientes (hasPendingWrites=true): cuando
      // FieldValue.serverTimestamp() está en vuelo, fromDoc devuelve
      // DateTime.now() en lugar de DateTime(2000), por lo que el inventario
      // queda en cero correctamente y no se produce el loop de auto-reset.
      .map((doc) =>
          doc.exists ? CicloConfig.fromDoc(doc) : CicloConfig.initial());

  /// Inicia un nuevo ciclo: a partir de este momento el inventario
  /// visible empieza desde cero. Los registros anteriores se conservan.
  ///
  /// Usa una transacción para garantizar idempotencia: si el ciclo ya fue
  /// reiniciado hoy (por otro dispositivo que ganó la carrera), esta llamada
  /// no sobreescribe — así se evita la cascada de cicloIds cuando varios
  /// dispositivos detectan el cambio de día simultáneamente.
  Future<void> resetCiclo() async {
    final ref = _db.collection('config').doc('ciclo');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final inicio = data['inicio'];
        if (inicio is Timestamp) {
          final dt = inicio.toDate();
          final hoy = DateTime.now();
          if (dt.year == hoy.year &&
              dt.month == hoy.month &&
              dt.day == hoy.day) {
            return; // Ya reiniciado hoy por otro dispositivo; no hacer nada.
          }
        }
      }
      tx.set(ref, {
        'inicio': FieldValue.serverTimestamp(),
        'cicloId': const Uuid().v4(),
      });
    });
  }

  /// Reinicia el ciclo Y crea ingresos remanente en una sola operación atómica.
  /// [items] son los registros de producto que se trasladan al nuevo ciclo.
  Future<void> resetCicloConRemanente(
      List<({
        String clienteId,
        String clienteNombre,
        String rangoId,
        String rangoNombre,
        String rangoTipo,
        int canastillas,
        int unidades,
        double peso,
        bool esCola,
      })> items) async {
    final batch = _db.batch();
    batch.set(_db.collection('config').doc('ciclo'), {
      'inicio': FieldValue.serverTimestamp(),
      'cicloId': const Uuid().v4(),
    });
    for (final item in items) {
      final ref = _db.collection(_colIngresos).doc();
      batch.set(ref, {
        'clienteId': item.clienteId,
        'clienteNombre': item.clienteNombre,
        'rangoId': item.rangoId,
        'rangoNombre': item.rangoNombre,
        'rangoTipo': item.rangoTipo,
        'canastillas': item.canastillas,
        'unidades': item.unidades,
        'peso': item.peso,
        'esCola': item.esCola,
        'esRemanente': true,
        'timestamp': FieldValue.serverTimestamp(),
        if (_creadoPor.isNotEmpty) 'creadoPor': _creadoPor,
      });
    }
    await batch.commit();
  }

  /// Elimina TODOS los documentos de cf_ingresos y cf_salidas, y reinicia
  /// el ciclo. Usar solo para limpiar datos de prueba.
  /// Trabaja en lotes de 400 para respetar el límite de 500 ops por batch.
  Future<void> limpiarDatosPrueba() async {
    for (final col in [_colIngresos, _colSalidas]) {
      QuerySnapshot snap;
      do {
        snap = await _db.collection(col).limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (snap.docs.length == 400);
    }
    // Reiniciar el ciclo al momento actual
    await resetCiclo();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int calcularUnidades(bool esCola, int inputValue, double mult) {
    if (esCola) return inputValue;
    return (inputValue * mult).round();
  }
}
