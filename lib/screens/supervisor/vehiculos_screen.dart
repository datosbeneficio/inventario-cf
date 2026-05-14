import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/vehiculo.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';

class VehiculosScreen extends StatelessWidget {
  const VehiculosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehiculos = context.watch<List<Vehiculo>>();

    return Scaffold(
      body: vehiculos.isEmpty
          ? const Center(
              child: Text('Sin vehículos registrados. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vehiculos.length,
              itemBuilder: (_, i) => _VehiculoTile(v: vehiculos[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(context, null),
        icon: const Icon(Icons.local_shipping),
        label: const Text('Nuevo vehículo'),
      ),
    );
  }

  static void _showDialog(BuildContext context, Vehiculo? existing) {
    final placaCtrl =
        TextEditingController(text: existing?.placa ?? '');
    final nombreCtrl =
        TextEditingController(text: existing?.conductorNombre ?? '');
    final cedulaCtrl =
        TextEditingController(text: existing?.conductorCedula ?? '');
    final celularCtrl =
        TextEditingController(text: existing?.conductorCelular ?? '');
    final capacidadCtrl = TextEditingController(
        text: existing?.capacidadKg != null
            ? formatNum(existing!.capacidadKg)
            : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo vehículo' : 'Editar vehículo'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: placaCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Placa',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                    hintText: 'Ej: SSW 405',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del conductor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cedulaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cédula del conductor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: celularCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Celular del conductor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capacidadCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Capacidad (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    final n =
                        double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Valor inválido';
                    return null;
                  },
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
              final cap = double.parse(
                  capacidadCtrl.text.replaceAll(',', '.'));
              if (existing == null) {
                FirestoreService.instance.addVehiculo(
                  placa: placaCtrl.text,
                  conductorNombre: nombreCtrl.text,
                  conductorCedula: cedulaCtrl.text,
                  conductorCelular: celularCtrl.text,
                  capacidadKg: cap,
                );
              } else {
                FirestoreService.instance.updateVehiculo(
                  existing.id,
                  placa: placaCtrl.text,
                  conductorNombre: nombreCtrl.text,
                  conductorCedula: cedulaCtrl.text,
                  conductorCelular: celularCtrl.text,
                  capacidadKg: cap,
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

class _VehiculoTile extends StatelessWidget {
  final Vehiculo v;
  const _VehiculoTile({required this.v});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.local_shipping,
              size: 20, color: cs.onPrimaryContainer),
        ),
        title: Text(v.placa,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.conductorNombre),
            Text(
              'CC ${v.conductorCedula} · ${v.conductorCelular} · '
              '${formatNum(v.capacidadKg)} kg',
              style:
                  TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () =>
                  VehiculosScreen._showDialog(context, v),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () async {
                final ok = await showConfirmDelete(context, v.placa);
                if (ok && context.mounted) {
                  FirestoreService.instance.deleteVehiculo(v.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
