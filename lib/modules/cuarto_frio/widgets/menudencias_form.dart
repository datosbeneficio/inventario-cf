import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/ciclo_config.dart';
import '../../../shared/models/cliente.dart';
import '../models/ingreso.dart';
import '../models/rango.dart';
import '../models/salida.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/utils/constants.dart';
import '../../../shared/utils/formatters.dart';

typedef OnSubmitMenudencias = Future<void> Function({
  required String clienteId,
  required String clienteNombre,
  required String rangoId,
  required String rangoNombre,
  required int canastillas,
  required int unidades,
  required double peso,
});

class MenudenciasForm extends StatefulWidget {
  final OnSubmitMenudencias onSubmit;
  final String submitLabel;

  /// Si es true, filtra los rangos a sólo los que tienen stock disponible
  /// y valida que canastillas/peso no excedan el inventario real.
  final bool soloConInventario;

  final String? initialClienteId;
  final String? initialRangoId;
  final int? initialCanastillas;
  final double? initialPeso;

  const MenudenciasForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.soloConInventario = false,
    this.initialClienteId,
    this.initialRangoId,
    this.initialCanastillas,
    this.initialPeso,
  });

  @override
  State<MenudenciasForm> createState() => _MenudenciasFormState();
}

// Saldo disponible por (clienteId|rangoId)
typedef _Saldo = ({int canastillas, int unidades, double peso});

class _MenudenciasFormState extends State<MenudenciasForm> {
  final _formKey = GlobalKey<FormState>();
  String? _clienteId;
  String? _rangoId;
  Rango? _rangoObj;
  final _canastillasCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _submitting = false;
  bool _showRangoError = false;

  // Se puebla en build() cuando soloConInventario == true
  Map<String, _Saldo> _saldoMap = {};

  bool get _esPaquetes => _rangoObj?.esPaquetes ?? false;
  int get _canastillas => int.tryParse(_canastillasCtrl.text) ?? 0;
  int get _preview => _esPaquetes
      ? FirestoreService.calcularUnidades(false, _canastillas, _rangoObj!.multiplicador)
      : _canastillas;

  _Saldo? get _saldoActual {
    if (_clienteId == null || _rangoObj == null) return null;
    return _saldoMap['$_clienteId|${_rangoObj!.id}'];
  }

  @override
  void initState() {
    super.initState();
    _clienteId = widget.initialClienteId;
    _rangoId = widget.initialRangoId;
    if (widget.initialCanastillas != null) {
      _canastillasCtrl.text = widget.initialCanastillas.toString();
    }
    if (widget.initialPeso != null) {
      _pesoCtrl.text = widget.initialPeso.toString();
    }
  }

  @override
  void dispose() {
    _canastillasCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  static Map<String, _Saldo> _buildSaldoMap(
      List<Ingreso> ingresos, List<Salida> salidas) {
    final m = <String, _Saldo>{};
    for (final i in ingresos) {
      if (i.rangoTipo != kTipoMenudencias) continue;
      final k = '${i.clienteId}|${i.rangoId}';
      final p = m[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      m[k] = (
        canastillas: p.canastillas + i.canastillas,
        unidades: p.unidades + i.unidades,
        peso: p.peso + i.peso,
      );
    }
    for (final s in salidas) {
      if (s.rangoTipo != kTipoMenudencias) continue;
      final k = '${s.clienteId}|${s.rangoId}';
      final p = m[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      m[k] = (
        canastillas: p.canastillas - s.canastillas,
        unidades: p.unidades - s.unidades,
        peso: p.peso - s.peso,
      );
    }
    return m;
  }

  Future<void> _submit(List<Cliente> clientes) async {
    if (_rangoObj == null) { setState(() => _showRangoError = true); }
    if (!_formKey.currentState!.validate() || _rangoObj == null ||
        _clienteId == null) { return; }
    final cliente = clientes.firstWhere((c) => c.id == _clienteId);
    final canastillas = _canastillas;
    final unidades = _esPaquetes
        ? FirestoreService.calcularUnidades(
            false, canastillas, _rangoObj!.multiplicador)
        : canastillas;

    setState(() => _submitting = true);
    await widget.onSubmit(
      clienteId: cliente.id,
      clienteNombre: cliente.nombre,
      rangoId: _rangoObj!.id,
      rangoNombre: _rangoObj!.nombre,
      canastillas: canastillas,
      unidades: unidades,
      peso: double.parse(_pesoCtrl.text.replaceAll(',', '.')),
    );
    if (mounted) {
      setState(() {
        _submitting = false;
        if (widget.initialRangoId == null) {
          _canastillasCtrl.clear();
          _pesoCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientes = context.watch<List<Cliente>>();

    // Computar saldos del ciclo activo (solo en modo despacho)
    if (widget.soloConInventario) {
      final ciclo = context.watch<CicloConfig>();
      final ingresos = context
          .watch<List<Ingreso>>()
          .where((i) => !i.timestamp.isBefore(ciclo.inicio))
          .toList();
      final salidas = context
          .watch<List<Salida>>()
          .where((s) => !s.timestamp.isBefore(ciclo.inicio))
          .toList();
      _saldoMap = _buildSaldoMap(ingresos, salidas);
    }

    final saldo = _saldoActual;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cliente ──────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Cliente',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            // ignore: deprecated_member_use
            value: clientes.any((c) => c.id == _clienteId) ? _clienteId : null,
            items: clientes
                .map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                .toList(),
            onChanged: (v) => setState(() {
              _clienteId = v;
              _rangoId = null;
              _rangoObj = null;
              _showRangoError = false;
            }),
            validator: (v) => v == null ? 'Selecciona un cliente' : null,
          ),
          const SizedBox(height: 12),

          // ── Chips de rango ────────────────────────────────────────────────
          if (_clienteId != null)
            StreamBuilder<List<Rango>>(
              stream: FirestoreService.instance.rangosStream(_clienteId!).map(
                    (rs) => rs
                        .where((r) => r.tipo == kTipoMenudencias)
                        .toList(),
                  ),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }

                final allRangos = snapshot.data ?? [];
                final rangos = widget.soloConInventario
                    ? allRangos.where((r) {
                        final s = _saldoMap['$_clienteId|${r.id}'];
                        return s != null && s.canastillas > 0;
                      }).toList()
                    : allRangos;

                // Resolver objeto rango cuando llega el stream (modo edición)
                if (_rangoId != null && _rangoObj == null &&
                    rangos.isNotEmpty) {
                  final found =
                      rangos.where((r) => r.id == _rangoId).firstOrNull;
                  if (found != null) {
                    Future.microtask(
                        () { if (mounted) setState(() => _rangoObj = found); });
                  }
                }

                if (rangos.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.soloConInventario
                          ? 'Sin menudencias con inventario disponible'
                          : 'Sin tipos de menudencia configurados para este cliente',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo de menudencia',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: rangos.map((r) {
                        final selected = _rangoId == r.id;
                        return ChoiceChip(
                          avatar: Icon(
                            r.esPaquetes
                                ? Icons.inventory_2
                                : Icons.shopping_basket,
                            size: 16,
                            color: selected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                          label: Text(
                            r.esPaquetes
                                ? '${r.nombre}  ×${formatNum(r.multiplicador)} paq.'
                                : r.nombre,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: selected,
                          selectedColor: cs.tertiaryContainer,
                          checkmarkColor: cs.tertiary,
                          onSelected: (_) => setState(() {
                            _rangoId = r.id;
                            _rangoObj = r;
                            _showRangoError = false;
                            if (widget.initialRangoId == null) {
                              _canastillasCtrl.clear();
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    if (_showRangoError && _rangoObj == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Selecciona un tipo de menudencia',
                          style:
                              TextStyle(color: cs.error, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Primero selecciona un cliente',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),

          // ── Stock disponible (sólo despacho) ─────────────────────────────
          if (widget.soloConInventario && saldo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2,
                        size: 14, color: cs.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _esPaquetes
                            ? 'Disponible: ${formatNum(saldo.canastillas)} canast. · '
                                '${formatNum(saldo.unidades)} paq. · '
                                '${formatKg(saldo.peso)}'
                            : 'Disponible: ${formatNum(saldo.canastillas)} canast. · '
                                '${formatKg(saldo.peso)}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Canastillas ───────────────────────────────────────────────────
          TextFormField(
            controller: _canastillasCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Canastillas',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shopping_basket),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              final n = int.tryParse(v) ?? 0;
              if (n <= 0) return 'Debe ser mayor a 0';
              if (widget.soloConInventario && saldo != null) {
                if (n > saldo.canastillas) {
                  return 'Máximo disponible: ${formatNum(saldo.canastillas)} canast.';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ── Peso ─────────────────────────────────────────────────────────
          TextFormField(
            controller: _pesoCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Peso (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.scale),
              suffixText: 'kg',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) return 'Peso inválido';
              if (widget.soloConInventario && saldo != null) {
                if (parsed > saldo.peso) {
                  return 'Máximo disponible: ${formatKg(saldo.peso)}';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // ── Preview ──────────────────────────────────────────────────────
          if (_rangoObj != null && _canastillas > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _esPaquetes
                    ? '${formatNum(_canastillas)} canast. → ${formatNum(_preview)} paquetes'
                    : '${formatNum(_canastillas)} canastillas a registrar',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onTertiaryContainer),
              ),
            ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _submitting ? null : () => _submit(clientes),
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(widget.submitLabel),
            style: FilledButton.styleFrom(
              backgroundColor: cs.tertiary,
              foregroundColor: cs.onTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
