import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/salida.dart';
import '../../models/cliente.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/menudencias_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/inventario_panel.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class SupervisorHome extends StatefulWidget {
  const SupervisorHome({super.key});

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
  int _tab = 0;

  static const _titles = [
    'Inventario Actual',
    'Despacho Aves',
    'Despacho Menudencias',
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
          _DespachoAvesTab(),
          _DespachoMenudenciasTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.set_meal), label: 'Aves'),
          NavigationDestination(
              icon: Icon(Icons.restaurant), label: 'Menudencias'),
        ],
      ),
    );
  }
}

// ── Despacho Aves ──────────────────────────────────────────────────────────

class _DespachoAvesTab extends StatelessWidget {
  const _DespachoAvesTab();

  @override
  Widget build(BuildContext context) {
    final todasSalidas = context.watch<List<Salida>>();
    final salidas = _porFechaYTipo(todasSalidas, DateTime.now(), kTipoAves);

    return LayoutBuilder(builder: (ctx, constraints) {
      final form = _AvesFormPanel();
      final list = _ListaSalidas(salidas: salidas, tipo: kTipoAves);
      if (constraints.maxWidth >= 700) {
        return Row(children: [
          SizedBox(width: 380, child: form),
          const VerticalDivider(width: 1),
          Expanded(child: list),
        ]);
      }
      return Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: form),
        const Divider(),
        Expanded(child: list),
      ]);
    });
  }
}

class _AvesFormPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Despacho — Aves en Canal',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          EntradaForm(
            submitLabel: 'Registrar Salida',
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
                FirestoreService.instance.addSalida(
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

// ── Despacho Menudencias ───────────────────────────────────────────────────

class _DespachoMenudenciasTab extends StatelessWidget {
  const _DespachoMenudenciasTab();

  @override
  Widget build(BuildContext context) {
    final todasSalidas = context.watch<List<Salida>>();
    final salidas =
        _porFechaYTipo(todasSalidas, DateTime.now(), kTipoMenudencias);

    return LayoutBuilder(builder: (ctx, constraints) {
      final form = _MenudFormPanel();
      final list = _ListaSalidas(salidas: salidas, tipo: kTipoMenudencias);
      if (constraints.maxWidth >= 700) {
        return Row(children: [
          SizedBox(width: 380, child: form),
          const VerticalDivider(width: 1),
          Expanded(child: list),
        ]);
      }
      return Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: form),
        const Divider(),
        Expanded(child: list),
      ]);
    });
  }
}

class _MenudFormPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Despacho — Menudencias',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          MenudenciasForm(
            submitLabel: 'Registrar Salida',
            onSubmit: ({
              required clienteId,
              required clienteNombre,
              required rangoId,
              required rangoNombre,
              required canastillas,
              required peso,
            }) =>
                FirestoreService.instance.addSalida(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              rangoId: rangoId,
              rangoNombre: rangoNombre,
              rangoTipo: kTipoMenudencias,
              canastillas: canastillas,
              peso: peso,
              esCola: false,
              unidades: canastillas,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de salidas compartida ────────────────────────────────────────────

class _ListaSalidas extends StatelessWidget {
  final List<Salida> salidas;
  final String tipo;
  const _ListaSalidas({required this.salidas, required this.tipo});

  @override
  Widget build(BuildContext context) {
    if (salidas.isEmpty) {
      return const Center(child: Text('Sin salidas hoy'));
    }

    final esAves = tipo == kTipoAves;
    final total = esAves
        ? salidas.fold(0, (s, i) => s + i.unidades)
        : salidas.fold(0, (s, i) => s + i.canastillas);
    final totalLabel = esAves ? 'unid.' : 'canast.';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Salidas de hoy (${salidas.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Total: ${formatNum(total)} $totalLabel',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: salidas.length,
            itemBuilder: (ctx, i) {
              final salida = salidas[i];
              return MovimientoTile(
                rangoNombre: salida.rangoNombre,
                clienteNombre: salida.clienteNombre.isNotEmpty
                    ? salida.clienteNombre
                    : null,
                unidades: esAves ? salida.unidades : salida.canastillas,
                peso: salida.peso,
                esCola: salida.esCola,
                canastillas: salida.canastillas,
                timestamp: salida.timestamp,
                onEdit: () => _showEditDialog(context, salida, tipo),
                onDelete: () async {
                  final label = esAves
                      ? '${salida.rangoNombre} — ${formatNum(salida.unidades)} unid.'
                      : '${salida.rangoNombre} — ${formatNum(salida.canastillas)} canast.';
                  final ok = await showConfirmDelete(ctx, label);
                  if (ok) FirestoreService.instance.deleteSalida(salida.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Salida salida, String tipo) {
    final clientes = context.read<List<Cliente>>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar salida'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Provider<List<Cliente>>.value(
              value: clientes,
              child: tipo == kTipoMenudencias
                  ? MenudenciasForm(
                      submitLabel: 'Guardar cambios',
                      initialClienteId: salida.clienteId,
                      initialRangoId: salida.rangoId,
                      initialCanastillas: salida.canastillas,
                      initialPeso: salida.peso,
                      onSubmit: ({
                        required clienteId,
                        required clienteNombre,
                        required rangoId,
                        required rangoNombre,
                        required canastillas,
                        required peso,
                      }) async {
                        await FirestoreService.instance.updateSalida(
                          salida.id,
                          canastillas: canastillas,
                          peso: peso,
                          esCola: false,
                          unidades: canastillas,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    )
                  : EntradaForm(
                      submitLabel: 'Guardar cambios',
                      initialClienteId: salida.clienteId,
                      initialRangoId: salida.rangoId,
                      initialInputValue:
                          salida.esCola ? salida.unidades : salida.canastillas,
                      initialPeso: salida.peso,
                      initialEsCola: salida.esCola,
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
                        await FirestoreService.instance.updateSalida(
                          salida.id,
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

// ── Helpers ────────────────────────────────────────────────────────────────

List<Salida> _porFechaYTipo(
    List<Salida> todas, DateTime fecha, String tipo) {
  return todas
      .where((s) =>
          s.rangoTipo == tipo &&
          s.timestamp.year == fecha.year &&
          s.timestamp.month == fecha.month &&
          s.timestamp.day == fecha.day)
      .toList();
}
