import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
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

    final toEnd = _to.add(const Duration(days: 1));
    final ingresosRango = todos
        .where((i) =>
            !i.timestamp.isBefore(_from) &&
            i.timestamp.isBefore(toEnd) &&
            (_clienteId == null || i.clienteId == _clienteId))
        .toList();
    final salidasRango = todasSalidas
        .where((s) =>
            !s.timestamp.isBefore(_from) &&
            s.timestamp.isBefore(toEnd) &&
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
                // Selector de rango de fechas
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickRange(context),
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      '${formatDate(_from)} – ${formatDate(_to)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                _RendimientoView(
                  tipo: kTipoAves,
                  ingresos: ingresosRango
                      .where((i) => i.rangoTipo == kTipoAves)
                      .toList(),
                  salidas: salidasRango
                      .where((s) => s.rangoTipo == kTipoAves)
                      .toList(),
                  mostrarCliente: _clienteId == null,
                ),
                _RendimientoView(
                  tipo: kTipoMenudencias,
                  ingresos: ingresosRango
                      .where((i) => i.rangoTipo == kTipoMenudencias)
                      .toList(),
                  salidas: salidasRango
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
  final bool mostrarCliente;

  const _RendimientoView({
    required this.tipo,
    required this.ingresos,
    required this.salidas,
    required this.mostrarCliente,
  });

  @override
  Widget build(BuildContext context) {
    if (ingresos.isEmpty && salidas.isEmpty) {
      return const Center(child: Text('Sin movimientos en este período'));
    }

    // Clave de agrupación
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

      final canIn = ing.fold(0, (s, e) => s + e.canastillas);
      final canOut = sal.fold(0, (s, e) => s + e.canastillas);
      final pesoIn = ing.fold(0.0, (s, e) => s + e.peso);
      final pesoOut = sal.fold(0.0, (s, e) => s + e.peso);
      final mermaKg = pesoIn - pesoOut;
      final mermaP = pesoIn > 0 ? (mermaKg / pesoIn) * 100 : 0.0;

      return _RendRow(
        clienteNombre: clienteNombre,
        rangoNombre: rangoNombre,
        canIn: canIn,
        canOut: canOut,
        pesoIn: pesoIn,
        pesoOut: pesoOut,
        mermaKg: mermaKg,
        mermaP: mermaP,
      );
    }).toList();

    final totalCanIn = rows.fold(0, (s, r) => s + r.canIn);
    final totalCanOut = rows.fold(0, (s, r) => s + r.canOut);
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
          // ── Resumen ────────────────────────────────────────────────────
          Row(
            children: [
              _SummaryCard(
                label: 'Peso Ingresado',
                value: formatKg(totalPesoIn),
                sub: '${formatNum(totalCanIn)} canast.',
                icon: Icons.arrow_downward,
                color: cs.primaryContainer,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Peso Despachado',
                value: formatKg(totalPesoOut),
                sub: '${formatNum(totalCanOut)} canast.',
                icon: Icons.arrow_upward,
                color: cs.secondaryContainer,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Merma',
                value: formatKg(totalMermaKg),
                sub: '${formatNum(totalMermaP)}%',
                icon: Icons.trending_down,
                color: totalMermaKg > 0
                    ? cs.errorContainer
                    : cs.tertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Gráfico ────────────────────────────────────────────────────
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
                mostrarCliente: mostrarCliente,
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

          // ── Tabla ──────────────────────────────────────────────────────
          Text('Detalle por rango',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(cs.primaryContainer),
              columnSpacing: 18,
              columns: [
                if (mostrarCliente)
                  const DataColumn(label: Text('Cliente')),
                const DataColumn(label: Text('Rango')),
                const DataColumn(label: Text('Can. Ing.'), numeric: true),
                const DataColumn(label: Text('Peso Ing.'), numeric: true),
                const DataColumn(label: Text('Can. Sal.'), numeric: true),
                const DataColumn(label: Text('Peso Sal.'), numeric: true),
                const DataColumn(label: Text('Merma (kg)'), numeric: true),
                const DataColumn(label: Text('Merma %'), numeric: true),
              ],
              rows: [
                ...rows.map((r) => DataRow(cells: [
                      if (mostrarCliente) DataCell(Text(r.clienteNombre)),
                      DataCell(Text(r.rangoNombre)),
                      DataCell(Text(formatNum(r.canIn))),
                      DataCell(Text(formatKg(r.pesoIn))),
                      DataCell(Text(formatNum(r.canOut))),
                      DataCell(Text(formatKg(r.pesoOut))),
                      DataCell(Text(formatKg(r.mermaKg))),
                      DataCell(Text('${formatNum(r.mermaP)}%')),
                    ])),
                DataRow(
                  color: WidgetStateProperty.all(cs.secondaryContainer),
                  cells: [
                    if (mostrarCliente) const DataCell(Text('')),
                    const DataCell(Text('TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalCanIn),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatKg(totalPesoIn),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatNum(totalCanOut),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatKg(totalPesoOut),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(formatKg(totalMermaKg),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text('${formatNum(totalMermaP)}%',
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

// ── Bar chart ──────────────────────────────────────────────────────────────

class _PesoBarChart extends StatelessWidget {
  final List<_RendRow> rows;
  final Color colorIn;
  final Color colorOut;
  final Color colorMerma;
  final bool mostrarCliente;

  const _PesoBarChart({
    required this.rows,
    required this.colorIn,
    required this.colorOut,
    required this.colorMerma,
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
                final r = rows[idx];
                final label = mostrarCliente
                    ? '${_abbr(r.clienteNombre)}\n${_abbr(r.rangoNombre)}'
                    : _abbr(r.rangoNombre);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center),
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
              final r = rows[group.x];
              final labels = ['Ingresado', 'Despachado', 'Merma'];
              final canLabel = rodIdx == 0
                  ? '${formatNum(r.canIn)} canast.'
                  : rodIdx == 1
                      ? '${formatNum(r.canOut)} canast.'
                      : '';
              return BarTooltipItem(
                '${labels[rodIdx]}\n${formatKg(rod.toY)}'
                '${canLabel.isNotEmpty ? '\n$canLabel' : ''}',
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

class _RendRow {
  final String clienteNombre;
  final String rangoNombre;
  final int canIn;
  final int canOut;
  final double pesoIn;
  final double pesoOut;
  final double mermaKg;
  final double mermaP;

  const _RendRow({
    required this.clienteNombre,
    required this.rangoNombre,
    required this.canIn,
    required this.canOut,
    required this.pesoIn,
    required this.pesoOut,
    required this.mermaKg,
    required this.mermaP,
  });
}

// ── Widgets de UI ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

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
            Text(sub, style: const TextStyle(fontSize: 11)),
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
