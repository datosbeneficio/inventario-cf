import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/salidas_provider.dart';
import '../../models/salida.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/inventario_por_rango_card.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';

class SupervisorHome extends StatefulWidget {
  const SupervisorHome({super.key});

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Despacho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
        bottom: TabBar(
          controller: null,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Inventario'),
            Tab(icon: Icon(Icons.output), text: 'Despacho'),
          ],
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _InventarioTab(),
          _DespachoTab(),
        ],
      ),
    );
  }
}

class _InventarioTab extends StatelessWidget {
  const _InventarioTab();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    final ingresosProvider = context.watch<IngresosProvider>();
    final salidasProvider = context.watch<SalidasProvider>();

    if (rangos.isEmpty) {
      return const Center(child: Text('No hay rangos configurados'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rangos.length,
      itemBuilder: (ctx, i) {
        final rango = rangos[i];
        final totalIn = ingresosProvider
            .porRango(rango.id)
            .fold(0, (s, e) => s + e.unidades);
        final totalOut = salidasProvider
            .porRango(rango.id)
            .fold(0, (s, e) => s + e.unidades);
        final pesoIn = ingresosProvider
            .porRango(rango.id)
            .fold(0.0, (s, e) => s + e.peso);
        final pesoOut = salidasProvider
            .porRango(rango.id)
            .fold(0.0, (s, e) => s + e.peso);

        return InventarioPorRangoCard(
          nombre: rango.nombre,
          unidades: totalIn - totalOut,
          peso: pesoIn - pesoOut,
        );
      },
    );
  }
}

class _DespachoTab extends StatelessWidget {
  const _DespachoTab();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    final salidasProvider = context.watch<SalidasProvider>();
    final salidas = salidasProvider.porFecha(DateTime.now());

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              SizedBox(
                width: 380,
                child: _SalidaFormPanel(rangos: rangos),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _ListaSalidas(salidas: salidas)),
            ],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SalidaFormPanel(rangos: rangos),
            ),
            const Divider(),
            Expanded(child: _ListaSalidas(salidas: salidas)),
          ],
        );
      },
    );
  }
}

class _SalidaFormPanel extends StatelessWidget {
  final List rangos;
  const _SalidaFormPanel({required this.rangos});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SalidasProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar Salida',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          EntradaForm(
            rangos: rangos.cast(),
            submitLabel: 'Registrar Salida',
            onSubmit: ({
              required rangoId,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
            }) =>
                provider.registrar(
              rangoId: rangoId,
              inputValue: inputValue,
              peso: peso,
              esCola: esCola,
              multiplicador: multiplicador,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaSalidas extends StatelessWidget {
  final List<Salida> salidas;
  const _ListaSalidas({required this.salidas});

  @override
  Widget build(BuildContext context) {
    final rangosProvider = context.watch<RangosProvider>();
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
              return MovimientoTile(
                rangoNombre: rango?.nombre ?? 'Rango eliminado',
                unidades: salida.unidades,
                peso: salida.peso,
                esCola: salida.esCola,
                canastillas: salida.canastillas,
                timestamp: salida.timestamp,
                onEdit: () => _showEditDialog(context, salida, rango?.multiplicador ?? 1),
                onDelete: () async {
                  final ok = await showConfirmDelete(
                      ctx, '${rango?.nombre ?? ''} - ${formatNum(salida.unidades)} unid.');
                  if (ok) provider.eliminar(salida.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Salida salida, double multiplicador) {
    final rangosProvider = context.read<RangosProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar salida'),
        content: SizedBox(
          width: 360,
          child: EntradaForm(
            rangos: rangosProvider.activos,
            submitLabel: 'Guardar cambios',
            initialRangoId: salida.rangoId,
            initialInputValue: salida.esCola ? salida.unidades : salida.canastillas,
            initialPeso: salida.peso,
            initialEsCola: salida.esCola,
            onSubmit: ({
              required rangoId,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
            }) async {
              await context.read<SalidasProvider>().editar(
                    salida.id,
                    inputValue: inputValue,
                    peso: peso,
                    esCola: esCola,
                    multiplicador: multiplicador,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
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
