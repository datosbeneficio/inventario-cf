import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/services/firestore_service.dart';
import 'shared/utils/constants.dart';
import 'shared/screens/login_screen.dart';
import 'modules/cuarto_frio/screens/coordinador/coordinador_home.dart';
import 'modules/cuarto_frio/screens/encargado/encargado_home.dart';
import 'modules/cuarto_frio/screens/supervisor/supervisor_home.dart';
import 'modules/cuarto_frio/screens/supervisor_menudencias/supervisor_menudencias_home.dart';

class InventarioCfApp extends StatefulWidget {
  const InventarioCfApp({super.key});

  @override
  State<InventarioCfApp> createState() => _InventarioCfAppState();
}

class _InventarioCfAppState extends State<InventarioCfApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _writeErrorSub;

  @override
  void initState() {
    super.initState();
    // Escrituras "fire-and-forget" (addIngreso/addSalida) que terminan
    // rechazadas por el servidor se notifican aquí en vez de desaparecer
    // en silencio (ver firestore_service.dart).
    _writeErrorSub = FirestoreService.instance.writeErrors.listen((msg) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    });
  }

  @override
  void dispose() {
    _writeErrorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario CF',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          // Muestra spinner mientras Firebase Auth resuelve el estado inicial
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.isLoggedIn) return const LoginScreen();
          return switch (auth.role) {
            kRolCoordinador => const CoordinadorHome(),
            kRolEncargado => const EncargadoHome(),
            kRolSupervisor => const SupervisorHome(),
            kRolSupervisorMenudencias => const SupervisorMenudenciasHome(),
            _ => const LoginScreen(),
          };
        },
      ),
    );
  }
}
