import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../../../shared/models/cliente.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../widgets/menudencias_form.dart';
import '../../../../shared/widgets/movimiento_tile.dart';
import '../../widgets/inventario_panel.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/utils/constants.dart';
import '../../../../shared/utils/formatters.dart';

class SupervisorMenudenciasHome extends StatefulWidget {
  const SupervisorMenudenciasHome({super.key});

  @override
  State<SupervisorMenudenciasHome> createState() =>
      _SupervisorMenudenciasHomeState();
}

class _SupervisorMenudenciasHomeState
    extends State<SupervisorMenudenciasHome> {
  int _tab = 0;

  static const _titles = ['Inventario Menudencias', 'Registrar Ingreso'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          const AppLogo(),
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
          InventarioPanel(soloTipo: kTipoMenudencias),
          _IngresoMenudBody(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(
              icon: Icon(Icons.add_box), label: 'Registrar'),
        ],
      ),
    );
  }
}

// ── Pestaña registro de ingreso de menudencias ─────────────────────────────

class _IngresoMenudBody extends StatelessWidget {
  const _IngresoMenudBody();

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = todos
        .where((i) =>
            i.rangoTipo == kTipoMenudencias &&
            i.timestamp.year == DateTime.now().year &&
            i.timestamp.month == DateTime.now().month &&
            i.timestamp.day == DateTime.now().day)
        .toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final form = _FormPanel();
        final list = _ListaIngresos(ingresos: hoy);
        if (constraints.maxWidth >= 700) {
          return Row(children: [
            SizedBox(width: 380, child: form),
            const VerticalDivider(width: 1),
            Expanded(child: list),
          ]);
        }
        return Column(children: [
          Expanded(flex: 3, child: form),
          const Divider(),
          Expanded(flex: 2, child: list),
        ]);
      },
    );
  }
}

class _FormPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de ingresos del día ─────────────────────────────────────────────

class _ListaIngresos extends StatelessWidget {
  final List<Ingreso> ingresos;
  const _ListaIngresos({required this.ingresos});

  @override
  Widget build(BuildContext context) {
    if (ingresos.isEmpty) {
      return const Center(child: Text('Sin ingresos de menudencias hoy'));
    }

    final totalCan = ingresos.fold(0, (s, i) => s + i.canastillas);
    final totalPeso = ingresos.fold(0.0, (s, i) => s + i.peso);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Ingresos de hoy (${ingresos.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatNum(totalCan)} canastillas',
                      style: const TextStyle(fontSize: 12)),
                  Text(formatKg(totalPeso),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: ingresos.length,
            itemBuilder: (ctx, i) {
              final ingreso = ingresos[i];
              return MovimientoTile(
                rangoNombre: ingreso.rangoNombre,
                clienteNombre: ingreso.clienteNombre.isNotEmpty
                    ? ingreso.clienteNombre
                    : null,
                unidades: ingreso.unidades,
                peso: ingreso.peso,
                esCola: false,
                canastillas: ingreso.canastillas,
                timestamp: ingreso.timestamp,
                onEdit: () => _showEditDialog(context, ingreso),
                onDelete: () async {
                  final ok = await showConfirmDelete(
                      ctx,
                      '${ingreso.rangoNombre} — '
                      '${formatNum(ingreso.canastillas)} canastillas');
                  if (ok) FirestoreService.instance.deleteIngreso(ingreso.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Ingreso ingreso) {
    final clientes = context.read<List<Cliente>>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ingreso'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Provider<List<Cliente>>.value(
              value: clientes,
              child: MenudenciasForm(
                submitLabel: 'Guardar cambios',
                initialClienteId: ingreso.clienteId,
                initialRangoId: ingreso.rangoId,
                initialCanastillas: ingreso.canastillas,
                initialPeso: ingreso.peso,
                onSubmit: ({
                  required clienteId,
                  required clienteNombre,
                  required rangoId,
                  required rangoNombre,
                  required canastillas,
                  required unidades,
                  required peso,
                }) async {
                  await FirestoreService.instance.updateIngreso(
                    ingreso.id,
                    canastillas: canastillas,
                    peso: peso,
                    esCola: false,
                    unidades: unidades,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
