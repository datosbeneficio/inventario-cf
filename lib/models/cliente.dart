import 'package:hive/hive.dart';
part 'cliente.g.dart';

@HiveType(typeId: 3)
class Cliente extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String nombre;

  @HiveField(2)
  late bool activo;

  @HiveField(3)
  late DateTime creadoEn;
}
