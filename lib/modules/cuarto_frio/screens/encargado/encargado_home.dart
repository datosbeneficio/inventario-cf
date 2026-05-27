import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../../../shared/models/cliente.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../widgets/consolidado_panel.dart';
import '../../widgets/entrada_form.dart';
import '../../widgets/inventario_panel.dart';
import '../../widgets/historial_ingresos_panel.dart';
import '../../../../shared/widgets/movimiento_tile.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/calculadora_dialog.dart';
import '../../../../shared/widgets/connectivity_icon.dart';
import '../../../../shared/widgets/refresh_cache_button.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/delete_guard_button.dart';
import '../../../../shared/models/empresa_config.dart';
import '../../../../shared/providers/delete_guard_provider.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/utils/constants.dart';

class EncargadoHome extends StatefulWidget {
  const EncargadoHome({super.key});

  @override
  State<EncargadoHome> createState() => _EncargadoHomeState();
}

class _EncargadoHomeState extends State<EncargadoHome> {
  int _tab = 0;
  int _bloqueActual = 1;

  static const _titles = [
    'Inventario Aves',
    'Registrar Ingreso',
    'Historial',
    'Consolidado',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarBloque());
  }

  void _sincronizarBloque() {
    if (!mounted) return;
    final hoy = DateTime.now();
    final ingresos = context.read<List<Ingreso>>();
    int max = 1;
    for (final i in ingresos) {
      if (i.rangoTipo == kTipoAves &&
          i.timestamp.year == hoy.year &&
          i.timestamp.month == hoy.month &&
          i.timestamp.day == hoy.day) {
        if (i.bloqueNro > max) max = i.bloqueNro;
      }
    }
    if (max != _bloqueActual) setState(() => _bloqueActual = max);
  }

  void _nuevoBloque() {
    setState(() => _bloqueActual++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bloque $_bloqueActual iniciado'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          const ConnectivityIcon(),
          const AppLogo(),
          const RefreshCacheButton(),
          const DeleteGuardButton(),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculadora',
            onPressed: () => showCalculadora(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const InventarioPanel(soloTipo: kTipoAves),
          _IngresoAvesBody(
            bloqueActual: _bloqueActual,
            onNuevoBloque: _nuevoBloque,
          ),
          const HistorialIngresosPanel(rangoTipo: kTipoAves),
          const ConsolidadoPanel(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Inventario'),
          NavigationDestination(
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box),
              label: 'Registrar'),
          NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Historial'),
          NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Consolidado'),
        ],
      ),
    );
  }
}

// ── Pestaña de registro de ingreso de aves ────────────────────────────────────

class _IngresoAvesBody extends StatelessWidget {
  final int bloqueActual;
  final VoidCallback onNuevoBloque;

  const _IngresoAvesBody({
    required this.bloqueActual,
    required this.onNuevoBloque,
  });

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = DateTime.now();
    final hoysIngresos = todos
        .where((i) =>
            i.rangoTipo == kTipoAves &&
            i.timestamp.year == hoy.year &&
            i.timestamp.month == hoy.month &&
            i.timestamp.day == hoy.day)
        .toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final form = _FormPanel(
          bloqueActual: bloqueActual,
          onNuevoBloque: onNuevoBloque,
        );
        final list = _ListaIngresos(ingresos: hoysIngresos);
        if (constraints.maxWidth >= 700) {
          return Row(children: [
            SizedBox(width: 380, child: form),
            const VerticalDivider(width: 1),
            Expanded(child: list),
          ]);
        }
        return Column(children: [
          Expanded(flex: 3, child: form),
          const Divider(),
          Expanded(flex: 2, child: list),
        ]);
      },
    );
  }
}

// ── Formulario ────────────────────────────────────────────────────────────────

class _FormPanel extends StatelessWidget {
  final int bloqueActual;
  final VoidCallback onNuevoBloque;

  const _FormPanel({
    required this.bloqueActual,
    required this.onNuevoBloque,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: Icon(Icons.workspaces_outlined,
                    size: 14, color: cs.onPrimaryContainer),
                label: Text(
                  'Bloque $bloqueActual en curso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                backgroundColor: cs.primaryContainer,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_box_outlined, size: 16),
                label: const Text('Nuevo bloque'),
                onPressed: onNuevoBloque,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Registrar Ingreso',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          EntradaForm(
            submitLabel: 'Registrar Ingreso',
            onSubmit: ({
              required clienteId,
              required clienteNombre,
              required rangoId,
              required rangoNombre,
              required inputValue,
              required peso,
              required esCola,
              required multiplicador,
            }) =>
                FirestoreService.instance.addIngreso(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              rangoId: rangoId,
              rangoNombre: rangoNombre,
              rangoTipo: kTipoAves,
              canastillas: esCola ? 1 : inputValue,
              peso: peso,
              esCola: esCola,
              unidades: FirestoreService.calcularUnidades(
                  esCola, inputValue, multiplicador),
              bloqueNro: bloqueActual,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de ingresos del día agrupada por bloque ─────────────────────────────

class _ListaIngresos extends StatefulWidget {
  final List<Ingreso> ingresos;
  const _ListaIngresos({required this.ingresos});

  @override
  State<_ListaIngresos> createState() => _ListaIngresosState();
}

class _ListaIngresosState extends State<_ListaIngresos> {
  String? _clienteFiltro;

  @override
  Widget build(BuildContext context) {
    if (widget.ingresos.isEmpty) {
      return const Center(child: Text('Sin ingresos de aves hoy'));
    }

    final cs = Theme.of(context).colorScheme;
    final deleteCodigoSet = context
        .select<EmpresaConfig, bool>((e) => e.codigoEliminacion.isNotEmpty);
    final deleteDesbloqueado =
        context.select<DeleteGuardProvider, bool>((g) => g.isUnlocked);
    final canDelete = !deleteCodigoSet || deleteDesbloqueado;

    // Clientes únicos del día
    final clientesMap = <String, String>{};
    for (final i in widget.ingresos) {
      if (i.clienteId.isNotEmpty) clientesMap[i.clienteId] = i.clienteNombre;
    }
    final clientesOrdenados = clientesMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Reset filtro si el cliente ya no aparece
    if (_clienteFiltro != null && !clientesMap.containsKey(_clienteFiltro)) {
      Future.microtask(() => setState(() => _clienteFiltro = null));
    }

    final ingresos = _clienteFiltro == null
        ? widget.ingresos
        : widget.ingresos.where((i) => i.clienteId == _clienteFiltro).toList();

    final totalUnid = ingresos.fold(0, (s, i) => s + i.unidades);
    final totalPeso = ingresos.fold(0.0, (s, i) => s + i.peso);

    final Map<int, List<Ingreso>> porBloque = {};
    for (final i in ingresos) {
      porBloque.putIfAbsent(i.bloqueNro, () => []).add(i);
    }
    final bloques = porBloque.keys.toList()..sort();

    final List<Widget> items = [];

    // Chips de filtro por cliente (solo si hay más de uno)
    if (clientesOrdenados.length > 1) {
      items.add(Container(
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
                  selected: _clienteFiltro == null,
                  onSelected: (_) => setState(() => _clienteFiltro = null),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _clienteFiltro == null ? cs.onPrimaryContainer : null,
                    fontWeight: _clienteFiltro == null ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _clienteFiltro == null ? cs.primary : cs.outlineVariant,
                    width: _clienteFiltro == null ? 1.5 : 1,
                  ),
                  showCheckmark: _clienteFiltro == null,
                ),
              ),
              ...clientesOrdenados.map((entry) {
                final sel = _clienteFiltro == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: sel,
                    onSelected: (_) => setState(
                        () => _clienteFiltro = sel ? null : entry.key),
                    selectedColor: cs.primaryContainer,
                    checkmarkColor: cs.onPrimaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: sel ? cs.onPrimaryContainer : null,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: sel ? cs.primary : cs.outlineVariant,
                      width: sel ? 1.5 : 1,
                    ),
                    showCheckmark: sel,
                  ),
                );
              }),
            ],
          ),
        ),
      ));
    }

    items.add(Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Text('Ingresos de hoy (${ingresos.length})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${formatNum(totalUnid)} unidades',
                  style: const TextStyle(fontSize: 12)),
              Text(formatKg(totalPeso),
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    ));

    for (final nro in bloques) {
      final entries = porBloque[nro]!;
      final bUnid = entries.fold(0, (s, i) => s + i.unidades);
      final bPeso = entries.fold(0.0, (s, i) => s + i.peso);
      final esUltimo = nro == bloques.last;

      items.add(ExpansionTile(
        initiallyExpanded: esUltimo,
        leading: Icon(Icons.workspaces_outlined, size: 18, color: cs.primary),
        title: Text(
          'Bloque $nro',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cs.primary),
        ),
        subtitle: Text(
          '${formatNum(bUnid)} unid. · ${formatKg(bPeso)}',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        collapsedBackgroundColor: cs.surfaceContainerLow,
        backgroundColor: cs.surfaceContainerLowest,
        children: entries.map((ingreso) => MovimientoTile(
          rangoNombre: ingreso.rangoNombre,
          clienteNombre: ingreso.clienteNombre.isNotEmpty
              ? ingreso.clienteNombre
              : null,
          unidades: ingreso.unidades,
          peso: ingreso.peso,
          esCola: ingreso.esCola,
          canastillas: ingreso.canastillas,
          timestamp: ingreso.timestamp,
          onEdit: () => _showEditDialog(context, ingreso),
          onDelete: canDelete
              ? () async {
                  final ok = await showConfirmDelete(
                      context,
                      '${ingreso.rangoNombre} — '
                      '${formatNum(ingreso.unidades)} unid.');
                  if (ok) {
                    FirestoreService.instance.deleteIngreso(ingreso.id);
                  }
                }
              : null,
        )).toList(),
      ));
    }

    items.add(const SizedBox(height: 16));
    return ListView(children: items);
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
              child: EntradaForm(
                submitLabel: 'Guardar cambios',
                initialClienteId: ingreso.clienteId,
                initialRangoId: ingreso.rangoId,
                initialInputValue:
                    ingreso.esCola ? ingreso.unidades : ingreso.canastillas,
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
