import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/providers/delete_guard_provider.dart';
import 'shared/models/ciclo_config.dart';
import 'shared/models/cliente.dart';
import 'modules/cuarto_frio/models/ingreso.dart';
import 'modules/cuarto_frio/models/salida.dart';
import 'modules/cuarto_frio/models/conductor.dart';
import 'modules/cuarto_frio/models/vehiculo.dart';
import 'modules/cuarto_frio/models/destino.dart';
import 'modules/cuarto_frio/models/despacho.dart';
import 'shared/models/empresa_config.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/services/firestore_service.dart';
import 'shared/services/ciclo_auto_reset_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistencia offline: Firestore guarda una copia local en IndexedDB
  // y encola escrituras para sincronizar al reconectar.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Auto-reset del ciclo: si al abrir la app el ciclo activo corresponde
  // a un día anterior, lo reinicia automáticamente sin intervención del
  // coordinador (fallback por si se olvidó al cerrar el turno).
  CicloAutoResetService.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => DeleteGuardProvider()),
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
        StreamProvider<List<Conductor>>(
          create: (_) => FirestoreService.instance.conductoresStream(),
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
        StreamProvider<CicloConfig>(
          create: (_) => FirestoreService.instance.cicloConfigStream(),
          initialData: CicloConfig.initial(),
        ),
      ],
      child: const InventarioCfApp(),
    ),
  );
}
