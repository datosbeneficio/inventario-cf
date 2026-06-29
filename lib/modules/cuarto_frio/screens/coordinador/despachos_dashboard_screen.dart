import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/despacho.dart';
import '../../../../shared/utils/formatters.dart';
import '../supervisor/despacho_detalle_screen.dart';

class DespachosDashboardScreen extends StatelessWidget {
  const DespachosDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final despachos = context.watch<List<Despacho>>();
    final cs = Theme.of(context).colorScheme;

    if (despachos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('Sin despachos registrados',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    final ordenados = List<Despacho>.from(despachos)
      ..sort((a, b) => b.fechaDespacho.compareTo(a.fechaDespacho));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ordenados.length,
      itemBuilder: (ctx, i) => _DespachoCard(despacho: ordenados[i]),
    );
  }
}

// ── Tarjeta de despacho ──────────────────────────────────────────────────────

class _DespachoCard extends StatelessWidget {
  final Despacho despacho;
  const _DespachoCard({required this.despacho});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = despacho;

    final clientes = d.lineas
        .map((l) => l.clienteNombre)
        .toSet()
        .toList()
      ..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DespachoDetalleScreen(despacho: d),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila superior: guía + destino ────────────────────────────
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Guía ${d.guiaNro}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.destinoNombre,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: cs.outlineVariant),
                ],
              ),
              const SizedBox(height: 10),

              // ── Clientes ────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clientes.join(', '),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Placa + fecha/hora ──────────────────────────────────────
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.local_shipping,
                    label: d.placa,
                    color: cs.tertiaryContainer,
                    textColor: cs.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: formatDate(d.fechaDespacho),
                    color: cs.secondaryContainer,
                    textColor: cs.onSecondaryContainer,
                  ),
                  if (d.horaSalida.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.schedule,
                      label: d.horaSalida,
                      color: cs.secondaryContainer,
                      textColor: cs.onSecondaryContainer,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // ── Lotes de producción ─────────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (d.lotePollo.isNotEmpty)
                    _LoteTag(
                      label: 'Pollo: ${d.lotePollo}',
                      vencimiento: d.vencimientoPollo,
                      cs: cs,
                    ),
                  if (d.loteMenudencias.isNotEmpty)
                    _LoteTag(
                      label: 'Menud: ${d.loteMenudencias}',
                      vencimiento: d.vencimientoMenudencias,
                      cs: cs,
                    ),
                ],
              ),

              // ── Totales (resumen sutil) ─────────────────────────────────
              const Divider(height: 16),
              Row(
                children: [
                  _TotalItem(
                      icon: Icons.shopping_basket,
                      value: '${formatNum(d.totalCanastillas)} can.',
                      cs: cs),
                  const SizedBox(width: 16),
                  _TotalItem(
                      icon: Icons.tag,
                      value: '${formatNum(d.totalUnidades)} unid.',
                      cs: cs),
                  const SizedBox(width: 16),
                  _TotalItem(
                      icon: Icons.scale,
                      value: formatKg(d.totalPeso),
                      cs: cs),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }
}

class _LoteTag extends StatelessWidget {
  final String label;
  final DateTime? vencimiento;
  final ColorScheme cs;

  const _LoteTag({
    required this.label,
    required this.vencimiento,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final venc = vencimiento;
    final vencido = venc != null && venc.isBefore(DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined,
            size: 13,
            color: vencido ? cs.error : cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          venc != null ? '$label  →  ${formatDate(venc)}' : label,
          style: TextStyle(
            fontSize: 11,
            color: vencido ? cs.error : cs.onSurfaceVariant,
            fontWeight: vencido ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _TotalItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final ColorScheme cs;
  const _TotalItem({required this.icon, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
