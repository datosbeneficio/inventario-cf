import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ciclo_config.dart';
import '../models/ingreso.dart';
import '../models/salida.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Panel de inventario consolidado: muestra ingresado, salido y saldo actual
/// agrupado por tipo de producto → cliente → rango, para el ciclo activo.
class ConsolidadoPanel extends StatelessWidget {
  const ConsolidadoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ciclo = context.watch<CicloConfig>();
    final ingresos = context
        .watch<List<Ingreso>>()
        .where((i) => !i.timestamp.isBefore(ciclo.inicio))
        .toList();
    final salidas = context
        .watch<List<Salida>>()
        .where((s) => !s.timestamp.isBefore(ciclo.inicio))
        .toList();

    // ── Construir filas consolidadas ────────────────────────────────────
    final map = <String, _Fila>{};

    for (final i in ingresos) {
      final k = '${i.clienteId}|${i.rangoId}';
      map.putIfAbsent(k, () => _Fila(
            clienteNombre: i.clienteNombre,
            rangoNombre: i.rangoNombre,
            rangoTipo: i.rangoTipo,
          ));
      map[k]!.ingrUnid += i.unidades;
      map[k]!.ingrCan += i.canastillas;
      map[k]!.ingrKg += i.peso;
    }

    for (final s in salidas) {
      final k = '${s.clienteId}|${s.rangoId}';
      map.putIfAbsent(k, () => _Fila(
            clienteNombre: s.clienteNombre,
            rangoNombre: s.rangoNombre,
            rangoTipo: s.rangoTipo,
          ));
      map[k]!.salUnid += s.unidades;
      map[k]!.salCan += s.canastillas;
      map[k]!.salKg += s.peso;
    }

    final filas = map.values.toList()
      ..sort((a, b) {
        final t = a.rangoTipo.compareTo(b.rangoTipo);
        if (t != 0) return t;
        final c = a.clienteNombre.compareTo(b.clienteNombre);
        if (c != 0) return c;
        return a.rangoNombre.compareTo(b.rangoNombre);
      });

    if (filas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Text('Sin movimientos en el ciclo actual',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    // ── Totales globales ─────────────────────────────────────────────────
    final totalIngrUnid = filas.fold(0, (s, f) => s + f.ingrUnid);
    final totalIngrCan = filas.fold(0, (s, f) => s + f.ingrCan);
    final totalIngrKg = filas.fold(0.0, (s, f) => s + f.ingrKg);
    final totalSalUnid = filas.fold(0, (s, f) => s + f.salUnid);
    final totalSalCan = filas.fold(0, (s, f) => s + f.salCan);
    final totalSalKg = filas.fold(0.0, (s, f) => s + f.salKg);
    final saldoUnid = totalIngrUnid - totalSalUnid;
    final saldoCan = totalIngrCan - totalSalCan;
    final saldoKg = totalIngrKg - totalSalKg;

    // ── Filas por tipo ────────────────────────────────────────────────────
    final aves = filas.where((f) => f.rangoTipo == kTipoAves).toList();
    final menus =
        filas.where((f) => f.rangoTipo == kTipoMenudencias).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Ciclo info ────────────────────────────────────────────────────
        _CicloChip(ciclo: ciclo),
        const SizedBox(height: 12),

        // ── Resumen global ────────────────────────────────────────────────
        _ResumenGlobal(
          ingrUnid: totalIngrUnid,
          ingrCan: totalIngrCan,
          ingrKg: totalIngrKg,
          salUnid: totalSalUnid,
          salCan: totalSalCan,
          salKg: totalSalKg,
          saldoUnid: saldoUnid,
          saldoCan: saldoCan,
          saldoKg: saldoKg,
        ),
        const SizedBox(height: 16),

        // ── Aves ──────────────────────────────────────────────────────────
        if (aves.isNotEmpty) ...[
          _SeccionHeader(tipo: kTipoAves),
          const SizedBox(height: 6),
          ...aves.map((f) => _FilaCard(fila: f)),
          _TotalesCard(filas: aves, tipo: kTipoAves),
          const SizedBox(height: 16),
        ],

        // ── Menudencias ───────────────────────────────────────────────────
        if (menus.isNotEmpty) ...[
          _SeccionHeader(tipo: kTipoMenudencias),
          const SizedBox(height: 6),
          ...menus.map((f) => _FilaCard(fila: f)),
          _TotalesCard(filas: menus, tipo: kTipoMenudencias),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── Chip de ciclo ─────────────────────────────────────────────────────────────

class _CicloChip extends StatelessWidget {
  final CicloConfig ciclo;
  const _CicloChip({required this.ciclo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = ciclo.cicloId.isEmpty
        ? 'Ciclo: desde el inicio'
        : 'Ciclo desde ${formatDate(ciclo.inicio)}';
    return Row(
      children: [
        Icon(Icons.refresh, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Resumen global ────────────────────────────────────────────────────────────

class _ResumenGlobal extends StatelessWidget {
  final int ingrUnid, ingrCan, salUnid, salCan, saldoUnid, saldoCan;
  final double ingrKg, salKg, saldoKg;

  const _ResumenGlobal({
    required this.ingrUnid,
    required this.ingrCan,
    required this.ingrKg,
    required this.salUnid,
    required this.salCan,
    required this.salKg,
    required this.saldoUnid,
    required this.saldoCan,
    required this.saldoKg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_downward,
            label: 'Ingresado',
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
            unid: ingrUnid,
            can: ingrCan,
            kg: ingrKg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_upward,
            label: 'Salido',
            color: Colors.orange.shade800,
            bgColor: Colors.orange.shade50,
            unid: salUnid,
            can: salCan,
            kg: salKg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            icon: Icons.inventory_2,
            label: 'En stock',
            color: saldoUnid > 0
                ? Colors.green.shade700
                : Colors.grey.shade600,
            bgColor: saldoUnid > 0
                ? Colors.green.shade50
                : Colors.grey.shade100,
            unid: saldoUnid,
            can: saldoCan,
            kg: saldoKg,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final int unid, can;
  final double kg;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.unid,
    required this.can,
    required this.kg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(
            '${formatNum(unid)} unid.',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text('${formatNum(can)} canast.',
              style: TextStyle(fontSize: 11, color: color)),
          Text(formatKg(kg),
              style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ── Encabezado de sección ─────────────────────────────────────────────────────

class _SeccionHeader extends StatelessWidget {
  final String tipo;
  const _SeccionHeader({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = tipo == kTipoAves;
    return Row(
      children: [
        Icon(
          esAves ? Icons.set_meal : Icons.restaurant,
          size: 18,
          color: esAves ? cs.primary : cs.tertiary,
        ),
        const SizedBox(width: 6),
        Text(
          esAves ? 'Aves en Canal' : 'Menudencias',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: esAves ? cs.primary : cs.tertiary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
              color: esAves ? cs.primary.withValues(alpha: 0.3)
                  : cs.tertiary.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

// ── Tarjeta de una fila (rango-cliente) ───────────────────────────────────────

class _FilaCard extends StatelessWidget {
  final _Fila fila;
  const _FilaCard({required this.fila});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saldoUnid = fila.saldoUnid;
    final saldoColor = saldoUnid > 0
        ? Colors.green.shade700
        : saldoUnid == 0
            ? cs.onSurfaceVariant
            : cs.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de la fila
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fila.rangoNombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Row(children: [
                        Icon(Icons.business,
                            size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(fila.clienteNombre,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tabla ingresado / salido / saldo
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.6), // etiqueta
                1: FlexColumnWidth(1),   // ingresado
                2: FlexColumnWidth(1),   // salido
                3: FlexColumnWidth(1),   // saldo
              },
              children: [
                // Header
                TableRow(children: [
                  const SizedBox.shrink(),
                  _hdr('INGRESADO', Colors.blue.shade700),
                  _hdr('SALIDO', Colors.orange.shade800),
                  _hdr('EN STOCK', saldoColor),
                ]),
                // Unidades
                TableRow(children: [
                  _lbl('Unidades'),
                  _val(formatNum(fila.ingrUnid), Colors.blue.shade700),
                  _val(formatNum(fila.salUnid), Colors.orange.shade800),
                  _val(formatNum(saldoUnid), saldoColor,
                      bold: true),
                ]),
                // Canastillas
                TableRow(children: [
                  _lbl('Canastillas'),
                  _val(formatNum(fila.ingrCan), Colors.blue.shade700),
                  _val(formatNum(fila.salCan), Colors.orange.shade800),
                  _val(formatNum(fila.saldoCan), saldoColor),
                ]),
                // Peso
                TableRow(children: [
                  _lbl('Peso'),
                  _val(formatKg(fila.ingrKg), Colors.blue.shade700),
                  _val(formatKg(fila.salKg), Colors.orange.shade800),
                  _val(formatKg(fila.saldoKg), saldoColor),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _hdr(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: c)),
      );

  static Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(t,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      );

  static Widget _val(String t, Color c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500)),
      );
}

// ── Fila de totales del tipo ──────────────────────────────────────────────────

class _TotalesCard extends StatelessWidget {
  final List<_Fila> filas;
  final String tipo;
  const _TotalesCard({required this.filas, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ingrUnid = filas.fold(0, (s, f) => s + f.ingrUnid);
    final ingrCan = filas.fold(0, (s, f) => s + f.ingrCan);
    final ingrKg = filas.fold(0.0, (s, f) => s + f.ingrKg);
    final salUnid = filas.fold(0, (s, f) => s + f.salUnid);
    final salCan = filas.fold(0, (s, f) => s + f.salCan);
    final salKg = filas.fold(0.0, (s, f) => s + f.salKg);
    final saldoUnid = ingrUnid - salUnid;
    final saldoCan = ingrCan - salCan;
    final saldoKg = ingrKg - salKg;

    final esAves = tipo == kTipoAves;
    final accentColor =
        esAves ? cs.primaryContainer : cs.tertiaryContainer;
    final onAccent =
        esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('SUBTOTAL',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: onAccent)),
          const Spacer(),
          _Pill(
            label: 'Ingr.',
            value: '${formatNum(ingrUnid)} u · ${formatKg(ingrKg)}',
            color: onAccent,
          ),
          const SizedBox(width: 8),
          _Pill(
            label: 'Sal.',
            value: '${formatNum(salUnid)} u · ${formatKg(salKg)}',
            color: onAccent,
          ),
          const SizedBox(width: 8),
          _Pill(
            label: '≡',
            value: '${formatNum(saldoUnid)} u · '
                '${formatNum(saldoCan)} c · ${formatKg(saldoKg)}',
            color: onAccent,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Pill(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.7))),
        Text(value,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

// ── Modelo interno ────────────────────────────────────────────────────────────

class _Fila {
  final String clienteNombre;
  final String rangoNombre;
  final String rangoTipo;
  int ingrUnid = 0;
  int ingrCan = 0;
  double ingrKg = 0;
  int salUnid = 0;
  int salCan = 0;
  double salKg = 0;

  _Fila({
    required this.clienteNombre,
    required this.rangoNombre,
    required this.rangoTipo,
  });

  int get saldoUnid => ingrUnid - salUnid;
  int get saldoCan => ingrCan - salCan;
  double get saldoKg => ingrKg - salKg;
}
