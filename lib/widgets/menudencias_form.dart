import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rango.dart';
import '../models/cliente.dart';
import '../utils/formatters.dart';

class MenudenciasForm extends StatefulWidget {
  final List<Rango> rangos;
  final List<Cliente> clientes;
  final Future<void> Function({
    required String rangoId,
    required int canastillas,
    required double peso,
    String? clienteId,
  }) onSubmit;
  final String submitLabel;

  final String? initialRangoId;
  final int? initialCanastillas;
  final double? initialPeso;
  final String? initialClienteId;

  const MenudenciasForm({
    super.key,
    required this.rangos,
    required this.clientes,
    required this.onSubmit,
    required this.submitLabel,
    this.initialRangoId,
    this.initialCanastillas,
    this.initialPeso,
    this.initialClienteId,
  });

  @override
  State<MenudenciasForm> createState() => _MenudenciasFormState();
}

class _MenudenciasFormState extends State<MenudenciasForm> {
  final _formKey = GlobalKey<FormState>();
  String? _rangoId;
  String? _clienteId;
  final _canastillasCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rangoId = widget.initialRangoId;
    _clienteId = widget.initialClienteId;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      rangoId: _rangoId!,
      canastillas: int.parse(_canastillasCtrl.text),
      peso: double.parse(_pesoCtrl.text.replaceAll(',', '.')),
      clienteId: _clienteId,
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.clientes.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Cliente',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              initialValue: _clienteId,
              items: widget.clientes
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                  .toList(),
              onChanged: (v) => setState(() => _clienteId = v),
              validator: (v) => v == null ? 'Selecciona un cliente' : null,
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Tipo de menudencia',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.restaurant),
            ),
            initialValue: _rangoId,
            items: widget.rangos
                .map((r) =>
                    DropdownMenuItem(value: r.id, child: Text(r.nombre)))
                .toList(),
            onChanged: (v) => setState(() => _rangoId = v),
            validator: (v) => v == null ? 'Selecciona un tipo' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _canastillasCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Canastillas',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shopping_basket),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
              return null;
            },
          ),
          const SizedBox(height: 12),
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
          if (_rangoId != null &&
              (int.tryParse(_canastillasCtrl.text) ?? 0) > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Canastillas a registrar: ${formatNum(int.tryParse(_canastillasCtrl.text) ?? 0)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onTertiaryContainer),
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
