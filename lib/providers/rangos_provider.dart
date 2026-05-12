import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/rango.dart';
import '../utils/constants.dart';

class RangosProvider extends ChangeNotifier {
  Box<Rango> get _box => Hive.box<Rango>(kBoxRangos);

  List<Rango> get all => _box.values.toList();
  List<Rango> get activos => all.where((r) => r.activo).toList();
  List<Rango> get activosAves =>
      activos.where((r) => r.esAves).toList();
  List<Rango> get activosMenudencias =>
      activos.where((r) => r.esMenudencias).toList();

  Future<void> agregar(String nombre, double multiplicador, String tipo) async {
    final rango = Rango()
      ..id = const Uuid().v4()
      ..nombre = nombre.trim()
      ..multiplicador = multiplicador
      ..activo = true
      ..creadoEn = DateTime.now()
      ..tipo = tipo;
    await _box.put(rango.id, rango);
    notifyListeners();
  }

  Future<void> eliminar(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Rango? porId(String id) {
    try {
      return _box.values.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
