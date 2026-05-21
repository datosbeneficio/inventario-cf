import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../../../shared/models/cliente.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/inventario_panel.dart';
import '../../../../shared/widgets/movimiento_tile.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/calculadora_dialog.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/utils/constants.dart';

class EncargadoHome extends StatefulWidget {
  const EncargadoHome({super.key});

  @override
  State<EncargadoHome> createState() => _EncargadoHomeState();
}

class _EncargadoHomeState extends State<EncargadoHome> {
  int _tab = 0;

  static const _titles = ['Inventario Aves', 'Registrar Ingreso'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          const AppLogo(),
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
        children: const [
          InventarioPanel(soloTipo: kTipoAves),
          _IngresoAvesBody(),
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

// ── Pestaña de registro de ingreso de aves ────────────────────────────────

class _IngresoAvesBody extends StatelessWidget {
  const _IngresoAvesBody();

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = todos
        .where((i) =>
            i.rangoTipo == kTipoAves &&
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

// ── Formulario ────────────────────────────────────────────────────────────

class _FormPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registrar Ingreso',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          EntradaForm(
            submitLabel: 'Registrar Ingreso',
            onSubmit: ({
              required clienteId,
              required clienteNombre,
              required rangoId,
              required rangoNombre,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
            }) =>
                FirestoreService.instance.addIngreso(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              rangoId: rangoId,
              rangoNombre: rangoNombre,
              rangoTipo: kTipoAves,
              canastillas: esCola ? 1 : inputValue,
              peso: peso,
              esCola: esCola,
              unidades: FirestoreService.calcularUnidades(
                  esCola, inputValue, multiplicador),
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
      return const Center(child: Text('Sin ingresos de aves hoy'));
    }

    final totalUnid = ingresos.fold(0, (s, i) => s + i.unidades);
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
                  Text('${formatNum(totalUnid)} unidades',
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
                esCola: ingreso.esCola,
                canastillas: ingreso.canastillas,
                timestamp: ingreso.timestamp,
                onEdit: () => _showEditDialog(context, ingreso),
                onDelete: () async {
                  final ok = await showConfirmDelete(
                      ctx,
                      '${ingreso.rangoNombre} — '
                      '${formatNum(ingreso.unidades)} unid.');
                  if (ok) {
                    FirestoreService.instance.deleteIngreso(ingreso.id);
                  }
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
              child: EntradaForm(
                submitLabel: 'Guardar cambios',
                initialClienteId: ingreso.clienteId,
                initialRangoId: ingreso.rangoId,
                initialInputValue:
                    ingreso.esCola ? ingreso.unidades : ingreso.canastillas,
                initialPeso: ingreso.peso,
                initialEsCola: ingreso.esCola,
                onSubmit: ({
                  required clienteId,
                  required clienteNombre,
                  required rangoId,
                  required rangoNombre,
                  required inputValue,
                  required peso,
                  required esCola,
                  required multiplicador,
                }) async {
                  await FirestoreService.instance.updateIngreso(
                    ingreso.id,
                    canastillas: esCola ? 1 : inputValue,
                    peso: peso,
                    esCola: esCola,
                    unidades: FirestoreService.calcularUnidades(
                        esCola, inputValue, multiplicador),
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
