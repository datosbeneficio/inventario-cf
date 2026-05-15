import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ciclo_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/consolidado_panel.dart';
import 'clientes_screen.dart';
import 'empresa_config_screen.dart';
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
    final cs = Theme.of(context).colorScheme;
    final ahora = formatDate(DateTime.now());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.restart_alt,
            size: 40, color: cs.error),
        title: const Text('Reiniciar inventario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Al reiniciar el inventario:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              text: 'Esta acción no se puede deshacer '
                  'fácilmente.',
            ),
            if (ciclo.cicloId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ciclo actual iniciado el '
                '${formatDate(ciclo.inicio)}',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '¿Confirmas el reinicio del inventario '
              'para el $ahora?',
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
                backgroundColor: cs.error,
                foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar ahora'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await FirestoreService.instance.resetCiclo();
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
