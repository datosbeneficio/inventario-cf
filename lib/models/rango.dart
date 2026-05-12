import 'package:hive/hive.dart';
part 'rango.g.dart';

@HiveType(typeId: 0)
class Rango extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String nombre;

  @HiveField(2)
  late double multiplicador;

  @HiveField(3)
  late bool activo;

  @HiveField(4)
  late DateTime creadoEn;
}
