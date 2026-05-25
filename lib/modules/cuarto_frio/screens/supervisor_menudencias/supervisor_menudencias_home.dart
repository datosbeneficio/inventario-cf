import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingreso.dart';
import '../../../../shared/models/cliente.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../widgets/menudencias_form.dart';
import '../../widgets/inventario_panel.dart';
import '../../widgets/historial_ingresos_panel.dart';
import '../../../../shared/widgets/movimiento_tile.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/calculadora_dialog.dart';
import '../../../../shared/widgets/connectivity_icon.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/utils/constants.dart';
import '../../../../shared/utils/formatters.dart';

class SupervisorMenudenciasHome extends StatefulWidget {
  const SupervisorMenudenciasHome({super.key});

  @override
  State<SupervisorMenudenciasHome> createState() =>
      _SupervisorMenudenciasHomeState();
}

class _SupervisorMenudenciasHomeState
    extends State<SupervisorMenudenciasHome> {
  int _tab = 0;
  int _bloqueActual = 1;

  static const _titles = [
    'Inventario Menudencias',
    'Registrar Ingreso',
    'Historial',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarBloque());
  }

  /// Al iniciar, detecta el bloque más alto del día actual para no
  /// reiniciar el contador si el operario recarga la página.
  void _sincronizarBloque() {
    if (!mounted) return;
    final hoy = DateTime.now();
    final ingresos = context.read<List<Ingreso>>();
    int max = 1;
    for (final i in ingresos) {
      if (i.rangoTipo == kTipoMenudencias &&
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
          const InventarioPanel(soloTipo: kTipoMenudencias),
          _IngresoMenudBody(
            bloqueActual: _bloqueActual,
            onNuevoBloque: _nuevoBloque,
          ),
          const HistorialIngresosPanel(rangoTipo: kTipoMenudencias),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(
              icon: Icon(Icons.add_box), label: 'Registrar'),
          NavigationDestination(
              icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

// ── Pestaña registro de ingreso de menudencias ─────────────────────────────

class _IngresoMenudBody extends StatelessWidget {
  final int bloqueActual;
  final VoidCallback onNuevoBloque;

  const _IngresoMenudBody({
    required this.bloqueActual,
    required this.onNuevoBloque,
  });

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<Ingreso>>();
    final hoy = DateTime.now();
    final hoysIngresos = todos
        .where((i) =>
            i.rangoTipo == kTipoMenudencias &&
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
          // ── Indicador de bloque activo ──────────────────────────────
          Row(
            children: [
              Chip(
                avatar: Icon(Icons.workspaces_outlined,
                    size: 14, color: cs.onTertiaryContainer),
                label: Text(
                  'Bloque $bloqueActual en curso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                backgroundColor: cs.tertiaryContainer,
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
            'Registrar Ingreso — Menudencias',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          MenudenciasForm(
            submitLabel: 'Registrar Ingreso',
            onSubmit: ({
              required clienteId,
              required clienteNombre,
              required rangoId,
              required rangoNombre,
              required canastillas,
              required unidades,
              required peso,
            }) =>
                FirestoreService.instance.addIngreso(
              clienteId: clienteId,
              clienteNombre: clienteNombre,
              rangoId: rangoId,
              rangoNombre: rangoNombre,
              rangoTipo: kTipoMenudencias,
              canastillas: canastillas,
              peso: peso,
              esCola: false,
              unidades: unidades,
              bloqueNro: bloqueActual,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de ingresos del día agrupada por bloque ─────────────────────────────

class _ListaIngresos extends StatelessWidget {
  final List<Ingreso> ingresos;
  const _ListaIngresos({required this.ingresos});

  @override
  Widget build(BuildContext context) {
    if (ingresos.isEmpty) {
      return const Center(child: Text('Sin ingresos de menudencias hoy'));
    }

    final cs = Theme.of(context).colorScheme;
    final totalCan = ingresos.fold(0, (s, i) => s + i.canastillas);
    final totalPeso = ingresos.fold(0.0, (s, i) => s + i.peso);

    // Agrupar por bloque (orden ascendente)
    final Map<int, List<Ingreso>> porBloque = {};
    for (final i in ingresos) {
      porBloque.putIfAbsent(i.bloqueNro, () => []).add(i);
    }
    final bloques = porBloque.keys.toList()..sort();

    // Construir lista plana con encabezados de bloque
    final List<Widget> items = [];

    // Resumen global
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
              Text('${formatNum(totalCan)} canastillas',
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
      final bCan = entries.fold(0, (s, i) => s + i.canastillas);
      final bPeso = entries.fold(0.0, (s, i) => s + i.peso);

      // Encabezado de bloque
      items.add(Container(
        color: cs.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.workspaces_outlined, size: 14, color: cs.tertiary),
            const SizedBox(width: 6),
            Text(
              'Bloque $nro',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.tertiary),
            ),
            const Spacer(),
            Text(
              '${formatNum(bCan)} can. · ${formatKg(bPeso)}',
              style:
                  TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ));

      // Entradas del bloque
      for (final ingreso in entries) {
        items.add(MovimientoTile(
          rangoNombre: ingreso.rangoNombre,
          clienteNombre: ingreso.clienteNombre.isNotEmpty
              ? ingreso.clienteNombre
              : null,
          unidades: ingreso.unidades,
          peso: ingreso.peso,
          esCola: false,
          canastillas: ingreso.canastillas,
          timestamp: ingreso.timestamp,
          onEdit: () => _showEditDialog(context, ingreso),
          onDelete: () async {
            final ok = await showConfirmDelete(
                context,
                '${ingreso.rangoNombre} — '
                '${formatNum(ingreso.canastillas)} canastillas');
            if (ok) {
              FirestoreService.instance.deleteIngreso(ingreso.id);
            }
          },
        ));
      }
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
              child: MenudenciasForm(
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
