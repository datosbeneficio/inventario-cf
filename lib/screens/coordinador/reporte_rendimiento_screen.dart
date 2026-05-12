import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../models/salida.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class ReporteRendimientoScreen extends StatefulWidget {
  const ReporteRendimientoScreen({super.key});

  @override
  State<ReporteRendimientoScreen> createState() =>
      _ReporteRendimientoScreenState();
}

class _ReporteRendimientoScreenState extends State<ReporteRendimientoScreen>
    with SingleTickerProviderStateMixin {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();
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
    final todos = context.watch<List<Ingreso>>();
    final todasSalidas = context.watch<List<Salida>>();

    final toEnd = _to.add(const Duration(days: 1));
    final ingresosRango = todos
        .where((i) =>
            !i.timestamp.isBefore(_from) && i.timestamp.isBefore(toEnd))
        .toList();
    final salidasRango = todasSalidas
        .where((s) =>
            !s.timestamp.isBefore(_from) && s.timestamp.isBefore(toEnd))
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range),
              label: Text('${formatDate(_from)} – ${formatDate(_to)}'),
            ),
          ),
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.set_meal), text: 'Aves en Canal'),
              Tab(icon: Icon(Icons.restaurant), text: 'Menudencias'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _RendimientoView(
                  tipo: kTipoAves,
                  ingresos: ingresosRango
                      .where((i) => i.rangoTipo == kTipoAves)
                      .toList(),
                  salidas: salidasRango
                      .where((s) => s.rangoTipo == kTipoAves)
                      .toList(),
                ),
                _RendimientoView(
                  tipo: kTipoMenudencias,
                  ingresos: ingresosRango
                      .where((i) => i.rangoTipo == kTipoMenudencias)
                      .toList(),
                  salidas: salidasRango
                      .where((s) => s.rangoTipo == kTipoMenudencias)
                      .toList(),
                ),
              ],
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

// ── Vista de rendimiento por tipo ──────────────────────────────────────────

class _RendimientoView extends StatelessWidget {
  final String tipo;
  final List<Ingreso> ingresos;
  final List<Salida> salidas;

  const _RendimientoView({
    required this.tipo,
    required this.ingresos,
    required this.salidas,
  });

  @override
  Widget build(BuildContext context) {
    if (ingresos.isEmpty && salidas.isEmpty) {
      return const Center(
          child: Text('Sin movimientos en este período'));
    }

    // Agrupar por rangoNombre (campo denormalizado)
    final nombres = <String>{
      ...ingresos.map((i) => i.rangoNombre),
      ...salidas.map((s) => s.rangoNombre),
    }.toList()
      ..sort();

    final rows = nombres.map((nombre) {
      final ing = ingresos.where((i) => i.rangoNombre == nombre);
      final sal = salidas.where((s) => s.rangoNombre == nombre);
      final pesoIn = ing.fold(0.0, (s, e) => s + e.peso);
      final pesoOut = sal.fold(0.0, (s, e) => s + e.peso);
      final mermaKg = pesoIn - pesoOut;
      final mermaP = pesoIn > 0 ? (mermaKg / pesoIn) * 100 : 0.0;
      return _RendRow(
        nombre: nombre,
        pesoIn: pesoIn,
        pesoOut: pesoOut,
        mermaKg: mermaKg,
        mermaP: mermaP,
      );
    }).toList();

    final totalPesoIn = rows.fold(0.0, (s, r) => s + r.pesoIn);
    final totalPesoOut = rows.fold(0.0, (s, r) => s + r.pesoOut);
    final totalMermaKg = totalPesoIn - totalPesoOut;
    final totalMermaP =
        totalPesoIn > 0 ? (totalMermaKg / totalPesoIn) * 100 : 0.0;

    final cs = Theme.of(context).colorScheme;
    final colorIn = tipo == kTipoAves ? cs.primary : cs.tertiary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resumen
          Row(
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
                  value:
                      '${formatKg(totalMermaKg)}\n${formatNum(totalMermaP)}%',
                  icon: Icons.trending_down,
                  color: totalMermaKg > 0
                      ? cs.errorContainer
                      : cs.tertiaryContainer),
            ],
          ),
          const SizedBox(height: 16),
          // Gráfico
          if (rows.any((r) => r.pesoIn > 0 || r.pesoOut > 0)) ...[
            Text('Peso por rango (kg)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _PesoBarChart(
                rows: rows,
                colorIn: colorIn,
                colorOut: cs.secondary,
                colorMerma: cs.error,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(color: colorIn, label: 'Ingresado'),
                const SizedBox(width: 12),
                _LegendDot(color: cs.secondary, label: 'Despachado'),
                const SizedBox(width: 12),
                _LegendDot(color: cs.error, label: 'Merma'),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Tabla
          Text('Detalle por rango',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(cs.primaryContainer),
              columns: const [
                DataColumn(label: Text('Rango')),
                DataColumn(label: Text('Peso Ing. (kg)'), numeric: true),
                DataColumn(label: Text('Peso Sal. (kg)'), numeric: true),
                DataColumn(label: Text('Merma (kg)'), numeric: true),
                DataColumn(label: Text('Merma %'), numeric: true),
              ],
              rows: [
                ...rows.map((r) => DataRow(cells: [
                      DataCell(Text(r.nombre)),
                      DataCell(Text(formatNum(r.pesoIn))),
                      DataCell(Text(formatNum(r.pesoOut))),
                      DataCell(Text(formatNum(r.mermaKg))),
                      DataCell(Text('${formatNum(r.mermaP)}%')),
                    ])),
                DataRow(
                  color:
                      WidgetStateProperty.all(cs.secondaryContainer),
                  cells: [
                    const DataCell(Text('TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalPesoIn),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalPesoOut),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalMermaKg),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text('${formatNum(totalMermaP)}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ──────────────────────────────────────────────────────────────

class _PesoBarChart extends StatelessWidget {
  final List<_RendRow> rows;
  final Color colorIn;
  final Color colorOut;
  final Color colorMerma;

  const _PesoBarChart({
    required this.rows,
    required this.colorIn,
    required this.colorOut,
    required this.colorMerma,
  });

  @override
  Widget build(BuildContext context) {
    final groups = rows.asMap().entries.map((e) {
      final idx = e.key;
      final r = e.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: r.pesoIn,
            color: colorIn,
            width: 12,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: r.pesoOut,
            color: colorOut,
            width: 12,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: r.mermaKg < 0 ? 0 : r.mermaKg,
            color: colorMerma,
            width: 12,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        barsSpace: 3,
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= rows.length) return const SizedBox();
                final name = rows[idx].nombre;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 7)}…' : name,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIdx) {
              final labels = ['Ingresado', 'Despachado', 'Merma'];
              return BarTooltipItem(
                '${labels[rodIdx]}\n${formatKg(rod.toY)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Modelos y helpers de UI ────────────────────────────────────────────────

class _RendRow {
  final String nombre;
  final double pesoIn;
  final double pesoOut;
  final double mermaKg;
  final double mermaP;

  const _RendRow({
    required this.nombre,
    required this.pesoIn,
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

  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
