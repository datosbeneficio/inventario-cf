import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/utils/constants.dart';
import 'shared/screens/login_screen.dart';
import 'shared/widgets/offline_banner.dart';
import 'modules/cuarto_frio/screens/coordinador/coordinador_home.dart';
import 'modules/cuarto_frio/screens/encargado/encargado_home.dart';
import 'modules/cuarto_frio/screens/supervisor/supervisor_home.dart';
import 'modules/cuarto_frio/screens/supervisor_menudencias/supervisor_menudencias_home.dart';

class InventarioCfApp extends StatelessWidget {
  const InventarioCfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario CF',
      debugShowCheckedModeBanner: false,
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
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child ?? const SizedBox()),
        ],
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
