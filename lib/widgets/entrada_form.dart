import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cliente.dart';
import '../models/rango.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

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
  final String? initialClienteId;
  final String? initialRangoId;
  final int? initialInputValue;
  final double? initialPeso;
  final bool? initialEsCola;

  const EntradaForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initialClienteId,
    this.initialRangoId,
    this.initialInputValue,
    this.initialPeso,
    this.initialEsCola,
  });

  @override
  State<EntradaForm> createState() => _EntradaFormState();
}

class _EntradaFormState extends State<EntradaForm> {
  final _formKey = GlobalKey<FormState>();
  String? _clienteId;
  String? _rangoId;
  Rango? _rangoObj;
  final _inputCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _esCola = false;
  bool _submitting = false;

  int get _inputValue => int.tryParse(_inputCtrl.text) ?? 0;

  int get _preview {
    final mult = _rangoObj?.multiplicador ?? 1.0;
    return FirestoreService.calcularUnidades(_esCola, _inputValue, mult);
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
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                .toList(),
            onChanged: (v) => setState(() {
              _clienteId = v;
              _rangoId = null;
              _rangoObj = null;
            }),
            validator: (v) => v == null ? 'Selecciona un cliente' : null,
          ),
          const SizedBox(height: 12),

          // ── Rango (dinámico por cliente) ─────────────────────────────────
          if (_clienteId != null)
            StreamBuilder<List<Rango>>(
              stream: FirestoreService.instance.rangosStream(_clienteId!).map(
                    (rs) => rs.where((r) => r.tipo == kTipoAves).toList(),
                  ),
              builder: (ctx, snapshot) {
                final rangos = snapshot.data ?? [];

                // Resolve initial rango object when stream first arrives
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
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
                    if (_clienteId == null) return 'Primero selecciona un cliente';
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
              if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
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
