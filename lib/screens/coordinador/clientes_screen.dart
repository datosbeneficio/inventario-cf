import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/clientes_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';

class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clientes = context.watch<ClientesProvider>().activos;
    return Scaffold(
      body: clientes.isEmpty
          ? const Center(
              child: Text('Sin clientes. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: clientes.length,
              itemBuilder: (ctx, i) {
                final c = clientes[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business)),
                    title: Text(c.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar cliente',
                      onPressed: () async {
                        final ok =
                            await showConfirmDelete(ctx, c.nombre);
                        if (ok && ctx.mounted) {
                          ctx.read<ClientesProvider>().eliminar(c.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
    );
  }

  void _showCrearDialog(BuildContext context) {
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
              ctx.read<ClientesProvider>().agregar(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
