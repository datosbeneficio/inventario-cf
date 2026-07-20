import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/cliente.dart';
import '../../models/rango.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/utils/constants.dart';
import '../../../../shared/utils/formatters.dart';

class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clientes = context.watch<List<Cliente>>();

    return Scaffold(
      body: clientes.isEmpty
          ? const Center(
              child: Text('Sin clientes. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: clientes.length,
              itemBuilder: (ctx, i) => _ClienteTile(cliente: clientes[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearClienteDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
    );
  }

  void _showCrearClienteDialog(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final diasAvesCtrl = TextEditingController(text: '30');
    final diasMenudCtrl = TextEditingController(text: '30');
    final formKey = GlobalKey<FormState>();
    bool marcaEditadaManualmente = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Crear cliente'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                    onChanged: (v) {
                      if (marcaEditadaManualmente) return;
                      final letra = v.trim().isNotEmpty
                          ? v.trim()[0].toUpperCase()
                          : '';
                      setDs(() => marcaCtrl.text = letra);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: marcaCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'Marca en lote',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                      hintText: 'Ej: A',
                      counterText: '',
                    ),
                    onChanged: (_) =>
                        setDs(() => marcaEditadaManualmente = true),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: diasAvesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Días venc. Aves',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return (n == null || n <= 0) ? 'Inválido' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: diasMenudCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Días venc. Menud.',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return (n == null || n <= 0) ? 'Inválido' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                FirestoreService.instance.addCliente(
                  nombreCtrl.text,
                  marcaLote: marcaCtrl.text,
                  diasVencimientoAves: int.parse(diasAvesCtrl.text.trim()),
                  diasVencimientoMenudencias:
                      int.parse(diasMenudCtrl.text.trim()),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editar datos de un cliente existente ───────────────────────────────────

void _showEditarClienteDialog(BuildContext context, Cliente cliente) {
  final nombreCtrl = TextEditingController(text: cliente.nombre);
  final marcaCtrl = TextEditingController(text: cliente.marcaLoteEfectiva);
  final diasAvesCtrl =
      TextEditingController(text: cliente.diasVencimientoAves.toString());
  final diasMenudCtrl = TextEditingController(
      text: cliente.diasVencimientoMenudencias.toString());
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Editar — ${cliente.nombre}'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: marcaCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: const InputDecoration(
                  labelText: 'Marca en lote',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'Ej: A',
                  counterText: '',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: diasAvesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Días venc. Aves',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return (n == null || n <= 0) ? 'Inválido' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: diasMenudCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Días venc. Menud.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return (n == null || n <= 0) ? 'Inválido' : null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            FirestoreService.instance.updateCliente(
              cliente.id,
              nombre: nombreCtrl.text,
              marcaLote: marcaCtrl.text,
              diasVencimientoAves: int.parse(diasAvesCtrl.text.trim()),
              diasVencimientoMenudencias:
                  int.parse(diasMenudCtrl.text.trim()),
            );
            Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

// ── Tile de cliente con ExpansionTile para sus rangos ─────────────────────

class _ClienteTile extends StatelessWidget {
  final Cliente cliente;
  const _ClienteTile({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.business)),
        title: Text(cliente.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Toca para gestionar rangos · Lote: ${cliente.marcaLoteEfectiva} · '
            'Venc. ${cliente.diasVencimientoAves}d aves / '
            '${cliente.diasVencimientoMenudencias}d menud.'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar cliente',
              onPressed: () => _showEditarClienteDialog(context, cliente),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar cliente',
              onPressed: () async {
                final ok =
                    await showConfirmDelete(context, cliente.nombre);
                if (ok && context.mounted) {
                  FirestoreService.instance.deleteCliente(cliente.id);
                }
              },
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          _RangosCliente(cliente: cliente),
        ],
      ),
    );
  }
}

// ── Rangos del cliente (stream interno) ───────────────────────────────────

class _RangosCliente extends StatelessWidget {
  final Cliente cliente;
  const _RangosCliente({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rango>>(
      stream: FirestoreService.instance.rangosStream(cliente.id),
      builder: (ctx, snapshot) {
        final rangos = snapshot.data ?? [];

        void mover(int index, int delta) {
          final destino = index + delta;
          if (destino < 0 || destino >= rangos.length) return;
          final reordenados = [...rangos];
          final item = reordenados.removeAt(index);
          reordenados.insert(destino, item);
          FirestoreService.instance.reordenarRangos(
              cliente.id, reordenados.map((r) => r.id).toList());
        }

        return Column(
          children: [
            for (var i = 0; i < rangos.length; i++)
              _RangoTile(
                clienteId: cliente.id,
                rango: rangos[i],
                puedeSubir: i > 0,
                puedeBajar: i < rangos.length - 1,
                onSubir: () => mover(i, -1),
                onBajar: () => mover(i, 1),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir rango'),
                onPressed: () =>
                    _showCrearRangoDialog(context, cliente.id),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCrearRangoDialog(BuildContext context, String clienteId) {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final multCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String tipoSel = kTipoAves;
    String subtipoSel = kSubtipoCanastillas;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('Nuevo rango — ${cliente.nombre}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Nombre ──────────────────────────────────────────
                  TextFormField(
                    controller: nombreCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del rango',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Campo requerido'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Descripción (opcional) ───────────────────────────
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Pollo entero > 2 kg',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // ── Tipo: Aves / Menudencias ─────────────────────────
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: kTipoAves,
                        label: Text('Aves'),
                        icon: Icon(Icons.set_meal),
                      ),
                      ButtonSegment(
                        value: kTipoMenudencias,
                        label: Text('Menudencias'),
                        icon: Icon(Icons.restaurant),
                      ),
                    ],
                    selected: {tipoSel},
                    onSelectionChanged: (s) => setDs(() {
                      tipoSel = s.first;
                      subtipoSel = kSubtipoCanastillas;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // ── Campos condicionales por tipo ────────────────────
                  if (tipoSel == kTipoAves) ...[
                    TextFormField(
                      controller: multCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Multiplicador (unid/canastilla)',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: 20',
                      ),
                      validator: (v) {
                        if (tipoSel != kTipoAves) return null;
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Valor inválido';
                        return null;
                      },
                    ),
                  ] else ...[
                    // Subtipo: Canastillas / Paquetes
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: kSubtipoCanastillas,
                          label: Text('Canastillas'),
                          icon: Icon(Icons.shopping_basket),
                        ),
                        ButtonSegment(
                          value: kSubtipoPaquetes,
                          label: Text('Paquetes'),
                          icon: Icon(Icons.inventory_2),
                        ),
                      ],
                      selected: {subtipoSel},
                      onSelectionChanged: (s) =>
                          setDs(() => subtipoSel = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (subtipoSel == kSubtipoPaquetes)
                      TextFormField(
                        controller: multCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Paquetes por canastilla',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: 12',
                        ),
                        validator: (v) {
                          if (subtipoSel != kSubtipoPaquetes) return null;
                          if (v == null || v.isEmpty) return 'Campo requerido';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Valor inválido';
                          return null;
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Se registra en canastillas directas (sin multiplicador)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                double mult;
                if (tipoSel == kTipoAves) {
                  mult = double.parse(multCtrl.text);
                } else if (subtipoSel == kSubtipoPaquetes) {
                  mult = double.parse(multCtrl.text);
                } else {
                  mult = 1.0;
                }
                FirestoreService.instance.addRango(
                  clienteId,
                  nombreCtrl.text,
                  mult,
                  tipoSel,
                  subtipo: tipoSel == kTipoMenudencias
                      ? subtipoSel
                      : kSubtipoCanastillas,
                  descripcion: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile de rango individual ───────────────────────────────────────────────

class _RangoTile extends StatelessWidget {
  final String clienteId;
  final Rango rango;
  final bool puedeSubir;
  final bool puedeBajar;
  final VoidCallback onSubir;
  final VoidCallback onBajar;
  const _RangoTile({
    required this.clienteId,
    required this.rango,
    required this.puedeSubir,
    required this.puedeBajar,
    required this.onSubir,
    required this.onBajar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = rango.tipo == kTipoAves;

    String tipoLabel;
    if (esAves) {
      tipoLabel = 'Aves · ×${formatNum(rango.multiplicador)}';
    } else if (rango.esPaquetes) {
      tipoLabel = 'Menudencias · paquetes · ×${formatNum(rango.multiplicador)}';
    } else {
      tipoLabel = 'Menudencias · canastillas directas';
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: rango.esEspecial
            ? cs.errorContainer
            : esAves
                ? cs.primaryContainer
                : cs.tertiaryContainer,
        child: Icon(
          rango.esEspecial
              ? Icons.star
              : esAves
                  ? Icons.set_meal
                  : rango.esPaquetes
                      ? Icons.inventory_2
                      : Icons.restaurant,
          size: 16,
          color: rango.esEspecial
              ? cs.onErrorContainer
              : esAves
                  ? cs.onPrimaryContainer
                  : cs.onTertiaryContainer,
        ),
      ),
      title: Row(
        children: [
          Text(rango.nombre),
          if (rango.esEspecial) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('ESPECIAL',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: cs.onError)),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rango.descripcion != null && rango.descripcion!.isNotEmpty)
            Text(
              rango.descripcion!,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          Text(tipoLabel, style: const TextStyle(fontSize: 12)),
        ],
      ),
      isThreeLine: rango.descripcion != null && rango.descripcion!.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: 'Subir',
            onPressed: puedeSubir ? onSubir : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            tooltip: 'Bajar',
            onPressed: puedeBajar ? onBajar : null,
          ),
          IconButton(
            icon: Icon(
              rango.esEspecial ? Icons.star : Icons.star_border,
              color: rango.esEspecial ? cs.error : cs.outlineVariant,
              size: 20,
            ),
            tooltip: rango.esEspecial
                ? 'Quitar marca especial'
                : 'Marcar como especial',
            onPressed: () {
              FirestoreService.instance.updateRango(
                clienteId,
                rango.id,
                {'esEspecial': !rango.esEspecial},
              );
            },
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Eliminar rango',
            onPressed: () async {
              final ok = await showConfirmDelete(context, rango.nombre);
              if (ok && context.mounted) {
                FirestoreService.instance.deleteRango(clienteId, rango.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
