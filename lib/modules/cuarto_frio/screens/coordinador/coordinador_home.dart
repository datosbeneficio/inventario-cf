import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/ciclo_config.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/ciclo_auto_reset_service.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/connectivity_icon.dart';
import '../../models/ingreso.dart';
import '../../models/salida.dart';
import '../../widgets/consolidado_panel.dart';
import 'clientes_screen.dart';
import 'empresa_config_screen.dart';
import 'despachos_dashboard_screen.dart';
import 'reporte_totales_screen.dart';
import 'reporte_rendimiento_screen.dart';

class CoordinadorHome extends StatefulWidget {
  const CoordinadorHome({super.key});

  @override
  State<CoordinadorHome> createState() => _CoordinadorHomeState();
}

class _CoordinadorHomeState extends State<CoordinadorHome> {
  int _tab = 0;

  static const _tabs = [
    _TabInfo(
        label: 'Clientes',
        icon: Icons.business,
        title: 'Clientes y Rangos'),
    _TabInfo(
        label: 'Consolidado',
        icon: Icons.analytics,
        title: 'Inventario Consolidado'),
    _TabInfo(
        label: 'Despachos',
        icon: Icons.local_shipping,
        title: 'Despachos'),
    _TabInfo(
        label: 'Totales',
        icon: Icons.bar_chart,
        title: 'Reporte Totales'),
    _TabInfo(
        label: 'Rendimiento',
        icon: Icons.trending_up,
        title: 'Rendimiento'),
  ];

  @override
  Widget build(BuildContext context) {
    final ciclo = context.watch<CicloConfig>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_tab].title),
        actions: [
          const ConnectivityIcon(),
          const AppLogo(),
          // ── Reiniciar inventario ────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reiniciar inventario del día',
            onPressed: () => _confirmReset(context, ciclo),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Datos de empresa',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const EmpresaConfigScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar datos de prueba',
            onPressed: () => _confirmarLimpieza(context),
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
        children: const [
          ClientesScreen(),
          ConsolidadoPanel(),
          DespachosDashboardScreen(),
          ReporteTotalesScreen(),
          ReporteRendimientoScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs
            .map((t) =>
                NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, CicloConfig ciclo) async {
    // ── Calcular saldos del ciclo actual ──────────────────────────────────
    final ingresos = context
        .read<List<Ingreso>>()
        .where((i) => !i.timestamp.isBefore(ciclo.inicio))
        .toList();
    final salidas = context
        .read<List<Salida>>()
        .where((s) => !s.timestamp.isBefore(ciclo.inicio))
        .toList();

    // Agrupar saldos por clienteId|rangoId (solo canastillas > 0)
    final saldoMap = <String, _RemaneItem>{};
    for (final i in ingresos) {
      final k = '${i.clienteId}|${i.rangoId}';
      final p = saldoMap[k] ??
          (
            clienteId: i.clienteId,
            clienteNombre: i.clienteNombre,
            rangoId: i.rangoId,
            rangoNombre: i.rangoNombre,
            rangoTipo: i.rangoTipo,
            canastillas: 0,
            unidades: 0,
            peso: 0.0,
            esCola: i.esCola,
          );
      saldoMap[k] = (
        clienteId: p.clienteId,
        clienteNombre: p.clienteNombre,
        rangoId: p.rangoId,
        rangoNombre: p.rangoNombre,
        rangoTipo: p.rangoTipo,
        canastillas: p.canastillas + i.canastillas,
        unidades: p.unidades + i.unidades,
        peso: p.peso + i.peso,
        esCola: p.esCola,
      );
    }
    for (final s in salidas) {
      final k = '${s.clienteId}|${s.rangoId}';
      final p = saldoMap[k];
      if (p == null) continue;
      saldoMap[k] = (
        clienteId: p.clienteId,
        clienteNombre: p.clienteNombre,
        rangoId: p.rangoId,
        rangoNombre: p.rangoNombre,
        rangoTipo: p.rangoTipo,
        canastillas: p.canastillas - s.canastillas,
        unidades: p.unidades - s.unidades,
        peso: p.peso - s.peso,
        esCola: p.esCola,
      );
    }

    final conProducto = saldoMap.values
        .where((e) => e.canastillas > 0)
        .toList();

    // ── Sin remanente → diálogo simple ────────────────────────────────────
    if (conProducto.isEmpty) {
      await _showSimpleResetDialog(context, ciclo);
      return;
    }

    // ── Con remanente → diálogo mejorado ──────────────────────────────────
    if (!context.mounted) return;
    // null = cancelado; [] = reiniciar sin trasladar; [items] = trasladar seleccionados
    final result = await showDialog<List<_RemaneItem>>(
      context: context,
      builder: (ctx) => _ResetConRemaneDialog(
        ciclo: ciclo,
        items: conProducto,
      ),
    );

    if (result == null || !context.mounted) return; // cancelado
    final seleccionados = result;

    if (seleccionados.isEmpty) {
      await CicloAutoResetService.ejecutarReset(
          FirestoreService.instance.resetCiclo);
    } else {
      await CicloAutoResetService.ejecutarReset(
          () => FirestoreService.instance.resetCicloConRemanente(seleccionados));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(seleccionados.isEmpty
              ? 'Inventario reiniciado correctamente'
              : 'Inventario reiniciado · ${seleccionados.length} rango(s) trasladado(s) como remanente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSimpleResetDialog(
      BuildContext context, CicloConfig ciclo) async {
    final cs = Theme.of(context).colorScheme;
    final ahora = formatDate(DateTime.now());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.restart_alt, size: 40, color: cs.error),
        title: const Text('Reiniciar inventario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Al reiniciar el inventario:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _BulletItem(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              text: 'Los movimientos anteriores se conservan '
                  'en los reportes históricos.',
            ),
            const SizedBox(height: 4),
            _BulletItem(
              icon: Icons.visibility_off_outlined,
              color: cs.primary,
              text: 'El inventario visible en la app parte '
                  'desde cero a partir de ahora.',
            ),
            const SizedBox(height: 4),
            _BulletItem(
              icon: Icons.warning_amber_outlined,
              color: cs.error,
              text: 'Esta acción no se puede deshacer fácilmente.',
            ),
            if (ciclo.cicloId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ciclo actual iniciado el ${formatDate(ciclo.inicio)}',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '¿Confirmas el reinicio del inventario para el $ahora?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar ahora'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await CicloAutoResetService.ejecutarReset(
          FirestoreService.instance.resetCiclo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventario reiniciado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmarLimpieza(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    // Primera confirmación
    final paso1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_sweep_outlined, size: 40, color: cs.error),
        title: const Text('Limpiar datos de prueba'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción eliminará permanentemente:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _BulletItem(
              icon: Icons.delete_forever,
              color: cs.error,
              text: 'Todos los ingresos (cf_ingresos)',
            ),
            const SizedBox(height: 4),
            _BulletItem(
              icon: Icons.delete_forever,
              color: cs.error,
              text: 'Todas las salidas (cf_salidas)',
            ),
            const SizedBox(height: 4),
            _BulletItem(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              text: 'Clientes, conductores, destinos y vehículos: intactos.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Esta acción NO se puede deshacer.',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (paso1 != true || !context.mounted) return;

    // Segunda confirmación
    final paso2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, size: 40, color: cs.error),
        title: const Text('¿Estás absolutamente seguro?'),
        content: const Text(
          'Se eliminarán TODOS los ingresos y salidas registrados. '
          'Los reportes históricos también quedarán vacíos. '
          '\n\n¿Confirmas la limpieza total?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, limpiar todo'),
          ),
        ],
      ),
    );

    if (paso2 != true || !context.mounted) return;

    await CicloAutoResetService.ejecutarReset(
        FirestoreService.instance.limpiarDatosPrueba);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de prueba eliminados. Inventario en cero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _BulletItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _BulletItem(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  final String title;
  const _TabInfo(
      {required this.label, required this.icon, required this.title});
}

// ── Diálogo de reset con remanente ────────────────────────────────────────────

typedef _RemaneItem = ({
  String clienteId,
  String clienteNombre,
  String rangoId,
  String rangoNombre,
  String rangoTipo,
  int canastillas,
  int unidades,
  double peso,
  bool esCola,
});

class _ResetConRemaneDialog extends StatefulWidget {
  final CicloConfig ciclo;
  final List<_RemaneItem> items;

  const _ResetConRemaneDialog({
    required this.ciclo,
    required this.items,
  });

  @override
  State<_ResetConRemaneDialog> createState() =>
      _ResetConRemaneDialogState();
}

class _ResetConRemaneDialogState extends State<_ResetConRemaneDialog> {
  late final List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selCount = _checked.where((c) => c).length;

    return AlertDialog(
      icon: Icon(Icons.inventory_2_outlined,
          size: 40, color: cs.tertiary),
      title: const Text('Hay producto en inventario'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quedan canastillas en el cuarto frío. '
              '¿Qué hacer con ellas al reiniciar?',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(
                  children: widget.items.asMap().entries.map((e) {
                    final idx = e.key;
                    final item = e.value;
                    return CheckboxListTile(
                      dense: true,
                      value: _checked[idx],
                      onChanged: (v) =>
                          setState(() => _checked[idx] = v ?? false),
                      title: Text(
                        '${item.clienteNombre} — ${item.rangoNombre}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${formatNum(item.canastillas)} can. · '
                        '${formatNum(item.unidades)} unid. · '
                        '${formatKg(item.peso)}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                      secondary: Icon(Icons.label_important,
                          color: cs.tertiary, size: 18),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selCount > 0
                    ? '$selCount rango(s) seleccionado(s) se trasladarán '
                        'al nuevo ciclo como "Remanente día anterior".'
                    : 'Sin selección: el inventario se reiniciará desde cero.',
                style: TextStyle(
                    fontSize: 12, color: cs.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: () {
            final selected = widget.items
                .asMap()
                .entries
                .where((e) => _checked[e.key])
                .map((e) => e.value)
                .toList();
            Navigator.pop(context, selected);
          },
          icon: const Icon(Icons.restart_alt, size: 16),
          label: Text(selCount > 0
              ? 'Reiniciar y trasladar'
              : 'Reiniciar desde cero'),
        ),
      ],
    );
  }
}
