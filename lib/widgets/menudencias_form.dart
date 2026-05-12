import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cliente.dart';
import '../models/rango.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

typedef OnSubmitMenudencias = Future<void> Function({
  required String clienteId,
  required String clienteNombre,
  required String rangoId,
  required String rangoNombre,
  required int canastillas,
  required double peso,
});

class MenudenciasForm extends StatefulWidget {
  final OnSubmitMenudencias onSubmit;
  final String submitLabel;
  final String? initialClienteId;
  final String? initialRangoId;
  final int? initialCanastillas;
  final double? initialPeso;

  const MenudenciasForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initialClienteId,
    this.initialRangoId,
    this.initialCanastillas,
    this.initialPeso,
  });

  @override
  State<MenudenciasForm> createState() => _MenudenciasFormState();
}

class _MenudenciasFormState extends State<MenudenciasForm> {
  final _formKey = GlobalKey<FormState>();
  String? _clienteId;
  String? _rangoId;
  Rango? _rangoObj;
  final _canastillasCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _submitting = false;

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
      canastillas: int.parse(_canastillasCtrl.text),
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

          // ── Tipo de menudencia (dinámico por cliente) ─────────────────────
          if (_clienteId != null)
            StreamBuilder<List<Rango>>(
              stream: FirestoreService.instance.rangosStream(_clienteId!).map(
                    (rs) => rs.where((r) => r.tipo == kTipoMenudencias).toList(),
                  ),
              builder: (ctx, snapshot) {
                final rangos = snapshot.data ?? [];

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
                    labelText: 'Tipo de menudencia',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.restaurant),
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
                            child: Text(r.nombre),
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
                    if (v == null) return 'Selecciona un tipo';
                    return null;
                  },
                );
              },
            )
          else
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Tipo de menudencia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
                hintText: 'Primero selecciona un cliente',
              ),
              items: const [],
              onChanged: null,
              validator: (_) =>
                  _clienteId == null ? 'Primero selecciona un cliente' : null,
            ),
          const SizedBox(height: 12),

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

          if (_rangoObj != null &&
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
