import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/despacho.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/inventario_panel.dart';
import 'despacho_detalle_screen.dart';
import 'destinos_screen.dart';
import 'nuevo_despacho_screen.dart';
import 'vehiculos_screen.dart';

class SupervisorHome extends StatefulWidget {
  const SupervisorHome({super.key});

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
  int _tab = 0;

  static const _titles = [
    'Inventario Actual',
    'Nuevo Despacho',
    'Historial de Despachos',
    'Gestión',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
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
          InventarioPanel(),
          NuevoDespachoScreen(),
          _HistorialTab(),
          _GestionTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Despacho',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Gestión',
          ),
        ],
      ),
    );
  }
}

// ── Historial de despachos ─────────────────────────────────────────────────

class _HistorialTab extends StatelessWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context) {
    final despachos = context.watch<List<Despacho>>();

    if (despachos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Text('Sin despachos registrados',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    // Ordenar del más reciente al más antiguo
    final sorted = [...despachos]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _DespachTile(d: sorted[i]),
    );
  }
}

class _DespachTile extends StatelessWidget {
  final Despacho d;
  const _DespachTile({required this.d});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.local_shipping,
              size: 20, color: cs.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Text('Guía N° ${d.guiaNro}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatDate(d.fechaDespacho),
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${d.destinoNombre}  ·  ${d.placa}'),
            Text(
              '${d.lineas.length} línea(s)  ·  '
              '${formatNum(d.totalCanastillas)} canast.  ·  '
              '${formatNum(d.totalPeso)} kg',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DespachoDetalleScreen(despacho: d),
          ),
        ),
      ),
    );
  }
}

// ── Gestión: sub-tabs Vehículos / Destinos ─────────────────────────────────

class _GestionTab extends StatefulWidget {
  const _GestionTab();

  @override
  State<_GestionTab> createState() => _GestionTabState();
}

class _GestionTabState extends State<_GestionTab>
    with SingleTickerProviderStateMixin {
  late final TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _ctrl,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Vehículos'),
            Tab(
                icon: Icon(Icons.location_on_outlined),
                text: 'Destinos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _ctrl,
            children: const [
              VehiculosScreen(),
              DestinosScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
