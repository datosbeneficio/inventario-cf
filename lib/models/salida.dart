import 'package:hive/hive.dart';
part 'salida.g.dart';

@HiveType(typeId: 2)
class Salida extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String rangoId;

  @HiveField(2)
  late int canastillas;

  @HiveField(3)
  late double peso;

  @HiveField(4)
  late bool esCola;

  @HiveField(5)
  late int unidades;

  @HiveField(6)
  late DateTime timestamp;

  @HiveField(7)
  String? clienteId;
}
