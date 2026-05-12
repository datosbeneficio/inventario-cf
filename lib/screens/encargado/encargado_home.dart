import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../models/ingreso.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';

class EncargadoHome extends StatelessWidget {
  const EncargadoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encargado Cuarto Frío'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: const _EncargadoBody(),
    );
  }
}

class _EncargadoBody extends StatefulWidget {
  const _EncargadoBody();

  @override
  State<_EncargadoBody> createState() => _EncargadoBodyState();
}

class _EncargadoBodyState extends State<_EncargadoBody> {
  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    final ingresosProvider = context.watch<IngresosProvider>();
    final hoy = ingresosProvider.porFecha(DateTime.now());

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              SizedBox(
                width: 380,
                child: _FormPanel(rangos: rangos),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _ListaIngresos(ingresos: hoy)),
            ],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _FormPanel(rangos: rangos),
            ),
            const Divider(),
            Expanded(child: _ListaIngresos(ingresos: hoy)),
          ],
        );
      },
    );
  }
}

class _FormPanel extends StatelessWidget {
  final List rangos;
  const _FormPanel({required this.rangos});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<IngresosProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar Ingreso',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          EntradaForm(
            rangos: rangos.cast(),
            submitLabel: 'Registrar Ingreso',
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

class _ListaIngresos extends StatelessWidget {
  final List<Ingreso> ingresos;
  const _ListaIngresos({required this.ingresos});

  @override
  Widget build(BuildContext context) {
    final rangosProvider = context.watch<RangosProvider>();
    final provider = context.read<IngresosProvider>();

    if (ingresos.isEmpty) {
      return const Center(child: Text('Sin ingresos hoy'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Ingresos de hoy (${ingresos.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                'Total: ${formatNum(ingresos.fold(0, (s, i) => s + i.unidades))} unid.',
                style: const TextStyle(fontSize: 13),
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
              return MovimientoTile(
                rangoNombre: rango?.nombre ?? 'Rango eliminado',
                unidades: ingreso.unidades,
                peso: ingreso.peso,
                esCola: ingreso.esCola,
                canastillas: ingreso.canastillas,
                timestamp: ingreso.timestamp,
                onEdit: () => _showEditDialog(context, ingreso, rango?.multiplicador ?? 1),
                onDelete: () async {
                  final ok = await showConfirmDelete(
                      ctx, '${rango?.nombre ?? ''} - ${formatNum(ingreso.unidades)} unid.');
                  if (ok) provider.eliminar(ingreso.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Ingreso ingreso, double multiplicador) {
    final rangosProvider = context.read<RangosProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ingreso'),
        content: SizedBox(
          width: 360,
          child: EntradaForm(
            rangos: rangosProvider.activos,
            submitLabel: 'Guardar cambios',
            initialRangoId: ingreso.rangoId,
            initialInputValue: ingreso.esCola ? ingreso.unidades : ingreso.canastillas,
            initialPeso: ingreso.peso,
            initialEsCola: ingreso.esCola,
            onSubmit: ({
              required rangoId,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
            }) async {
              await context.read<IngresosProvider>().editar(
                    ingreso.id,
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
