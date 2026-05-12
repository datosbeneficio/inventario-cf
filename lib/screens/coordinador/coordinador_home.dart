import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'rangos_screen.dart';
import 'clientes_screen.dart';
import 'reporte_totales_screen.dart';
import 'reporte_rendimiento_screen.dart';

class CoordinadorHome extends StatefulWidget {
  const CoordinadorHome({super.key});

  @override
  State<CoordinadorHome> createState() => _CoordinadorHomeState();
}

class _CoordinadorHomeState extends State<CoordinadorHome> {
  int _tab = 0;

  static const _tabs = [
    _TabInfo(label: 'Rangos', icon: Icons.category, title: 'Gestión de Rangos'),
    _TabInfo(label: 'Clientes', icon: Icons.business, title: 'Clientes'),
    _TabInfo(label: 'Totales', icon: Icons.bar_chart, title: 'Reporte Totales'),
    _TabInfo(label: 'Rendimiento', icon: Icons.trending_up, title: 'Rendimiento'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_tab].title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          RangosScreen(),
          ClientesScreen(),
          ReporteTotalesScreen(),
          ReporteRendimientoScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  final String title;
  const _TabInfo({required this.label, required this.icon, required this.title});
}
