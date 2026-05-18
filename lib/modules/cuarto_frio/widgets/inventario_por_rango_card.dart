import 'package:flutter/material.dart';
import '../../../shared/utils/formatters.dart';

class InventarioPorRangoCard extends StatelessWidget {
  final String nombre;
  final int unidades;
  final double peso;

  const InventarioPorRangoCard({
    super.key,
    required this.nombre,
    required this.unidades,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esNegativo = unidades < 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: esNegativo ? cs.errorContainer : cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (esNegativo)
                    Text('Stock negativo', style: TextStyle(color: cs.error, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatNum(unidades)} unid.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: esNegativo ? cs.error : cs.primary,
                      ),
                ),
                Text(formatKg(peso),
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
