import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/destino.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirm_delete_dialog.dart';

class DestinosScreen extends StatelessWidget {
  const DestinosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final destinos = context.watch<List<Destino>>();

    return Scaffold(
      body: destinos.isEmpty
          ? const Center(
              child: Text('Sin destinos registrados. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: destinos.length,
              itemBuilder: (_, i) => _DestinoTile(d: destinos[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(context, null),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nuevo destino'),
      ),
    );
  }

  static void _showDialog(BuildContext context, Destino? existing) {
    final nombreCtrl =
        TextEditingController(text: existing?.nombre ?? '');
    final dirCtrl =
        TextEditingController(text: existing?.direccion ?? '');
    final munCtrl =
        TextEditingController(text: existing?.municipio ?? '');
    final depCtrl =
        TextEditingController(text: existing?.departamento ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo destino' : 'Editar destino'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Identificador',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    hintText: 'Ej: POLLOS SAVICOL',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'Ej: CL 10 # 32-62',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: munCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Municipio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: depCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Departamento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
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
              if (existing == null) {
                FirestoreService.instance.addDestino(
                  nombre: nombreCtrl.text,
                  direccion: dirCtrl.text,
                  municipio: munCtrl.text,
                  departamento: depCtrl.text,
                );
              } else {
                FirestoreService.instance.updateDestino(
                  existing.id,
                  nombre: nombreCtrl.text,
                  direccion: dirCtrl.text,
                  municipio: munCtrl.text,
                  departamento: depCtrl.text,
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

class _DestinoTile extends StatelessWidget {
  final Destino d;
  const _DestinoTile({required this.d});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Icon(Icons.location_on,
              size: 20, color: cs.onSecondaryContainer),
        ),
        title: Text(d.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.direccion),
            Text(
              '${d.municipio}, ${d.departamento}',
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
              onPressed: () => DestinosScreen._showDialog(context, d),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () async {
                final ok = await showConfirmDelete(context, d.nombre);
                if (ok && context.mounted) {
                  FirestoreService.instance.deleteDestino(d.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
