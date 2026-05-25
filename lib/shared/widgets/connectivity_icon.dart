import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// Ícono que aparece en el AppBar únicamente cuando no hay conexión.
/// Cuando hay red no ocupa espacio ni es visible.
class ConnectivityIcon extends StatelessWidget {
  const ConnectivityIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.select<ConnectivityProvider, bool>(
      (p) => p.isOnline,
    );
    if (isOnline) return const SizedBox.shrink();
    return Tooltip(
      message: 'Sin conexión — los registros se guardarán al reconectar',
      child: Icon(
        Icons.wifi_off,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
