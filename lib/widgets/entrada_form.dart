import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rango.dart';
import '../providers/ingresos_provider.dart';
import '../utils/formatters.dart';

class EntradaForm extends StatefulWidget {
  final List<Rango> rangos;
  final Future<void> Function({
    required String rangoId,
    required int inputValue,
    required double peso,
    required bool esCola,
    required double multiplicador,
  }) onSubmit;

  final String submitLabel;

  final String? initialRangoId;
  final int? initialInputValue;
  final double? initialPeso;
  final bool? initialEsCola;

  const EntradaForm({
    super.key,
    required this.rangos,
    required this.onSubmit,
    required this.submitLabel,
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
  String? _rangoId;
  final _inputController = TextEditingController();
  final _pesoController = TextEditingController();
  bool _esCola = false;
  bool _submitting = false;

  Rango? get _rangoSeleccionado {
    if (_rangoId == null) return null;
    try {
      return widget.rangos.firstWhere((r) => r.id == _rangoId);
    } catch (_) {
      return null;
    }
  }

  int get _inputValue => int.tryParse(_inputController.text) ?? 0;

  int get _preview {
    final rango = _rangoSeleccionado;
    if (rango == null) return 0;
    return IngresosProvider.calcularUnidades(_esCola, _inputValue, rango.multiplicador);
  }

  @override
  void initState() {
    super.initState();
    _rangoId = widget.initialRangoId;
    _esCola = widget.initialEsCola ?? false;
    if (widget.initialInputValue != null) {
      _inputController.text = widget.initialInputValue.toString();
    }
    if (widget.initialPeso != null) {
      _pesoController.text = widget.initialPeso.toString();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final rango = _rangoSeleccionado;
    if (rango == null) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      rangoId: rango.id,
      inputValue: _inputValue,
      peso: double.parse(_pesoController.text.replaceAll(',', '.')),
      esCola: _esCola,
      multiplicador: rango.multiplicador,
    );
    if (mounted) {
      setState(() {
        _submitting = false;
        if (widget.initialRangoId == null) {
          _inputController.clear();
          _pesoController.clear();
          _esCola = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Rango',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            initialValue: _rangoId,
            items: widget.rangos
                .map((r) => DropdownMenuItem(
                      value: r.id,
                      child: Text('${r.nombre} (×${formatNum(r.multiplicador)})'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _rangoId = v),
            validator: (v) => v == null ? 'Selecciona un rango' : null,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Tipo Cola'),
            subtitle: Text(_esCola
                ? 'Ingresa las unidades (canastillas = 1)'
                : 'Ingresa las canastillas'),
            value: _esCola,
            onChanged: (v) => setState(() {
              _esCola = v;
              _inputController.clear();
            }),
            tileColor: _esCola ? cs.tertiaryContainer.withValues(alpha: 0.3) : null,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: cs.outlineVariant)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inputController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _esCola ? 'Unidades' : 'Canastillas',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(_esCola ? Icons.numbers : Icons.shopping_basket),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pesoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          if (_rangoSeleccionado != null && _inputValue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unidades a registrar: ${formatNum(_preview)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
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
