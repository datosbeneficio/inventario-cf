import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/rangos_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/formatters.dart';

class RangosScreen extends StatelessWidget {
  const RangosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    return Scaffold(
      body: rangos.isEmpty
          ? const Center(child: Text('Sin rangos. Agrega uno con el botón +'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rangos.length,
              itemBuilder: (ctx, i) {
                final rango = rangos[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.category)),
                    title: Text(rango.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Multiplicador: ×${formatNum(rango.multiplicador)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar rango',
                      onPressed: () async {
                        final ok = await showConfirmDelete(ctx, rango.nombre);
                        if (ok && ctx.mounted) {
                          ctx.read<RangosProvider>().eliminar(rango.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo rango'),
      ),
    );
  }

  void _showCrearDialog(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final multCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear rango'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del rango',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: multCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Multiplicador (unid/canastilla)',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 20',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo requerido';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Valor inválido';
                  return null;
                },
              ),
            ],
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
              ctx.read<RangosProvider>().agregar(
                    nombreCtrl.text,
                    double.parse(multCtrl.text),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
