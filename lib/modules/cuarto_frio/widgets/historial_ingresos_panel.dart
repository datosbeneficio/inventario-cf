import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ingreso.dart';
import '../../../shared/models/cliente.dart';
import '../../../shared/models/empresa_config.dart';
import '../../../shared/providers/delete_guard_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/movimiento_tile.dart';
import 'entrada_form.dart';
import 'menudencias_form.dart';

/// Panel de registros de ingresos agrupados por día y bloque.
///
/// [incluirHoy] — cuando true, muestra los registros del día actual en una
///   sección siempre visible en la parte superior, más los días anteriores
///   como secciones colapsables.
///
/// [showEdit] — cuando true, cada tile muestra el botón de edición.
class HistorialIngresosPanel extends StatefulWidget {
  final String rangoTipo;
  final bool incluirHoy;
  final bool showEdit;

  const HistorialIngresosPanel({
    super.key,
    required this.rangoTipo,
    this.incluirHoy = false,
    this.showEdit = false,
  });

  @override
  State<HistorialIngresosPanel> createState() => _HistorialIngresosPanelState();
}

class _HistorialIngresosPanelState extends State<HistorialIngresosPanel> {
  String? _clienteIdFiltro;

  static String _claveDia(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static bool _esHoy(DateTime dt) {
    final hoy = DateTime.now();
    return dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();

    // Filtrar por tipo
    final porTipo =
        todos.where((i) => i.rangoTipo == widget.rangoTipo).toList();

    if (porTipo.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              widget.incluirHoy ? 'Sin registros aún' : 'Sin historial de días anteriores',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Separar hoy de días anteriores
    final hoy = porTipo.where((i) => _esHoy(i.timestamp)).toList();
    final anteriores = porTipo.where((i) => !_esHoy(i.timestamp)).toList();

    // Clientes únicos para filtros (union de hoy + anteriores)
    final clientesMap = <String, String>{};
    for (final i in porTipo) {
      if (i.clienteId.isNotEmpty) clientesMap[i.clienteId] = i.clienteNombre;
    }
    final clientes = clientesMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Reset filtro si el cliente ya no existe
    if (_clienteIdFiltro != null &&
        !clientesMap.containsKey(_clienteIdFiltro)) {
      Future.microtask(() => setState(() => _clienteIdFiltro = null));
    }

    // Aplicar filtro de cliente
    final hoyFiltrado = _clienteIdFiltro == null
        ? hoy
        : hoy.where((i) => i.clienteId == _clienteIdFiltro).toList();
    final anterioresFiltrados = _clienteIdFiltro == null
        ? anteriores
        : anteriores.where((i) => i.clienteId == _clienteIdFiltro).toList();

    // Agrupar días anteriores
    final Map<String, List<Ingreso>> porDia = {};
    for (final i in anterioresFiltrados) {
      porDia.putIfAbsent(_claveDia(i.timestamp), () => []).add(i);
    }
    final diasOrdenados = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Barra de filtros por cliente
        if (clientes.length > 1)
          _FiltroClientes(
            clientes: clientes,
            seleccionado: _clienteIdFiltro,
            onSeleccionado: (id) => setState(() => _clienteIdFiltro = id),
            esAves: widget.rangoTipo == kTipoAves,
          ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // ── Sección de HOY (siempre visible si incluirHoy) ────────────
              if (widget.incluirHoy) ...[
                _SeccionHoy(
                  ingresos: hoyFiltrado,
                  rangoTipo: widget.rangoTipo,
                  showEdit: widget.showEdit,
                ),
              ],

              // ── Días anteriores colapsables ───────────────────────────────
              if (diasOrdenados.isNotEmpty) ...[
                if (widget.incluirHoy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Días anteriores',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ...diasOrdenados.map((dia) {
                  final entradas = porDia[dia]!;
                  final fecha = DateTime.parse(dia);
                  return _DiaTile(
                    fecha: fecha,
                    entradas: entradas,
                    rangoTipo: widget.rangoTipo,
                    showEdit: widget.showEdit,
                  );
                }),
              ],

              // Estado vacío cuando filtro activo no da resultados
              if (widget.incluirHoy &&
                  hoyFiltrado.isEmpty &&
                  diasOrdenados.isEmpty &&
                  _clienteIdFiltro != null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Sin registros para este cliente',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sección de HOY — siempre visible, sin ExpansionTile ──────────────────────

class _SeccionHoy extends StatelessWidget {
  final List<Ingreso> ingresos;
  final String rangoTipo;
  final bool showEdit;

  const _SeccionHoy({
    required this.ingresos,
    required this.rangoTipo,
    required this.showEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = rangoTipo == kTipoAves;

    if (ingresos.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: esAves ? cs.primary : cs.tertiary,
              child: Text(
                'HOY',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: esAves ? cs.onPrimary : cs.onTertiary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sin ingresos hoy',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Agrupar por bloque
    final Map<int, List<Ingreso>> porBloque = {};
    for (final i in ingresos) {
      porBloque.putIfAbsent(i.bloqueNro, () => []).add(i);
    }
    final bloquesOrdenados = porBloque.keys.toList()..sort();

    final totalUnid = ingresos.fold(0, (s, i) => s + i.unidades);
    final totalCan = ingresos.fold(0, (s, i) => s + i.canastillas);
    final totalPeso = ingresos.fold(0.0, (s, i) => s + i.peso);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado "Hoy"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: (esAves ? cs.primary : cs.tertiary).withValues(alpha: 0.12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: esAves ? cs.primary : cs.tertiary,
                  child: Text(
                    'HOY',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: esAves ? cs.onPrimary : cs.onTertiary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hoy — ${formatDateLong(DateTime.now())}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        esAves
                            ? '${formatNum(totalUnid)} unid. · ${formatKg(totalPeso)}'
                            : '${formatNum(totalCan)} can. · ${formatKg(totalPeso)}',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
          ),
          // Bloques
          ...bloquesOrdenados.map((nro) => _BloqueSeccion(
                nro: nro,
                items: porBloque[nro]!,
                esAves: esAves,
                showEdit: showEdit,
              )),
        ],
      ),
    );
  }
}

// ── Tile de un día anterior (colapsable) ──────────────────────────────────────

class _DiaTile extends StatelessWidget {
  final DateTime fecha;
  final List<Ingreso> entradas;
  final String rangoTipo;
  final bool showEdit;

  const _DiaTile({
    required this.fecha,
    required this.entradas,
    required this.rangoTipo,
    required this.showEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esAves = rangoTipo == kTipoAves;

    final totalUnid = entradas.fold(0, (s, i) => s + i.unidades);
    final totalCan = entradas.fold(0, (s, i) => s + i.canastillas);
    final totalPeso = entradas.fold(0.0, (s, i) => s + i.peso);

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
              fontSize: 14,
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
        children: bloquesOrdenados
            .map((nro) => _BloqueSeccion(
                  nro: nro,
                  items: porBloque[nro]!,
                  esAves: esAves,
                  showEdit: showEdit,
                ))
            .toList(),
      ),
    );
  }
}

// ── Sección de un bloque ──────────────────────────────────────────────────────

class _BloqueSeccion extends StatelessWidget {
  final int nro;
  final List<Ingreso> items;
  final bool esAves;
  final bool showEdit;

  const _BloqueSeccion({
    required this.nro,
    required this.items,
    required this.esAves,
    required this.showEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final totalUnid = items.fold(0, (s, i) => s + i.unidades);
    final totalCan = items.fold(0, (s, i) => s + i.canastillas);
    final totalPeso = items.fold(0.0, (s, i) => s + i.peso);

    final deleteCodigoSet = context
        .select<EmpresaConfig, bool>((e) => e.codigoEliminacion.isNotEmpty);
    final deleteDesbloqueado =
        context.select<DeleteGuardProvider, bool>((g) => g.isUnlocked);
    final canDelete = !deleteCodigoSet || deleteDesbloqueado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        ...items.map(
          (i) => MovimientoTile(
            rangoNombre: i.rangoNombre,
            clienteNombre: i.clienteNombre.isNotEmpty ? i.clienteNombre : null,
            unidades: i.unidades,
            peso: i.peso,
            esCola: i.esCola,
            canastillas: i.canastillas,
            timestamp: i.timestamp,
            onEdit: showEdit ? () => _showEditDialog(context, i) : null,
            onDelete: canDelete
                ? () async {
                    final label = esAves
                        ? '${i.rangoNombre} — ${formatNum(i.unidades)} unid.'
                        : '${i.rangoNombre} — ${formatNum(i.canastillas)} canastillas';
                    final ok = await showConfirmDelete(context, label);
                    if (ok) FirestoreService.instance.deleteIngreso(i.id);
                  }
                : null,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Ingreso ingreso) {
    final clientes = context.read<List<Cliente>>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ingreso'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Provider<List<Cliente>>.value(
              value: clientes,
              child: esAves
                  ? EntradaForm(
                      submitLabel: 'Guardar cambios',
                      initialClienteId: ingreso.clienteId,
                      initialRangoId: ingreso.rangoId,
                      initialInputValue: ingreso.esCola
                          ? ingreso.unidades
                          : ingreso.canastillas,
                      initialPeso: ingreso.peso,
                      initialEsCola: ingreso.esCola,
                      onSubmit: ({
                        required clienteId,
                        required clienteNombre,
                        required rangoId,
                        required rangoNombre,
                        required inputValue,
                        required peso,
                        required esCola,
                        required multiplicador,
                      }) async {
                        await FirestoreService.instance.updateIngreso(
                          ingreso.id,
                          canastillas: esCola ? 1 : inputValue,
                          peso: peso,
                          esCola: esCola,
                          unidades: FirestoreService.calcularUnidades(
                              esCola, inputValue, multiplicador),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    )
                  : MenudenciasForm(
                      submitLabel: 'Guardar cambios',
                      initialClienteId: ingreso.clienteId,
                      initialRangoId: ingreso.rangoId,
                      initialCanastillas: ingreso.canastillas,
                      initialPeso: ingreso.peso,
                      onSubmit: ({
                        required clienteId,
                        required clienteNombre,
                        required rangoId,
                        required rangoNombre,
                        required canastillas,
                        required unidades,
                        required peso,
                      }) async {
                        await FirestoreService.instance.updateIngreso(
                          ingreso.id,
                          canastillas: canastillas,
                          peso: peso,
                          esCola: false,
                          unidades: unidades,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
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
    final colorContainer = esAves ? cs.primaryContainer : cs.tertiaryContainer;
    final colorOnContainer =
        esAves ? cs.onPrimaryContainer : cs.onTertiaryContainer;

    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
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
