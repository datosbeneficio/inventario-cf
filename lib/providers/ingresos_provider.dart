import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/ingreso.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class IngresosProvider extends ChangeNotifier {
  Box<Ingreso> get _box => Hive.box<Ingreso>(kBoxIngresos);

  List<Ingreso> get all => _box.values.toList();

  static int calcularUnidades(bool esCola, int inputValue, double multiplicador) {
    if (esCola) return inputValue;
    return (inputValue * multiplicador).round();
  }

  Future<void> registrar({
    required String rangoId,
    required int inputValue,
    required double peso,
    required bool esCola,
    required double multiplicador,
  }) async {
    final unidades = calcularUnidades(esCola, inputValue, multiplicador);
    final ingreso = Ingreso()
      ..id = const Uuid().v4()
      ..rangoId = rangoId
      ..canastillas = esCola ? 1 : inputValue
      ..peso = peso
      ..esCola = esCola
      ..unidades = unidades
      ..timestamp = DateTime.now();
    await _box.put(ingreso.id, ingreso);
    notifyListeners();
  }

  Future<void> editar(
    String id, {
    required int inputValue,
    required double peso,
    required bool esCola,
    required double multiplicador,
  }) async {
    final ingreso = _box.get(id);
    if (ingreso == null) return;
    ingreso
      ..canastillas = esCola ? 1 : inputValue
      ..peso = peso
      ..esCola = esCola
      ..unidades = calcularUnidades(esCola, inputValue, multiplicador);
    await ingreso.save();
    notifyListeners();
  }

  Future<void> eliminar(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  List<Ingreso> porFecha(DateTime date) =>
      all.where((i) => isSameDay(i.timestamp, date)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<Ingreso> porRango(String rangoId) =>
      all.where((i) => i.rangoId == rangoId).toList();

  List<Ingreso> porRangoYRango(DateTime from, DateTime to, String rangoId) =>
      all
          .where((i) =>
              i.rangoId == rangoId && isInRange(i.timestamp, from, to))
          .toList();

  List<Ingreso> enRango(DateTime from, DateTime to) =>
      all.where((i) => isInRange(i.timestamp, from, to)).toList();
}
