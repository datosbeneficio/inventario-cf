import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/conductor.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';

class ConductoresScreen extends StatelessWidget {
  const ConductoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conductores = context.watch<List<Conductor>>();

    return Scaffold(
      body: conductores.isEmpty
          ? const Center(
              child: Text(
                  'Sin conductores registrados. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conductores.length,
              itemBuilder: (_, i) => _ConductorTile(c: conductores[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(context, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo conductor'),
      ),
    );
  }

  static void _showDialog(BuildContext context, Conductor? existing) {
    final nombreCtrl =
        TextEditingController(text: existing?.nombre ?? '');
    final cedulaCtrl =
        TextEditingController(text: existing?.cedula ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'Nuevo conductor' : 'Editar conductor'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
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
                    labelText: 'Cédula',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
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
                FirestoreService.instance.addConductor(
                  nombre: nombreCtrl.text,
                  cedula: cedulaCtrl.text,
                );
              } else {
                FirestoreService.instance.updateConductor(
                  existing.id,
                  nombre: nombreCtrl.text,
                  cedula: cedulaCtrl.text,
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

class _ConductorTile extends StatelessWidget {
  final Conductor c;
  const _ConductorTile({required this.c});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child:
              Icon(Icons.person, size: 20, color: cs.onSecondaryContainer),
        ),
        title: Text(c.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('CC ${c.cedula}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => ConductoresScreen._showDialog(context, c),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () async {
                final ok = await showConfirmDelete(context, c.nombre);
                if (ok && context.mounted) {
                  FirestoreService.instance.deleteConductor(c.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
