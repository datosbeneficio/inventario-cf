import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../widgets/consolidado_panel.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../widgets/menudencias_form.dart';
import '../../widgets/inventario_panel.dart';
import '../../widgets/historial_ingresos_panel.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/calculadora_dialog.dart';
import '../../../../shared/widgets/connectivity_icon.dart';
import '../../../../shared/widgets/delete_guard_button.dart';
import '../../../../shared/utils/constants.dart';

class SupervisorMenudenciasHome extends StatefulWidget {
  const SupervisorMenudenciasHome({super.key});

  @override
  State<SupervisorMenudenciasHome> createState() =>
      _SupervisorMenudenciasHomeState();
}

class _SupervisorMenudenciasHomeState
    extends State<SupervisorMenudenciasHome> {
  int _tab = 0;
  int _bloqueActual = 1;

  static const _titles = [
    'Inventario Menudencias',
    'Registrar Ingreso',
    'Registros',
    'Consolidado',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarBloque());
  }

  void _sincronizarBloque() {
    if (!mounted) return;
    final hoy = DateTime.now();
    final ingresos = context.read<List<Ingreso>>();
    int max = 1;
    for (final i in ingresos) {
      if (i.rangoTipo == kTipoMenudencias &&
          i.timestamp.year == hoy.year &&
          i.timestamp.month == hoy.month &&
          i.timestamp.day == hoy.day) {
        if (i.bloqueNro > max) max = i.bloqueNro;
      }
    }
    if (max != _bloqueActual) setState(() => _bloqueActual = max);
  }

  void _nuevoBloque() {
    setState(() => _bloqueActual++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bloque $_bloqueActual iniciado'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          const ConnectivityIcon(),
          const AppLogo(),
          const DeleteGuardButton(),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculadora',
            onPressed: () => showCalculadora(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const InventarioPanel(soloTipo: kTipoMenudencias),
          // Tab Registrar: solo el formulario, sin lista al lado
          _FormTab(
            bloqueActual: _bloqueActual,
            onNuevoBloque: _nuevoBloque,
          ),
          // Tab Registros: historial + hoy, con edición y borrado protegido
          const HistorialIngresosPanel(
            rangoTipo: kTipoMenudencias,
            incluirHoy: true,
            showEdit: true,
          ),
          const ConsolidadoPanel(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Inventario'),
          NavigationDestination(
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box),
              label: 'Registrar'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Registros'),
          NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Consolidado'),
        ],
      ),
    );
  }
}

// ── Tab de registro: solo el formulario ──────────────────────────────────────

class _FormTab extends StatelessWidget {
  final int bloqueActual;
  final VoidCallback onNuevoBloque;

  const _FormTab({
    required this.bloqueActual,
    required this.onNuevoBloque,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de bloque activo
          Row(
            children: [
              Chip(
                avatar: Icon(Icons.workspaces_outlined,
                    size: 14, color: cs.onTertiaryContainer),
                label: Text(
                  'Bloque $bloqueActual en curso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                backgroundColor: cs.tertiaryContainer,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_box_outlined, size: 16),
                label: const Text('Nuevo bloque'),
                onPressed: onNuevoBloque,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Registrar Ingreso — Menudencias',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          MenudenciasForm(
            submitLabel: 'Registrar Ingreso',
            onSubmit: ({
              required clienteId,
              required clienteNombre,
              required rangoId,
              required rangoNombre,
              required canastillas,
              required unidades,
              required peso,
            }) =>
                FirestoreService.instance.addIngreso(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              rangoId: rangoId,
              rangoNombre: rangoNombre,
              rangoTipo: kTipoMenudencias,
              canastillas: canastillas,
              peso: peso,
              esCola: false,
              unidades: unidades,
              bloqueNro: bloqueActual,
            ),
          ),
        ],
      ),
    );
  }
}
