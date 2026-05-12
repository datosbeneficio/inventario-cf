import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/rangos_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class RangosScreen extends StatefulWidget {
  const RangosScreen({super.key});

  @override
  State<RangosScreen> createState() => _RangosScreenState();
}

class _RangosScreenState extends State<RangosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: [
              Tab(
                icon: Icon(Icons.set_meal, color: cs.primary),
                text: 'Aves en Canal',
              ),
              Tab(
                icon: Icon(Icons.restaurant, color: cs.tertiary),
                text: 'Menudencias',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _RangosList(tipo: kTipoAves),
                _RangosList(tipo: kTipoMenudencias),
              ],
            ),
          ),
        ],
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
    String tipoSeleccionado = kTipoAves;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: kTipoAves,
                      label: Text('Aves en Canal'),
                      icon: Icon(Icons.set_meal),
                    ),
                    ButtonSegment(
                      value: kTipoMenudencias,
                      label: Text('Menudencias'),
                      icon: Icon(Icons.restaurant),
                    ),
                  ],
                  selected: {tipoSeleccionado},
                  onSelectionChanged: (s) =>
                      setDialogState(() => tipoSeleccionado = s.first),
                ),
                const SizedBox(height: 12),
                if (tipoSeleccionado == kTipoAves)
                  TextFormField(
                    controller: multCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Multiplicador (unid/canastilla)',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: 20',
                    ),
                    validator: (v) {
                      if (tipoSeleccionado == kTipoMenudencias) return null;
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
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menudencias se registra en canastillas directas (sin multiplicador)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
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
                final mult = tipoSeleccionado == kTipoMenudencias
                    ? 1.0
                    : double.parse(multCtrl.text);
                ctx.read<RangosProvider>().agregar(
                      nombreCtrl.text,
                      mult,
                      tipoSeleccionado,
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

class _RangosList extends StatelessWidget {
  final String tipo;
  const _RangosList({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = tipo == kTipoAves;
    final rangos = esAves
        ? context.watch<RangosProvider>().activosAves
        : context.watch<RangosProvider>().activosMenudencias;

    if (rangos.isEmpty) {
      return Center(
        child: Text(
          'Sin rangos de ${esAves ? 'aves en canal' : 'menudencias'}.\nAgrega uno con el botón +',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rangos.length,
      itemBuilder: (ctx, i) {
        final rango = rangos[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: esAves ? cs.primaryContainer : cs.tertiaryContainer,
              child: Icon(
                esAves ? Icons.set_meal : Icons.restaurant,
                color: esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer,
              ),
            ),
            title: Text(rango.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: esAves
                ? Text('Multiplicador: ×${formatNum(rango.multiplicador)}')
                : const Text('Canastillas directas'),
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
    );
  }
}
