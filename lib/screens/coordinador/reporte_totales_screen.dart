import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/salidas_provider.dart';
import '../../utils/formatters.dart';

class ReporteTotalesScreen extends StatefulWidget {
  const ReporteTotalesScreen({super.key});

  @override
  State<ReporteTotalesScreen> createState() => _ReporteTotalesScreenState();
}

class _ReporteTotalesScreenState extends State<ReporteTotalesScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    final ingresosP = context.watch<IngresosProvider>();
    final salidasP = context.watch<SalidasProvider>();

    final rows = rangos.map((rango) {
      final ingresos = ingresosP.porFecha(_selectedDate).where((i) => i.rangoId == rango.id);
      final salidas = salidasP.porFecha(_selectedDate).where((s) => s.rangoId == rango.id);
      return _RangoRow(
        nombre: rango.nombre,
        unidIn: ingresos.fold(0, (s, e) => s + e.unidades),
        pesoIn: ingresos.fold(0.0, (s, e) => s + e.peso),
        unidOut: salidas.fold(0, (s, e) => s + e.unidades),
        pesoOut: salidas.fold(0.0, (s, e) => s + e.peso),
      );
    }).toList();

    final totalUnidIn = rows.fold(0, (s, r) => s + r.unidIn);
    final totalPesoIn = rows.fold(0.0, (s, r) => s + r.pesoIn);
    final totalUnidOut = rows.fold(0, (s, r) => s + r.unidOut);
    final totalPesoOut = rows.fold(0.0, (s, r) => s + r.pesoOut);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text('Fecha: ${formatDate(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _pickDate(context),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No hay rangos configurados'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            Theme.of(context).colorScheme.primaryContainer),
                        columns: const [
                          DataColumn(label: Text('Rango')),
                          DataColumn(label: Text('Unid. Ingresadas'), numeric: true),
                          DataColumn(label: Text('Peso Ing. (kg)'), numeric: true),
                          DataColumn(label: Text('Unid. Salidas'), numeric: true),
                          DataColumn(label: Text('Peso Sal. (kg)'), numeric: true),
                        ],
                        rows: [
                          ...rows.map((r) => DataRow(cells: [
                                DataCell(Text(r.nombre)),
                                DataCell(Text(formatNum(r.unidIn))),
                                DataCell(Text(formatNum(r.pesoIn))),
                                DataCell(Text(formatNum(r.unidOut))),
                                DataCell(Text(formatNum(r.pesoOut))),
                              ])),
                          DataRow(
                            color: WidgetStateProperty.all(
                                Theme.of(context).colorScheme.secondaryContainer),
                            cells: [
                              const DataCell(Text('TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalUnidIn),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalPesoIn),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalUnidOut),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalPesoOut),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

class _RangoRow {
  final String nombre;
  final int unidIn;
  final double pesoIn;
  final int unidOut;
  final double pesoOut;

  const _RangoRow({
    required this.nombre,
    required this.unidIn,
    required this.pesoIn,
    required this.unidOut,
    required this.pesoOut,
  });
}
