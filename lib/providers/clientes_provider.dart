import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/cliente.dart';
import '../utils/constants.dart';

class ClientesProvider extends ChangeNotifier {
  Box<Cliente> get _box => Hive.box<Cliente>(kBoxClientes);

  List<Cliente> get all => _box.values.toList();
  List<Cliente> get activos =>
      all.where((c) => c.activo).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

  Future<void> agregar(String nombre) async {
    final cliente = Cliente()
      ..id = const Uuid().v4()
      ..nombre = nombre.trim()
      ..activo = true
      ..creadoEn = DateTime.now();
    await _box.put(cliente.id, cliente);
    notifyListeners();
  }

  Future<void> eliminar(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Cliente? porId(String id) {
    try {
      return _box.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
