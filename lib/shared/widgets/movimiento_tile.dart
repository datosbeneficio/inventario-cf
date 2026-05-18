import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class MovimientoTile extends StatelessWidget {
  final String rangoNombre;
  final String? clienteNombre;
  final int unidades;
  final double peso;
  final bool esCola;
  final int canastillas;
  final DateTime timestamp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MovimientoTile({
    super.key,
    required this.rangoNombre,
    required this.unidades,
    required this.peso,
    required this.esCola,
    required this.canastillas,
    required this.timestamp,
    required this.onEdit,
    required this.onDelete,
    this.clienteNombre,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              esCola ? cs.tertiaryContainer : cs.primaryContainer,
          child: Text(
            esCola ? 'C' : '${canastillas}c',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: esCola
                  ? cs.onTertiaryContainer
                  : cs.onPrimaryContainer,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(rangoNombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (clienteNombre != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  clienteNombre!,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSecondaryContainer),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${formatNum(unidades)} unid. · ${formatKg(peso)}${esCola ? ' · COLA' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatTime(timestamp),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Editar',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }
}
