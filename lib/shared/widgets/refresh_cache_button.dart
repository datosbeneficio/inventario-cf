import 'package:flutter/material.dart';
import '../services/local_cache_service.dart';

/// Botón de AppBar que permite al usuario limpiar el caché local de Firestore
/// (IndexedDB) y recargar la aplicación desde el servidor.
///
/// Útil cuando el inventario muestra datos desactualizados o fantasma
/// en el dispositivo móvil del operario / supervisor.
class RefreshCacheButton extends StatelessWidget {
  const RefreshCacheButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: 'Actualizar datos',
      onPressed: () => _confirmar(context),
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.sync_rounded, size: 40, color: cs.primary),
        title: const Text('Actualizar datos'),
        content: const Text(
          'Esto limpiará los datos guardados en este dispositivo y recargará '
          'la aplicación directamente desde el servidor.\n\n'
          'Usa esta opción si el inventario no se actualiza correctamente '
          'o sigue mostrando datos de días anteriores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Actualizar ahora'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LocalCacheService.limpiarCacheYRecargar();
    }
  }
}
