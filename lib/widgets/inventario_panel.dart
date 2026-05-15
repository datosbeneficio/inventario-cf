import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ciclo_config.dart';
import '../models/ingreso.dart';
import '../models/salida.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Muestra el inventario actual (ingresos − salidas) agrupado por
/// tipo → cliente → rango, usando los campos denormalizados de cada documento.
class InventarioPanel extends StatelessWidget {
  /// Si no es null, filtra sólo los movimientos de ese tipo.
  final String? soloTipo;

  const InventarioPanel({super.key, this.soloTipo});

  @override
  Widget build(BuildContext context) {
    final ciclo = context.watch<CicloConfig>();
    // Solo movimientos del ciclo activo
    final ingresos = context
        .watch<List<Ingreso>>()
        .where((i) => !i.timestamp.isBefore(ciclo.inicio))
        .toList();
    final salidas = context
        .watch<List<Salida>>()
        .where((s) => !s.timestamp.isBefore(ciclo.inicio))
        .toList();

    // Agrupar por (clienteId, rangoId) usando campos denormalizados
    final map = <String, _Saldo>{};

    for (final i in ingresos) {
      if (soloTipo != null && i.rangoTipo != soloTipo) continue;
      final key = '${i.clienteId}|${i.rangoId}';
      map.putIfAbsent(
          key,
          () => _Saldo(
                clienteId: i.clienteId,
                rangoId: i.rangoId,
                clienteNombre: i.clienteNombre,
                rangoNombre: i.rangoNombre,
                rangoTipo: i.rangoTipo,
              ));
      map[key]!.unidadesIn += i.unidades;
      map[key]!.canastillasIn += i.canastillas;
      map[key]!.pesoIn += i.peso;
    }

    for (final s in salidas) {
      if (soloTipo != null && s.rangoTipo != soloTipo) continue;
      final key = '${s.clienteId}|${s.rangoId}';
      map.putIfAbsent(
          key,
          () => _Saldo(
                clienteId: s.clienteId,
                rangoId: s.rangoId,
                clienteNombre: s.clienteNombre,
                rangoNombre: s.rangoNombre,
                rangoTipo: s.rangoTipo,
              ));
      map[key]!.unidadesOut += s.unidades;
      map[key]!.canastillasOut += s.canastillas;
      map[key]!.pesoOut += s.peso;
    }

    final entries = map.values.toList()
      ..sort((a, b) {
        final t = a.rangoTipo.compareTo(b.rangoTipo);
        if (t != 0) return t;
        final c = a.clienteNombre.compareTo(b.clienteNombre);
        if (c != 0) return c;
        return a.rangoNombre.compareTo(b.rangoNombre);
      });

    if (entries.isEmpty) {
      return const Center(
        child: Text('Sin movimientos registrados',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // Construir lista plana: header de sección + tarjetas
    final List<Widget> items = [];
    String? lastTipo;
    for (final e in entries) {
      if (e.rangoTipo != lastTipo) {
        items.add(_SectionHeader(tipo: e.rangoTipo));
        lastTipo = e.rangoTipo;
      }
      items.add(_InventarioCard(entry: e));
    }
    items.add(const SizedBox(height: 16));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: items,
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String tipo;
  const _SectionHeader({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = tipo == kTipoAves;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            esAves ? Icons.set_meal : Icons.restaurant,
            size: 16,
            color: esAves ? cs.primary : cs.tertiary,
          ),
          const SizedBox(width: 6),
          Text(
            esAves ? 'Aves en Canal' : 'Menudencias',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: esAves ? cs.primary : cs.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de inventario ─────────────────────────────────────────────────

class _InventarioCard extends StatelessWidget {
  final _Saldo entry;
  const _InventarioCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final saldoUnid = entry.unidadesIn - entry.unidadesOut;
    final saldoCan = entry.canastillasIn - entry.canastillasOut;
    final saldoPeso = entry.pesoIn - entry.pesoOut;

    // Mostrar unidades como valor primario; canastillas como secundario
    // Si ambos son iguales (menudencias canastillas estándar) omitir línea canastillas
    final mostrarCan = saldoCan != saldoUnid;

    final saldoColor = saldoUnid > 0
        ? cs.primary
        : saldoUnid == 0
            ? cs.onSurfaceVariant
            : cs.error;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.rangoNombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.business,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(entry.clienteNombre,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatNum(saldoUnid)} unid.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: saldoColor),
                ),
                if (mostrarCan)
                  Text(
                    '${formatNum(saldoCan)} canast.',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                Text(
                  formatKg(saldoPeso),
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelo interno ─────────────────────────────────────────────────────────

class _Saldo {
  final String clienteId;
  final String rangoId;
  final String clienteNombre;
  final String rangoNombre;
  final String rangoTipo;
  int unidadesIn = 0;
  int unidadesOut = 0;
  int canastillasIn = 0;
  int canastillasOut = 0;
  double pesoIn = 0;
  double pesoOut = 0;

  _Saldo({
    required this.clienteId,
    required this.rangoId,
    required this.clienteNombre,
    required this.rangoNombre,
    required this.rangoTipo,
  });
}
