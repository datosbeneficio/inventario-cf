import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/cliente.dart';
import '../../models/ingreso.dart';
import '../../models/salida.dart';
import '../../../../shared/utils/constants.dart';
import '../../../../shared/utils/formatters.dart';

class ReporteTotalesScreen extends StatefulWidget {
  const ReporteTotalesScreen({super.key});

  @override
  State<ReporteTotalesScreen> createState() => _ReporteTotalesScreenState();
}

class _ReporteTotalesScreenState extends State<ReporteTotalesScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  String? _clienteId; // null = todos
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
    final clientes = context.watch<List<Cliente>>();
    final todos = context.watch<List<Ingreso>>();
    final todasSalidas = context.watch<List<Salida>>();

    final ingresosDelDia = todos
        .where((i) =>
            _sameDay(i.timestamp, _selectedDate) &&
            (_clienteId == null || i.clienteId == _clienteId))
        .toList();
    final salidasDelDia = todasSalidas
        .where((s) =>
            _sameDay(s.timestamp, _selectedDate) &&
            (_clienteId == null || s.clienteId == _clienteId))
        .toList();

    return Scaffold(
      body: Column(
        children: [
          // ── Barra de filtros ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                // Selector de fecha
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 6),
                Text(formatDate(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _pickDate(context),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Cambiar'),
                ),
                const Spacer(),
                // Selector de cliente
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 6),
                DropdownButton<String?>(
                  value: _clienteId,
                  underline: const SizedBox(),
                  isDense: true,
                  hint: const Text('Todos'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Todos los clientes')),
                    ...clientes.map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.nombre))),
                  ],
                  onChanged: (v) => setState(() => _clienteId = v),
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
                  tipo: kTipoAves,
                  ingresos: ingresosDelDia
                      .where((i) => i.rangoTipo == kTipoAves)
                      .toList(),
                  salidas: salidasDelDia
                      .where((s) => s.rangoTipo == kTipoAves)
                      .toList(),
                  mostrarCliente: _clienteId == null,
                ),
                _TotalesView(
                  tipo: kTipoMenudencias,
                  ingresos: ingresosDelDia
                      .where((i) => i.rangoTipo == kTipoMenudencias)
                      .toList(),
                  salidas: salidasDelDia
                      .where((s) => s.rangoTipo == kTipoMenudencias)
                      .toList(),
                  mostrarCliente: _clienteId == null,
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

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Vista por tipo ─────────────────────────────────────────────────────────

class _TotalesView extends StatelessWidget {
  final String tipo;
  final List<Ingreso> ingresos;
  final List<Salida> salidas;
  final bool mostrarCliente;

  const _TotalesView({
    required this.tipo,
    required this.ingresos,
    required this.salidas,
    required this.mostrarCliente,
  });

  @override
  Widget build(BuildContext context) {
    if (ingresos.isEmpty && salidas.isEmpty) {
      return const Center(child: Text('Sin movimientos para esta fecha'));
    }

    // Clave de agrupación: "clienteNombre||rangoNombre" o solo "rangoNombre"
    String keyOf(String cliente, String rango) =>
        mostrarCliente ? '$cliente||$rango' : rango;

    final keys = <String>{
      ...ingresos.map((i) => keyOf(i.clienteNombre, i.rangoNombre)),
      ...salidas.map((s) => keyOf(s.clienteNombre, s.rangoNombre)),
    }.toList()
      ..sort();

    final rows = keys.map((key) {
      final parts = mostrarCliente ? key.split('||') : ['', key];
      final clienteNombre = parts[0];
      final rangoNombre = parts.length > 1 ? parts[1] : key;

      final ing = ingresos.where((i) =>
          i.rangoNombre == rangoNombre &&
          (!mostrarCliente || i.clienteNombre == clienteNombre));
      final sal = salidas.where((s) =>
          s.rangoNombre == rangoNombre &&
          (!mostrarCliente || s.clienteNombre == clienteNombre));

      return _Row(
        clienteNombre: clienteNombre,
        rangoNombre: rangoNombre,
        canIn: ing.fold(0, (s, e) => s + e.canastillas),
        unidIn: ing.fold(0, (s, e) => s + e.unidades),
        pesoIn: ing.fold(0.0, (s, e) => s + e.peso),
        canOut: sal.fold(0, (s, e) => s + e.canastillas),
        unidOut: sal.fold(0, (s, e) => s + e.unidades),
        pesoOut: sal.fold(0.0, (s, e) => s + e.peso),
      );
    }).toList();

    final totalCanIn = rows.fold(0, (s, r) => s + r.canIn);
    final totalUnidIn = rows.fold(0, (s, r) => s + r.unidIn);
    final totalPesoIn = rows.fold(0.0, (s, r) => s + r.pesoIn);
    final totalCanOut = rows.fold(0, (s, r) => s + r.canOut);
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
          // ── Chips de resumen ───────────────────────────────────────────
          Row(
            children: [
              _ChipSummary(
                label: 'Ingreso',
                value: '${formatNum(totalUnidIn)} unid.\n'
                    '${formatNum(totalCanIn)} canast.',
                sub: formatKg(totalPesoIn),
                color: colorIn,
              ),
              const SizedBox(width: 8),
              _ChipSummary(
                label: 'Salida',
                value: '${formatNum(totalUnidOut)} unid.\n'
                    '${formatNum(totalCanOut)} canast.',
                sub: formatKg(totalPesoOut),
                color: colorOut,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Gráfico de barras ──────────────────────────────────────────
          if (rows.any((r) => r.unidIn > 0 || r.unidOut > 0)) ...[
            Text('Unidades por rango',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _BarChart(
                  rows: rows,
                  colorIn: colorIn,
                  colorOut: colorOut,
                  mostrarCliente: mostrarCliente),
            ),
            const SizedBox(height: 16),
          ],

          // ── Tabla de detalle ───────────────────────────────────────────
          Text('Detalle', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(cs.primaryContainer),
              columnSpacing: 20,
              columns: [
                if (mostrarCliente)
                  const DataColumn(label: Text('Cliente')),
                const DataColumn(label: Text('Rango')),
                const DataColumn(label: Text('Can. Ing.'), numeric: true),
                const DataColumn(label: Text('Unid. Ing.'), numeric: true),
                const DataColumn(label: Text('Peso Ing.'), numeric: true),
                const DataColumn(label: Text('Can. Sal.'), numeric: true),
                const DataColumn(label: Text('Unid. Sal.'), numeric: true),
                const DataColumn(label: Text('Peso Sal.'), numeric: true),
              ],
              rows: [
                ...rows.map((r) => DataRow(cells: [
                      if (mostrarCliente) DataCell(Text(r.clienteNombre)),
                      DataCell(Text(r.rangoNombre)),
                      DataCell(Text(formatNum(r.canIn))),
                      DataCell(Text(formatNum(r.unidIn))),
                      DataCell(Text(formatKg(r.pesoIn))),
                      DataCell(Text(formatNum(r.canOut))),
                      DataCell(Text(formatNum(r.unidOut))),
                      DataCell(Text(formatKg(r.pesoOut))),
                    ])),
                DataRow(
                  color: WidgetStateProperty.all(cs.secondaryContainer),
                  cells: [
                    if (mostrarCliente)
                      const DataCell(Text('')),
                    const DataCell(Text('TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalCanIn),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalUnidIn),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatKg(totalPesoIn),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalCanOut),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalUnidOut),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(formatKg(totalPesoOut),
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

// ── Gráfico de barras ──────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<_Row> rows;
  final Color colorIn;
  final Color colorOut;
  final bool mostrarCliente;

  const _BarChart({
    required this.rows,
    required this.colorIn,
    required this.colorOut,
    required this.mostrarCliente,
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
            toY: r.unidIn.toDouble(),
            color: colorIn,
            width: 14,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: r.unidOut.toDouble(),
            color: colorOut,
            width: 14,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
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
                final r = rows[idx];
                final label = mostrarCliente
                    ? '${_abbr(r.clienteNombre)}\n${_abbr(r.rangoNombre)}'
                    : _abbr(r.rangoNombre);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
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
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final r = rows[groupIndex];
              final label = rodIndex == 0 ? 'Ingresadas' : 'Salidas';
              final extra = rodIndex == 0
                  ? '${formatNum(r.canIn)} canast.'
                  : '${formatNum(r.canOut)} canast.';
              return BarTooltipItem(
                '$label\n${formatNum(rod.toY.round())} unid.\n$extra',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _abbr(String s) =>
      s.length > 7 ? '${s.substring(0, 6)}…' : s;
}

// ── Modelos internos ───────────────────────────────────────────────────────

class _Row {
  final String clienteNombre;
  final String rangoNombre;
  final int canIn;
  final int unidIn;
  final double pesoIn;
  final int canOut;
  final int unidOut;
  final double pesoOut;

  const _Row({
    required this.clienteNombre,
    required this.rangoNombre,
    required this.canIn,
    required this.unidIn,
    required this.pesoIn,
    required this.canOut,
    required this.unidOut,
    required this.pesoOut,
  });
}

// ── Widgets de UI ──────────────────────────────────────────────────────────

class _ChipSummary extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _ChipSummary({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}
