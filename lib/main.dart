import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'models/cliente.dart';
import 'models/ingreso.dart';
import 'models/salida.dart';
import 'models/vehiculo.dart';
import 'models/destino.dart';
import 'models/despacho.dart';
import 'models/empresa_config.dart';
import 'providers/auth_provider.dart';
import 'services/firestore_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        StreamProvider<List<Cliente>>(
          create: (_) => FirestoreService.instance.clientesStream(),
          initialData: const [],
        ),
        StreamProvider<List<Ingreso>>(
          create: (_) => FirestoreService.instance.ingresosStream(),
          initialData: const [],
        ),
        StreamProvider<List<Salida>>(
          create: (_) => FirestoreService.instance.salidasStream(),
          initialData: const [],
        ),
        StreamProvider<List<Vehiculo>>(
          create: (_) => FirestoreService.instance.vehiculosStream(),
          initialData: const [],
        ),
        StreamProvider<List<Destino>>(
          create: (_) => FirestoreService.instance.destinosStream(),
          initialData: const [],
        ),
        StreamProvider<List<Despacho>>(
          create: (_) => FirestoreService.instance.despachosStream(),
          initialData: const [],
        ),
        StreamProvider<EmpresaConfig>(
          create: (_) => FirestoreService.instance.empresaConfigStream(),
          initialData: EmpresaConfig.empty(),
        ),
      ],
      child: const InventarioCfApp(),
    ),
  );
}
