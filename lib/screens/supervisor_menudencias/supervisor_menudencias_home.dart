import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/clientes_provider.dart';
import '../../models/ingreso.dart';
import '../../widgets/menudencias_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';

class SupervisorMenudenciasHome extends StatelessWidget {
  const SupervisorMenudenciasHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Menudencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activosMenudencias;
    final clientes = context.watch<ClientesProvider>().activos;
    final ingresosProvider = context.watch<IngresosProvider>();

    // Only show menudencias entries (rangos de menudencias)
    final rangosMenudIds =
        context.read<RangosProvider>().activosMenudencias.map((r) => r.id).toSet();
    final hoy = ingresosProvider
        .porFecha(DateTime.now())
        .where((i) => rangosMenudIds.contains(i.rangoId))
        .toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final form = _FormPanel(rangos: rangos, clientes: clientes);
        final list = _ListaIngresos(ingresos: hoy);
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
      },
    );
  }
}

class _FormPanel extends StatelessWidget {
  final List rangos;
  final List clientes;
  const _FormPanel({required this.rangos, required this.clientes});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<IngresosProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar Ingreso — Menudencias',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          MenudenciasForm(
            rangos: rangos.cast(),
            clientes: clientes.cast(),
            submitLabel: 'Registrar Ingreso',
            onSubmit: ({
              required rangoId,
              required canastillas,
              required peso,
              clienteId,
            }) =>
                provider.registrar(
              rangoId: rangoId,
              inputValue: canastillas,
              peso: peso,
              esCola: false,
              multiplicador: 1,
              clienteId: clienteId,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaIngresos extends StatelessWidget {
  final List<Ingreso> ingresos;
  const _ListaIngresos({required this.ingresos});

  @override
  Widget build(BuildContext context) {
    final rangosProvider = context.watch<RangosProvider>();
    final clientesProvider = context.watch<ClientesProvider>();
    final provider = context.read<IngresosProvider>();

    if (ingresos.isEmpty) {
      return const Center(child: Text('Sin ingresos de menudencias hoy'));
    }

    final totalCanastillas = ingresos.fold(0, (s, i) => s + i.canastillas);
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
                  Text('${formatNum(totalCanastillas)} canastillas',
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
              final rango = rangosProvider.porId(ingreso.rangoId);
              final cliente = ingreso.clienteId != null
                  ? clientesProvider.porId(ingreso.clienteId!)
                  : null;
              return MovimientoTile(
                rangoNombre: rango?.nombre ?? 'Rango eliminado',
                clienteNombre: cliente?.nombre,
                unidades: ingreso.canastillas,
                peso: ingreso.peso,
                esCola: false,
                canastillas: ingreso.canastillas,
                timestamp: ingreso.timestamp,
                onEdit: () => _showEditDialog(context, ingreso),
                onDelete: () async {
                  final ok = await showConfirmDelete(ctx,
                      '${rango?.nombre ?? ''} - ${formatNum(ingreso.canastillas)} canastillas');
                  if (ok) provider.eliminar(ingreso.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Ingreso ingreso) {
    final rangosProvider = context.read<RangosProvider>();
    final clientesProvider = context.read<ClientesProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ingreso'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: MenudenciasForm(
              rangos: rangosProvider.activosMenudencias,
              clientes: clientesProvider.activos,
              submitLabel: 'Guardar cambios',
              initialRangoId: ingreso.rangoId,
              initialCanastillas: ingreso.canastillas,
              initialPeso: ingreso.peso,
              initialClienteId: ingreso.clienteId,
              onSubmit: ({
                required rangoId,
                required canastillas,
                required peso,
                clienteId,
              }) async {
                await context.read<IngresosProvider>().editar(
                      ingreso.id,
                      inputValue: canastillas,
                      peso: peso,
                      esCola: false,
                      multiplicador: 1,
                      clienteId: clienteId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
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
