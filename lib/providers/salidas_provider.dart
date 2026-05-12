import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/salida.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'ingresos_provider.dart';

class SalidasProvider extends ChangeNotifier {
  Box<Salida> get _box => Hive.box<Salida>(kBoxSalidas);

  List<Salida> get all => _box.values.toList();

  Future<void> registrar({
    required String rangoId,
    required int inputValue,
    required double peso,
    required bool esCola,
    required double multiplicador,
    String? clienteId,
  }) async {
    final unidades =
        IngresosProvider.calcularUnidades(esCola, inputValue, multiplicador);
    final salida = Salida()
      ..id = const Uuid().v4()
      ..rangoId = rangoId
      ..canastillas = esCola ? 1 : inputValue
      ..peso = peso
      ..esCola = esCola
      ..unidades = unidades
      ..timestamp = DateTime.now()
      ..clienteId = clienteId;
    await _box.put(salida.id, salida);
    notifyListeners();
  }

  Future<void> editar(
    String id, {
    required int inputValue,
    required double peso,
    required bool esCola,
    required double multiplicador,
    String? clienteId,
  }) async {
    final salida = _box.get(id);
    if (salida == null) return;
    salida
      ..canastillas = esCola ? 1 : inputValue
      ..peso = peso
      ..esCola = esCola
      ..unidades =
          IngresosProvider.calcularUnidades(esCola, inputValue, multiplicador)
      ..clienteId = clienteId;
    await salida.save();
    notifyListeners();
  }

  Future<void> eliminar(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  List<Salida> porFecha(DateTime date) =>
      all.where((s) => isSameDay(s.timestamp, date)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<Salida> porRango(String rangoId) =>
      all.where((s) => s.rangoId == rangoId).toList();

  List<Salida> porCliente(String clienteId) =>
      all.where((s) => s.clienteId == clienteId).toList();

  List<Salida> enRango(DateTime from, DateTime to) =>
      all.where((s) => isInRange(s.timestamp, from, to)).toList();
}
