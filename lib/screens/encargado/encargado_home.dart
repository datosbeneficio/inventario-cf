import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../models/cliente.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/movimiento_tile.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

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

class _EncargadoBody extends StatelessWidget {
  const _EncargadoBody();

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = _porFecha(todos, DateTime.now());

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              SizedBox(width: 380, child: _FormPanel()),
              const VerticalDivider(width: 1),
              Expanded(child: _ListaIngresos(ingresos: hoy)),
            ],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _FormPanel(),
            ),
            const Divider(),
            Expanded(child: _ListaIngresos(ingresos: hoy)),
          ],
        );
      },
    );
  }

  List<Ingreso> _porFecha(List<Ingreso> todos, DateTime fecha) {
    return todos
        .where((i) =>
            i.timestamp.year == fecha.year &&
            i.timestamp.month == fecha.month &&
            i.timestamp.day == fecha.day)
        .toList();
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
