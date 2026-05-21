import 'package:flutter/material.dart';

/// Abre la calculadora flotante. El formulario subyacente no se altera.
void showCalculadora(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _CalculadoraDialog(),
  );
}

// ── Widget de calculadora ─────────────────────────────────────────────────────

class _CalculadoraDialog extends StatefulWidget {
  const _CalculadoraDialog();

  @override
  State<_CalculadoraDialog> createState() => _CalculadoraDialogState();
}

class _CalculadoraDialogState extends State<_CalculadoraDialog> {
  String _display = '0';
  double? _valor1;
  String? _operador;
  bool _esperandoSegundo = false;
  bool _hayError = false;

  /// Últimas operaciones (más reciente primero). Máx. 8.
  final List<String> _historial = [];
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  void _presionarDigito(String d) {
    setState(() {
      _hayError = false;
      if (_esperandoSegundo) {
        _display = d;
        _esperandoSegundo = false;
      } else {
        _display = (_display == '0') ? d : _display + d;
      }
    });
  }

  void _presionarComa() {
    setState(() {
      _hayError = false;
      if (_esperandoSegundo) {
        _display = '0,';
        _esperandoSegundo = false;
        return;
      }
      if (!_display.contains(',')) { _display += ','; }
    });
  }

  void _presionarOperador(String op) {
    setState(() {
      _hayError = false;
      _valor1 = _parsear(_display);
      _operador = op;
      _esperandoSegundo = true;
    });
  }

  void _presionarIgual() {
    if (_operador == null || _valor1 == null) return;
    final v2 = _parsear(_display);
    double resultado;
    switch (_operador) {
      case '+':
        resultado = _valor1! + v2;
      case '−':
        resultado = _valor1! - v2;
      case '×':
        resultado = _valor1! * v2;
      case '÷':
        if (v2 == 0) {
          setState(() {
            _display = 'Error';
            _hayError = true;
            _valor1 = null;
            _operador = null;
            _esperandoSegundo = false;
          });
          return;
        }
        resultado = _valor1! / v2;
      default:
        return;
    }
    final entrada =
        '${_formatear(_valor1!)} $_operador ${_formatear(v2)} = ${_formatear(resultado)}';
    setState(() {
      _display = _formatear(resultado);
      _historial.insert(0, entrada);
      if (_historial.length > 8) _historial.removeLast();
      _valor1 = null;
      _operador = null;
      _esperandoSegundo = false;
    });
    // Scroll al inicio (entrada más reciente)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _presionarCambioSigno() {
    if (_hayError) return;
    setState(() {
      final v = _parsear(_display);
      _display = _formatear(-v);
    });
  }

  void _presionarBorrar() {
    if (_hayError) {
      _limpiar();
      return;
    }
    setState(() {
      if (_display.length <= 1) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
        if (_display == '-') _display = '0';
      }
    });
  }

  void _limpiar() {
    setState(() {
      _display = '0';
      _valor1 = null;
      _operador = null;
      _esperandoSegundo = false;
      _hayError = false;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _parsear(String s) =>
      double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

  String _formatear(double v) {
    if (v == v.truncateToDouble()) {
      // Sin parte decimal → mostrar como entero
      return v.toStringAsFixed(0);
    }
    // Con decimales → hasta 8 cifras, sin ceros finales
    String s = v.toStringAsFixed(8);
    s = s.replaceAll('.', ',');
    s = s.replaceAll(RegExp(r',?0+$'), '');
    return s;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Row(
        children: [
          Icon(Icons.calculate_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Calculadora',
                  style: TextStyle(fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar',
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Historial de operaciones ──────────────────────────────
            if (_historial.isNotEmpty) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 88),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  shrinkWrap: true,
                  itemCount: _historial.length,
                  itemBuilder: (_, i) => Text(
                    _historial[i],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: i == 0
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: i == 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // ── Display ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Operador activo (pequeño, encima del display)
                  Text(
                    _operador != null
                        ? '${_formatear(_valor1 ?? 0)} $_operador'
                        : '',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _display,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _hayError ? cs.error : cs.onSurface,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Teclado ───────────────────────────────────────────────
            _buildTeclado(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildTeclado(ColorScheme cs) {
    // Colores reutilizables
    final colorNum = cs.surfaceContainerHighest;
    final colorOp = cs.secondaryContainer;
    final colorErr = cs.errorContainer;

    // Botón genérico
    Widget btn(
      String label, {
      required VoidCallback onTap,
      Color? bg,
      Color? fg,
      bool wide = false,
    }) {
      final bgColor = bg ?? colorNum;
      final fgColor = fg ?? cs.onSurface;
      return SizedBox(
        height: 52,
        width: wide ? double.infinity : null,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Fila 1: C, ⌫, ±, ÷
        Row(children: [
          Expanded(
              child: btn('C',
                  onTap: _limpiar,
                  bg: colorErr,
                  fg: cs.onErrorContainer)),
          const SizedBox(width: 6),
          Expanded(
              child: btn('⌫',
                  onTap: _presionarBorrar,
                  bg: colorErr,
                  fg: cs.onErrorContainer)),
          const SizedBox(width: 6),
          Expanded(
              child: btn('±',
                  onTap: _presionarCambioSigno,
                  bg: colorOp,
                  fg: cs.onSecondaryContainer)),
          const SizedBox(width: 6),
          Expanded(
              child: btn('÷',
                  onTap: () => _presionarOperador('÷'),
                  bg: colorOp,
                  fg: cs.onSecondaryContainer)),
        ]),
        const SizedBox(height: 6),

        // Fila 2: 7, 8, 9, ×
        Row(children: [
          Expanded(child: btn('7', onTap: () => _presionarDigito('7'))),
          const SizedBox(width: 6),
          Expanded(child: btn('8', onTap: () => _presionarDigito('8'))),
          const SizedBox(width: 6),
          Expanded(child: btn('9', onTap: () => _presionarDigito('9'))),
          const SizedBox(width: 6),
          Expanded(
              child: btn('×',
                  onTap: () => _presionarOperador('×'),
                  bg: colorOp,
                  fg: cs.onSecondaryContainer)),
        ]),
        const SizedBox(height: 6),

        // Fila 3: 4, 5, 6, −
        Row(children: [
          Expanded(child: btn('4', onTap: () => _presionarDigito('4'))),
          const SizedBox(width: 6),
          Expanded(child: btn('5', onTap: () => _presionarDigito('5'))),
          const SizedBox(width: 6),
          Expanded(child: btn('6', onTap: () => _presionarDigito('6'))),
          const SizedBox(width: 6),
          Expanded(
              child: btn('−',
                  onTap: () => _presionarOperador('−'),
                  bg: colorOp,
                  fg: cs.onSecondaryContainer)),
        ]),
        const SizedBox(height: 6),

        // Fila 4: 1, 2, 3, +
        Row(children: [
          Expanded(child: btn('1', onTap: () => _presionarDigito('1'))),
          const SizedBox(width: 6),
          Expanded(child: btn('2', onTap: () => _presionarDigito('2'))),
          const SizedBox(width: 6),
          Expanded(child: btn('3', onTap: () => _presionarDigito('3'))),
          const SizedBox(width: 6),
          Expanded(
              child: btn('+',
                  onTap: () => _presionarOperador('+'),
                  bg: colorOp,
                  fg: cs.onSecondaryContainer)),
        ]),
        const SizedBox(height: 6),

        // Fila 5: 0 (wide), , (coma), =
        Row(children: [
          Expanded(
            flex: 2,
            child: btn('0',
                onTap: () => _presionarDigito('0'), wide: true),
          ),
          const SizedBox(width: 6),
          Expanded(child: btn(',', onTap: _presionarComa)),
          const SizedBox(width: 6),
          Expanded(
            child: btn('=',
                onTap: _presionarIgual,
                bg: cs.primary,
                fg: cs.onPrimary),
          ),
        ]),
      ],
    );
  }
}
