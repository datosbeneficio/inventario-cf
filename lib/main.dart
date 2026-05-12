import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/hive_service.dart';
import 'providers/auth_provider.dart';
import 'providers/rangos_provider.dart';
import 'providers/ingresos_provider.dart';
import 'providers/salidas_provider.dart';
import 'providers/clientes_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RangosProvider()),
        ChangeNotifierProvider(create: (_) => IngresosProvider()),
        ChangeNotifierProvider(create: (_) => SalidasProvider()),
        ChangeNotifierProvider(create: (_) => ClientesProvider()),
      ],
      child: const InventarioCfApp(),
    ),
  );
}
