import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rangos_provider.dart';
import '../../providers/ingresos_provider.dart';
import '../../providers/salidas_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class ReporteTotalesScreen extends StatefulWidget {
  const ReporteTotalesScreen({super.key});

  @override
  State<ReporteTotalesScreen> createState() => _ReporteTotalesScreenState();
}

class _ReporteTotalesScreenState extends State<ReporteTotalesScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
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
    final rangosAves =
        context.watch<RangosProvider>().activosAves;
    final rangosMenud =
        context.watch<RangosProvider>().activosMenudencias;
    final ingresosP = context.watch<IngresosProvider>();
    final salidasP = context.watch<SalidasProvider>();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
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
                _TotalesView(
                  rangos: rangosAves,
                  tipo: kTipoAves,
                  selectedDate: _selectedDate,
                  ingresosP: ingresosP,
                  salidasP: salidasP,
                ),
                _TotalesView(
                  rangos: rangosMenud,
                  tipo: kTipoMenudencias,
                  selectedDate: _selectedDate,
                  ingresosP: ingresosP,
                  salidasP: salidasP,
                ),
              ],
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

class _TotalesView extends StatelessWidget {
  final List rangos;
  final String tipo;
  final DateTime selectedDate;
  final IngresosProvider ingresosP;
  final SalidasProvider salidasP;

  const _TotalesView({
    required this.rangos,
    required this.tipo,
    required this.selectedDate,
    required this.ingresosP,
    required this.salidasP,
  });

  @override
  Widget build(BuildContext context) {
    if (rangos.isEmpty) {
      return const Center(child: Text('Sin rangos configurados'));
    }

    final rows = rangos.map((rango) {
      final ingresos = ingresosP
          .porFecha(selectedDate)
          .where((i) => i.rangoId == rango.id);
      final salidas = salidasP
          .porFecha(selectedDate)
          .where((s) => s.rangoId == rango.id);
      return _Row(
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

    final cs = Theme.of(context).colorScheme;
    final colorIn = tipo == kTipoAves ? cs.primary : cs.tertiary;
    final colorOut = tipo == kTipoAves ? cs.secondary : cs.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary chips
          Row(
            children: [
              _ChipSummary(
                  label: 'Total Ing.',
                  value: '${formatNum(totalUnidIn)} unid.',
                  color: colorIn),
              const SizedBox(width: 8),
              _ChipSummary(
                  label: 'Peso Ing.',
                  value: formatKg(totalPesoIn),
                  color: colorIn),
              const SizedBox(width: 8),
              _ChipSummary(
                  label: 'Total Sal.',
                  value: '${formatNum(totalUnidOut)} unid.',
                  color: colorOut),
              const SizedBox(width: 8),
              _ChipSummary(
                  label: 'Peso Sal.',
                  value: formatKg(totalPesoOut),
                  color: colorOut),
            ],
          ),
          const SizedBox(height: 16),
          // Bar chart
          if (rows.any((r) => r.unidIn > 0 || r.unidOut > 0)) ...[
            Text('Unidades por rango',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _BarChart(rows: rows, colorIn: colorIn, colorOut: colorOut),
            ),
            const SizedBox(height: 16),
          ],
          // Table
          Text('Detalle', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(cs.primaryContainer),
              columns: const [
                DataColumn(label: Text('Rango')),
                DataColumn(label: Text('Unid. Ing.'), numeric: true),
                DataColumn(label: Text('Peso Ing.'), numeric: true),
                DataColumn(label: Text('Unid. Sal.'), numeric: true),
                DataColumn(label: Text('Peso Sal.'), numeric: true),
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
                  color: WidgetStateProperty.all(cs.secondaryContainer),
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
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<_Row> rows;
  final Color colorIn;
  final Color colorOut;

  const _BarChart(
      {required this.rows, required this.colorIn, required this.colorOut});

  @override
  Widget build(BuildContext context) {
    final groups = rows.asMap().entries.map((e) {
      final idx = e.key;
      final r = e.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: r.unidIn.toDouble(),
            color: colorIn,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: r.unidOut.toDouble(),
            color: colorOut,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Ingresadas' : 'Salidas';
              return BarTooltipItem(
                '$label\n${formatNum(rod.toY.round())}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Row {
  final String nombre;
  final int unidIn;
  final double pesoIn;
  final int unidOut;
  final double pesoOut;

  const _Row({
    required this.nombre,
    required this.unidIn,
    required this.pesoIn,
    required this.unidOut,
    required this.pesoOut,
  });
}

class _ChipSummary extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChipSummary(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
