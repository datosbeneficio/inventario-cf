import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/salidas_provider.dart';
import '../../providers/clientes_provider.dart';
import '../../models/salida.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/menudencias_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/inventario_por_rango_card.dart';
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
          _InventarioTab(),
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
          NavigationDestination(
              icon: Icon(Icons.set_meal), label: 'Aves'),
          NavigationDestination(
              icon: Icon(Icons.restaurant), label: 'Menudencias'),
        ],
      ),
    );
  }
}

// ── Inventario ─────────────────────────────────────────────────────────────

class _InventarioTab extends StatelessWidget {
  const _InventarioTab();

  @override
  Widget build(BuildContext context) {
    final rangosAves = context.watch<RangosProvider>().activosAves;
    final rangosMenud = context.watch<RangosProvider>().activosMenudencias;
    final ingresosP = context.watch<IngresosProvider>();
    final salidasP = context.watch<SalidasProvider>();

    if (rangosAves.isEmpty && rangosMenud.isEmpty) {
      return const Center(child: Text('No hay rangos configurados'));
    }

    Widget buildSection(List rangos, String titulo, String tipo) {
      if (rangos.isEmpty) return const SizedBox.shrink();
      final cs = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  tipo == kTipoAves ? Icons.set_meal : Icons.restaurant,
                  size: 16,
                  color: tipo == kTipoAves ? cs.primary : cs.tertiary,
                ),
                const SizedBox(width: 6),
                Text(titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tipo == kTipoAves ? cs.primary : cs.tertiary,
                    )),
              ],
            ),
          ),
          ...rangos.map((rango) {
            final totalIn = ingresosP
                .porRango(rango.id)
                .fold(0, (s, e) => s + e.unidades);
            final totalOut = salidasP
                .porRango(rango.id)
                .fold(0, (s, e) => s + e.unidades);
            final pesoIn = ingresosP
                .porRango(rango.id)
                .fold(0.0, (s, e) => s + e.peso);
            final pesoOut = salidasP
                .porRango(rango.id)
                .fold(0.0, (s, e) => s + e.peso);
            return InventarioPorRangoCard(
              nombre: rango.nombre,
              unidades: totalIn - totalOut,
              peso: pesoIn - pesoOut,
            );
          }),
        ],
      );
    }

    return ListView(
      children: [
        buildSection(rangosAves, 'Aves en Canal', kTipoAves),
        buildSection(rangosMenud, 'Menudencias', kTipoMenudencias),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Despacho Aves ──────────────────────────────────────────────────────────

class _DespachoAvesTab extends StatelessWidget {
  const _DespachoAvesTab();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activosAves;
    final clientes = context.watch<ClientesProvider>().activos;
    final salidasProvider = context.watch<SalidasProvider>();
    final salidas = salidasProvider
        .porFecha(DateTime.now())
        .where((s) {
          final rango = context.read<RangosProvider>().porId(s.rangoId);
          return rango?.esAves ?? true;
        })
        .toList();

    return LayoutBuilder(builder: (ctx, constraints) {
      final form = _SalidaAvesPanel(rangos: rangos, clientes: clientes);
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

class _SalidaAvesPanel extends StatelessWidget {
  final List rangos;
  final List clientes;
  const _SalidaAvesPanel({required this.rangos, required this.clientes});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SalidasProvider>();
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
            rangos: rangos.cast(),
            clientes: clientes.cast(),
            submitLabel: 'Registrar Salida',
            onSubmit: ({
              required rangoId,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
              clienteId,
            }) =>
                provider.registrar(
              rangoId: rangoId,
              inputValue: inputValue,
              peso: peso,
              esCola: esCola,
              multiplicador: multiplicador,
              clienteId: clienteId,
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
    final rangos = context.watch<RangosProvider>().activosMenudencias;
    final clientes = context.watch<ClientesProvider>().activos;
    final salidasProvider = context.watch<SalidasProvider>();
    final salidas = salidasProvider
        .porFecha(DateTime.now())
        .where((s) {
          final rango = context.read<RangosProvider>().porId(s.rangoId);
          return rango?.esMenudencias ?? false;
        })
        .toList();

    return LayoutBuilder(builder: (ctx, constraints) {
      final form = _SalidaMenudPanel(rangos: rangos, clientes: clientes);
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

class _SalidaMenudPanel extends StatelessWidget {
  final List rangos;
  final List clientes;
  const _SalidaMenudPanel({required this.rangos, required this.clientes});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SalidasProvider>();
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
            rangos: rangos.cast(),
            clientes: clientes.cast(),
            submitLabel: 'Registrar Salida',
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

// ── Lista salidas compartida ───────────────────────────────────────────────

class _ListaSalidas extends StatelessWidget {
  final List<Salida> salidas;
  final String tipo;
  const _ListaSalidas({required this.salidas, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final rangosProvider = context.watch<RangosProvider>();
    final clientesProvider = context.watch<ClientesProvider>();
    final provider = context.read<SalidasProvider>();

    if (salidas.isEmpty) {
      return const Center(child: Text('Sin salidas hoy'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Salidas de hoy (${salidas.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                'Total: ${formatNum(salidas.fold(0, (s, i) => s + i.unidades))} unid.',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: salidas.length,
            itemBuilder: (ctx, i) {
              final salida = salidas[i];
              final rango = rangosProvider.porId(salida.rangoId);
              final cliente = salida.clienteId != null
                  ? clientesProvider.porId(salida.clienteId!)
                  : null;
              return MovimientoTile(
                rangoNombre: rango?.nombre ?? 'Rango eliminado',
                clienteNombre: cliente?.nombre,
                unidades: salida.unidades,
                peso: salida.peso,
                esCola: salida.esCola,
                canastillas: salida.canastillas,
                timestamp: salida.timestamp,
                onEdit: () => _showEditDialog(
                    context, salida, rango?.multiplicador ?? 1, tipo),
                onDelete: () async {
                  final ok = await showConfirmDelete(ctx,
                      '${rango?.nombre ?? ''} - ${formatNum(salida.unidades)} unid.');
                  if (ok) provider.eliminar(salida.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(
      BuildContext context, Salida salida, double multiplicador, String tipo) {
    final rangosProvider = context.read<RangosProvider>();
    final clientesProvider = context.read<ClientesProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar salida'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: tipo == kTipoMenudencias
                ? MenudenciasForm(
                    rangos: rangosProvider.activosMenudencias,
                    clientes: clientesProvider.activos,
                    submitLabel: 'Guardar cambios',
                    initialRangoId: salida.rangoId,
                    initialCanastillas: salida.canastillas,
                    initialPeso: salida.peso,
                    initialClienteId: salida.clienteId,
                    onSubmit: ({
                      required rangoId,
                      required canastillas,
                      required peso,
                      clienteId,
                    }) async {
                      await context.read<SalidasProvider>().editar(
                            salida.id,
                            inputValue: canastillas,
                            peso: peso,
                            esCola: false,
                            multiplicador: 1,
                            clienteId: clienteId,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  )
                : EntradaForm(
                    rangos: rangosProvider.activosAves,
                    clientes: clientesProvider.activos,
                    submitLabel: 'Guardar cambios',
                    initialRangoId: salida.rangoId,
                    initialInputValue:
                        salida.esCola ? salida.unidades : salida.canastillas,
                    initialPeso: salida.peso,
                    initialEsCola: salida.esCola,
                    initialClienteId: salida.clienteId,
                    onSubmit: ({
                      required rangoId,
                      required inputValue,
                      required peso,
                      required esCola,
                      required multiplicador,
                      clienteId,
                    }) async {
                      await context.read<SalidasProvider>().editar(
                            salida.id,
                            inputValue: inputValue,
                            peso: peso,
                            esCola: esCola,
                            multiplicador: multiplicador,
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
