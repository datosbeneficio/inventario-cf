import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/salidas_provider.dart';
import '../../utils/formatters.dart';

class ReporteRendimientoScreen extends StatefulWidget {
  const ReporteRendimientoScreen({super.key});

  @override
  State<ReporteRendimientoScreen> createState() =>
      _ReporteRendimientoScreenState();
}

class _ReporteRendimientoScreenState extends State<ReporteRendimientoScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final rangos = context.watch<RangosProvider>().activos;
    final ingresosP = context.watch<IngresosProvider>();
    final salidasP = context.watch<SalidasProvider>();

    final rows = rangos.map((rango) {
      final ingresos = ingresosP.enRango(_from, _to).where((i) => i.rangoId == rango.id);
      final salidas = salidasP.enRango(_from, _to).where((s) => s.rangoId == rango.id);
      final pesoIn = ingresos.fold(0.0, (s, e) => s + e.peso);
      final pesoOut = salidas.fold(0.0, (s, e) => s + e.peso);
      final mermaKg = pesoIn - pesoOut;
      final mermaP = pesoIn > 0 ? (mermaKg / pesoIn) * 100 : 0.0;
      return _RendRow(
        nombre: rango.nombre,
        unidIn: ingresos.fold(0, (s, e) => s + e.unidades),
        pesoIn: pesoIn,
        unidOut: salidas.fold(0, (s, e) => s + e.unidades),
        pesoOut: pesoOut,
        mermaKg: mermaKg,
        mermaP: mermaP,
      );
    }).toList();

    final totalPesoIn = rows.fold(0.0, (s, r) => s + r.pesoIn);
    final totalPesoOut = rows.fold(0.0, (s, r) => s + r.pesoOut);
    final totalMermaKg = totalPesoIn - totalPesoOut;
    final totalMermaP = totalPesoIn > 0 ? (totalMermaKg / totalPesoIn) * 100 : 0.0;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range),
              label: Text('${formatDate(_from)} – ${formatDate(_to)}'),
            ),
          ),
          // Summary cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SummaryCard(
                    label: 'Peso Ingresado',
                    value: formatKg(totalPesoIn),
                    icon: Icons.arrow_downward,
                    color: cs.primaryContainer),
                const SizedBox(width: 8),
                _SummaryCard(
                    label: 'Peso Despachado',
                    value: formatKg(totalPesoOut),
                    icon: Icons.arrow_upward,
                    color: cs.secondaryContainer),
                const SizedBox(width: 8),
                _SummaryCard(
                    label: 'Merma',
                    value: '${formatKg(totalMermaKg)} (${formatNum(totalMermaP)}%)',
                    icon: Icons.trending_down,
                    color: totalMermaKg > 0 ? cs.errorContainer : cs.tertiaryContainer),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No hay rangos configurados'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(cs.primaryContainer),
                        columns: const [
                          DataColumn(label: Text('Rango')),
                          DataColumn(label: Text('Unid. Ing.'), numeric: true),
                          DataColumn(label: Text('Peso Ing. (kg)'), numeric: true),
                          DataColumn(label: Text('Unid. Sal.'), numeric: true),
                          DataColumn(label: Text('Peso Sal. (kg)'), numeric: true),
                          DataColumn(label: Text('Merma (kg)'), numeric: true),
                          DataColumn(label: Text('Merma %'), numeric: true),
                        ],
                        rows: [
                          ...rows.map((r) => DataRow(cells: [
                                DataCell(Text(r.nombre)),
                                DataCell(Text(formatNum(r.unidIn))),
                                DataCell(Text(formatNum(r.pesoIn))),
                                DataCell(Text(formatNum(r.unidOut))),
                                DataCell(Text(formatNum(r.pesoOut))),
                                DataCell(Text(formatNum(r.mermaKg))),
                                DataCell(Text('${formatNum(r.mermaP)}%')),
                              ])),
                          DataRow(
                            color: WidgetStateProperty.all(cs.secondaryContainer),
                            cells: [
                              const DataCell(Text('TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(rows.fold(0, (s, r) => s + r.unidIn)),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalPesoIn),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(rows.fold(0, (s, r) => s + r.unidOut)),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalPesoOut),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(formatNum(totalMermaKg),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${formatNum(totalMermaP)}%',
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

  Future<void> _pickRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }
}

class _RendRow {
  final String nombre;
  final int unidIn;
  final double pesoIn;
  final int unidOut;
  final double pesoOut;
  final double mermaKg;
  final double mermaP;

  const _RendRow({
    required this.nombre,
    required this.unidIn,
    required this.pesoIn,
    required this.unidOut,
    required this.pesoOut,
    required this.mermaKg,
    required this.mermaP,
  });
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
