import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ingreso.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/movimiento_tile.dart';

/// Panel de historial de ingresos agrupados por día y bloque.
/// Solo muestra días anteriores al día actual.
/// Incluye barra de filtros por cliente.
class HistorialIngresosPanel extends StatefulWidget {
  final String rangoTipo;
  const HistorialIngresosPanel({super.key, required this.rangoTipo});

  @override
  State<HistorialIngresosPanel> createState() => _HistorialIngresosPanelState();
}

class _HistorialIngresosPanelState extends State<HistorialIngresosPanel> {
  /// null = todos los clientes
  String? _clienteIdFiltro;

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = DateTime.now();

    // Solo ingresos del tipo correcto y de días anteriores al hoy
    final historicos = todos.where((i) {
      if (i.rangoTipo != widget.rangoTipo) return false;
      final t = i.timestamp;
      return !(t.year == hoy.year &&
          t.month == hoy.month &&
          t.day == hoy.day);
    }).toList();

    if (historicos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            const Text('Sin historial de días anteriores',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Clientes únicos presentes en el historial (orden alfabético)
    final clientesMap = <String, String>{}; // id → nombre
    for (final i in historicos) {
      if (i.clienteId.isNotEmpty) {
        clientesMap[i.clienteId] = i.clienteNombre;
      }
    }
    final clientes = clientesMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Si el filtro seleccionado ya no existe en el historial, resetear
    if (_clienteIdFiltro != null &&
        !clientesMap.containsKey(_clienteIdFiltro)) {
      _clienteIdFiltro = null;
    }

    // Aplicar filtro
    final filtrados = _clienteIdFiltro == null
        ? historicos
        : historicos.where((i) => i.clienteId == _clienteIdFiltro).toList();

    // Agrupar por día (clave: 'yyyy-MM-dd')
    final Map<String, List<Ingreso>> porDia = {};
    for (final i in filtrados) {
      final k = _claveDia(i.timestamp);
      porDia.putIfAbsent(k, () => []).add(i);
    }

    // Ordenar días de más reciente a más antiguo
    final diasOrdenados = porDia.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // ── Barra de filtros ───────────────────────────────────────────
        if (clientes.length > 1) _FiltroClientes(
          clientes: clientes,
          seleccionado: _clienteIdFiltro,
          onSeleccionado: (id) => setState(() => _clienteIdFiltro = id),
          esAves: widget.rangoTipo == kTipoAves,
        ),

        // ── Lista de días ──────────────────────────────────────────────
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_off,
                          size: 40,
                          color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 10),
                      const Text('Sin registros para este cliente',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: diasOrdenados.length,
                  itemBuilder: (ctx, idx) {
                    final dia = diasOrdenados[idx];
                    final entradas = porDia[dia]!;
                    final fecha = DateTime.parse(dia);
                    final totalUnid =
                        entradas.fold(0, (s, i) => s + i.unidades);
                    final totalCan =
                        entradas.fold(0, (s, i) => s + i.canastillas);
                    final totalPeso =
                        entradas.fold(0.0, (s, i) => s + i.peso);

                    return _DiaTile(
                      fecha: fecha,
                      entradas: entradas,
                      totalUnid: totalUnid,
                      totalCan: totalCan,
                      totalPeso: totalPeso,
                      rangoTipo: widget.rangoTipo,
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _claveDia(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ── Barra de filtros por cliente ──────────────────────────────────────────────

class _FiltroClientes extends StatelessWidget {
  final List<MapEntry<String, String>> clientes;
  final String? seleccionado;
  final ValueChanged<String?> onSeleccionado;
  final bool esAves;

  const _FiltroClientes({
    required this.clientes,
    required this.seleccionado,
    required this.onSeleccionado,
    required this.esAves,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = esAves ? cs.primary : cs.tertiary;
    final colorContainer =
        esAves ? cs.primaryContainer : cs.tertiaryContainer;
    final colorOnContainer =
        esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer;

    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip "Todos"
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('Todos'),
                selected: seleccionado == null,
                onSelected: (_) => onSeleccionado(null),
                selectedColor: colorContainer,
                checkmarkColor: colorOnContainer,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: seleccionado == null ? colorOnContainer : null,
                  fontWeight: seleccionado == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                side: BorderSide(
                  color: seleccionado == null ? color : cs.outlineVariant,
                  width: seleccionado == null ? 1.5 : 1,
                ),
                showCheckmark: seleccionado == null,
              ),
            ),
            // Un chip por cliente
            ...clientes.map((entry) {
              final isSelected = seleccionado == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) =>
                      onSeleccionado(isSelected ? null : entry.key),
                  selectedColor: colorContainer,
                  checkmarkColor: colorOnContainer,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? colorOnContainer : null,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? color : cs.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                  showCheckmark: isSelected,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Tile de un día ────────────────────────────────────────────────────────────

class _DiaTile extends StatelessWidget {
  final DateTime fecha;
  final List<Ingreso> entradas;
  final int totalUnid;
  final int totalCan;
  final double totalPeso;
  final String rangoTipo;

  const _DiaTile({
    required this.fecha,
    required this.entradas,
    required this.totalUnid,
    required this.totalCan,
    required this.totalPeso,
    required this.rangoTipo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = rangoTipo == kTipoAves;

    // Agrupar por bloque dentro del día
    final Map<int, List<Ingreso>> porBloque = {};
    for (final i in entradas) {
      porBloque.putIfAbsent(i.bloqueNro, () => []).add(i);
    }
    final bloquesOrdenados = porBloque.keys.toList()..sort();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor:
              esAves ? cs.primaryContainer : cs.tertiaryContainer,
          child: Text(
            fecha.day.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer,
            ),
          ),
        ),
        title: Text(
          formatDateLong(fecha),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          esAves
              ? '${formatNum(totalUnid)} unid. · ${formatKg(totalPeso)}'
              : '${formatNum(totalCan)} can. · ${formatKg(totalPeso)}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${bloquesOrdenados.length} bloque${bloquesOrdenados.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ],
        ),
        children: bloquesOrdenados.map((nro) {
          final bItems = porBloque[nro]!;
          final bUnid = bItems.fold(0, (s, i) => s + i.unidades);
          final bCan = bItems.fold(0, (s, i) => s + i.canastillas);
          final bPeso = bItems.fold(0.0, (s, i) => s + i.peso);

          return _BloqueSeccion(
            nro: nro,
            items: bItems,
            totalUnid: bUnid,
            totalCan: bCan,
            totalPeso: bPeso,
            esAves: esAves,
          );
        }).toList(),
      ),
    );
  }
}

// ── Seccion de un bloque dentro del dia expandido ─────────────────────────────

class _BloqueSeccion extends StatelessWidget {
  final int nro;
  final List<Ingreso> items;
  final int totalUnid;
  final int totalCan;
  final double totalPeso;
  final bool esAves;

  const _BloqueSeccion({
    required this.nro,
    required this.items,
    required this.totalUnid,
    required this.totalCan,
    required this.totalPeso,
    required this.esAves,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado del bloque
        Container(
          color: cs.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.workspaces_outlined,
                  size: 14, color: esAves ? cs.primary : cs.tertiary),
              const SizedBox(width: 6),
              Text(
                'Bloque $nro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: esAves ? cs.primary : cs.tertiary,
                ),
              ),
              const Spacer(),
              Text(
                esAves
                    ? '${formatNum(totalUnid)} unid. · ${formatKg(totalPeso)}'
                    : '${formatNum(totalCan)} can. · ${formatKg(totalPeso)}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // Entradas del bloque (solo lectura — sin botones de accion)
        ...items.map(
          (i) => MovimientoTile(
            rangoNombre: i.rangoNombre,
            clienteNombre:
                i.clienteNombre.isNotEmpty ? i.clienteNombre : null,
            unidades: i.unidades,
            peso: i.peso,
            esCola: i.esCola,
            canastillas: i.canastillas,
            timestamp: i.timestamp,
          ),
        ),
      ],
    );
  }
}
