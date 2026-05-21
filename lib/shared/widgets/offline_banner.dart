import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// Banner que aparece en la parte superior de la app cuando no hay conexión,
/// y muestra un aviso breve al reconectar.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showRestored = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged(bool isOnline) {
    if (isOnline && _showRestored == false) {
      // Acaba de reconectar: mostrar banner verde por 3 segundos
      setState(() => _showRestored = true);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showRestored = false);
      });
    } else if (!isOnline) {
      // Perdió conexión: ocultar banner de "restaurada" si estaba visible
      _timer?.cancel();
      if (_showRestored) setState(() => _showRestored = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.select<ConnectivityProvider, bool>(
      (p) => p.isOnline,
    );

    // Detectar cambio para disparar la lógica del banner verde
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onConnectivityChanged(isOnline);
    });

    final showOffline = !isOnline;
    final showRestored = isOnline && _showRestored;
    final visible = showOffline || showRestored;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: visible ? 36 : 0,
      color: showOffline
          ? const Color(0xFFF57F17) // amber[900]
          : const Color(0xFF2E7D32), // green[800]
      child: visible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showOffline ? Icons.wifi_off : Icons.wifi,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  showOffline
                      ? 'Sin conexión — los registros se guardarán al reconectar'
                      : 'Conexión restaurada',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
