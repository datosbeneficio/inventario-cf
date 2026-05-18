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
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear cliente'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del cliente',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
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
              FirestoreService.instance.addCliente(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
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
        subtitle: const Text('Toca para gestionar rangos'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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

        return Column(
          children: [
            ...rangos.map((r) => _RangoTile(clienteId: cliente.id, rango: r)),
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
  const _RangoTile({required this.clienteId, required this.rango});

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
        backgroundColor:
            esAves ? cs.primaryContainer : cs.tertiaryContainer,
        child: Icon(
          esAves
              ? Icons.set_meal
              : rango.esPaquetes
                  ? Icons.inventory_2
                  : Icons.restaurant,
          size: 16,
          color: esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer,
        ),
      ),
      title: Text(rango.nombre),
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
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
        tooltip: 'Eliminar rango',
        onPressed: () async {
          final ok = await showConfirmDelete(context, rango.nombre);
          if (ok && context.mounted) {
            FirestoreService.instance.deleteRango(clienteId, rango.id);
          }
        },
      ),
    );
  }
}
