import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/empresa_config.dart';
import '../providers/delete_guard_provider.dart';

/// Botón de candado en el AppBar.
///
/// Visible solo cuando [EmpresaConfig.codigoEliminacion] está configurado.
/// - 🔒 bloqueado → abre diálogo de código.
/// - 🔓 desbloqueado (rojo) → toca para bloquear de nuevo.
class DeleteGuardButton extends StatelessWidget {
  const DeleteGuardButton({super.key});

  @override
  Widget build(BuildContext context) {
    final codigo =
        context.select<EmpresaConfig, String>((e) => e.codigoEliminacion);

    // Feature desactivada si no hay código
    if (codigo.isEmpty) return const SizedBox.shrink();

    final guard = context.watch<DeleteGuardProvider>();
    final cs = Theme.of(context).colorScheme;

    if (guard.isUnlocked) {
      final mins = guard.minutosRestantes;
      return IconButton(
        icon: Icon(Icons.lock_open, color: cs.error),
        tooltip: 'Eliminación activa — ${mins < 1 ? '<1' : mins} min restante(s)\nToca para bloquear',
        onPressed: () => guard.bloquear(),
      );
    }

    return IconButton(
      icon: Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
      tooltip: 'Desbloquear eliminación de registros',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _UnlockDialog(
          codigoCorrecto: codigo,
          guard: guard,
        ),
      ),
    );
  }
}

// ── Diálogo para ingresar el código ──────────────────────────────────────────

class _UnlockDialog extends StatefulWidget {
  final String codigoCorrecto;
  final DeleteGuardProvider guard;

  const _UnlockDialog({
    required this.codigoCorrecto,
    required this.guard,
  });

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _intentar() {
    final ok =
        widget.guard.intentarDesbloquear(_ctrl.text.trim(), widget.codigoCorrecto);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Código incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.lock_outline, size: 40, color: cs.primary),
      title: const Text('Desbloquear eliminación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ingresa el código de supervisión para activar la eliminación '
            'de registros durante 5 minutos.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Código',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pin_outlined),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _intentar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _intentar,
          child: const Text('Desbloquear'),
        ),
      ],
    );
  }
}
