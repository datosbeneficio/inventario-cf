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

typedef OnSubmitEntrada = Future<void> Function({
  required String clienteId,
  required String clienteNombre,
  required String rangoId,
  required String rangoNombre,
  required int inputValue,
  required double peso,
  required bool esCola,
  required double multiplicador,
});

class EntradaForm extends StatefulWidget {
  final OnSubmitEntrada onSubmit;
  final String submitLabel;

  /// Si es true, filtra los rangos a sólo los que tienen stock disponible
  /// y valida que canastillas/peso no excedan el inventario real.
  final bool soloConInventario;

  final String? initialClienteId;
  final String? initialRangoId;
  final int? initialInputValue;
  final double? initialPeso;
  final bool? initialEsCola;

  const EntradaForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.soloConInventario = false,
    this.initialClienteId,
    this.initialRangoId,
    this.initialInputValue,
    this.initialPeso,
    this.initialEsCola,
  });

  @override
  State<EntradaForm> createState() => _EntradaFormState();
}

// Saldo disponible por (clienteId|rangoId)
typedef _Saldo = ({int canastillas, int unidades, double peso});

class _EntradaFormState extends State<EntradaForm> {
  final _formKey = GlobalKey<FormState>();
  String? _clienteId;
  String? _rangoId;
  Rango? _rangoObj;
  final _inputCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _esCola = false;
  bool _submitting = false;

  // Se puebla en build() cuando soloConInventario == true
  Map<String, _Saldo> _saldoMap = {};

  int get _inputValue => int.tryParse(_inputCtrl.text) ?? 0;

  int get _preview {
    final mult = _rangoObj?.multiplicador ?? 1.0;
    return FirestoreService.calcularUnidades(_esCola, _inputValue, mult);
  }

  _Saldo? get _saldoActual {
    if (_clienteId == null || _rangoObj == null) return null;
    return _saldoMap['$_clienteId|${_rangoObj!.id}'];
  }

  @override
  void initState() {
    super.initState();
    _clienteId = widget.initialClienteId;
    _rangoId = widget.initialRangoId;
    _esCola = widget.initialEsCola ?? false;
    if (widget.initialInputValue != null) {
      _inputCtrl.text = widget.initialInputValue.toString();
    }
    if (widget.initialPeso != null) {
      _pesoCtrl.text = widget.initialPeso.toString();
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  static Map<String, _Saldo> _buildSaldoMap(
      List<Ingreso> ingresos, List<Salida> salidas) {
    final m = <String, _Saldo>{};
    for (final i in ingresos) {
      if (i.rangoTipo != kTipoAves) continue;
      final k = '${i.clienteId}|${i.rangoId}';
      final p = m[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      m[k] = (
        canastillas: p.canastillas + i.canastillas,
        unidades: p.unidades + i.unidades,
        peso: p.peso + i.peso,
      );
    }
    for (final s in salidas) {
      if (s.rangoTipo != kTipoAves) continue;
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
    if (!_formKey.currentState!.validate()) return;
    if (_rangoObj == null || _clienteId == null) return;
    final cliente = clientes.firstWhere((c) => c.id == _clienteId);
    setState(() => _submitting = true);
    await widget.onSubmit(
      clienteId: cliente.id,
      clienteNombre: cliente.nombre,
      rangoId: _rangoObj!.id,
      rangoNombre: _rangoObj!.nombre,
      inputValue: _inputValue,
      peso: double.parse(_pesoCtrl.text.replaceAll(',', '.')),
      esCola: _esCola,
      multiplicador: _rangoObj!.multiplicador,
    );
    if (mounted) {
      setState(() {
        _submitting = false;
        if (widget.initialRangoId == null) {
          _inputCtrl.clear();
          _pesoCtrl.clear();
          _esCola = false;
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
            }),
            validator: (v) => v == null ? 'Selecciona un cliente' : null,
          ),
          const SizedBox(height: 12),

          // ── Rango (dinámico por cliente, filtrado por inventario) ─────────
          if (_clienteId != null)
            StreamBuilder<List<Rango>>(
              stream: FirestoreService.instance.rangosStream(_clienteId!).map(
                    (rs) => rs.where((r) => r.tipo == kTipoAves).toList(),
                  ),
              builder: (ctx, snapshot) {
                final allRangos = snapshot.data ?? [];

                // Filtrar sólo rangos con stock cuando soloConInventario
                final rangos = widget.soloConInventario
                    ? allRangos.where((r) {
                        final s = _saldoMap['$_clienteId|${r.id}'];
                        return s != null && s.unidades > 0;
                      }).toList()
                    : allRangos;

                // Resolver el objeto rango inicial cuando llega el stream
                if (_rangoId != null && _rangoObj == null && rangos.isNotEmpty) {
                  final found =
                      rangos.where((r) => r.id == _rangoId).firstOrNull;
                  if (found != null) {
                    Future.microtask(() {
                      if (mounted) setState(() => _rangoObj = found);
                    });
                  }
                }

                final resolvedValue =
                    rangos.any((r) => r.id == _rangoId) ? _rangoId : null;

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Rango (aves)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.category),
                    suffix: snapshot.connectionState == ConnectionState.waiting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                  ),
                  // ignore: deprecated_member_use
                  value: resolvedValue,
                  items: rangos
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                                '${r.nombre} (×${formatNum(r.multiplicador)})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final sel = rangos.firstWhere((r) => r.id == v);
                    setState(() {
                      _rangoId = v;
                      _rangoObj = sel;
                    });
                  },
                  validator: (v) {
                    if (_clienteId == null) {
                      return 'Primero selecciona un cliente';
                    }
                    if (v == null) return 'Selecciona un rango';
                    return null;
                  },
                );
              },
            )
          else
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Rango (aves)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                hintText: 'Primero selecciona un cliente',
              ),
              items: const [],
              onChanged: null,
              validator: (_) =>
                  _clienteId == null ? 'Primero selecciona un cliente' : null,
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
                        'Disponible: ${formatNum(saldo.canastillas)} canast. · '
                        '${formatNum(saldo.unidades)} unid. · '
                        '${formatKg(saldo.peso)}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Cola toggle ──────────────────────────────────────────────────
          SwitchListTile(
            title: const Text('Tipo Cola'),
            subtitle: Text(_esCola
                ? 'Ingresa las unidades (canastillas = 1)'
                : 'Ingresa las canastillas'),
            value: _esCola,
            onChanged: (v) => setState(() {
              _esCola = v;
              _inputCtrl.clear();
            }),
            tileColor:
                _esCola ? cs.tertiaryContainer.withValues(alpha: 0.3) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
          const SizedBox(height: 12),

          // ── Canastillas / Unidades ───────────────────────────────────────
          TextFormField(
            controller: _inputCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _esCola ? 'Unidades' : 'Canastillas',
              border: const OutlineInputBorder(),
              prefixIcon:
                  Icon(_esCola ? Icons.numbers : Icons.shopping_basket),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              final n = int.tryParse(v) ?? 0;
              if (n <= 0) return 'Debe ser mayor a 0';
              if (widget.soloConInventario && saldo != null) {
                final max = _esCola ? saldo.unidades : saldo.canastillas;
                if (n > max) {
                  return 'Máximo disponible: ${formatNum(max)} '
                      '${_esCola ? 'unid.' : 'canast.'}';
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
          if (_rangoObj != null && _inputValue > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unidades a registrar: ${formatNum(_preview)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer),
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
          ),
        ],
      ),
    );
  }
}
