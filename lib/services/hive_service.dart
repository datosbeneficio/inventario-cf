import 'package:hive_flutter/hive_flutter.dart';
import '../models/rango.dart';
import '../models/ingreso.dart';
import '../models/salida.dart';
import '../utils/constants.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(RangoAdapter());
    Hive.registerAdapter(IngresoAdapter());
    Hive.registerAdapter(SalidaAdapter());
    await Hive.openBox<Rango>(kBoxRangos);
    await Hive.openBox<Ingreso>(kBoxIngresos);
    await Hive.openBox<Salida>(kBoxSalidas);
  }
}
