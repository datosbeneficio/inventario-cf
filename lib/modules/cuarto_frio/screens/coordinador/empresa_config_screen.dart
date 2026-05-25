import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/empresa_config.dart';
import '../../../../shared/services/firestore_service.dart';

class EmpresaConfigScreen extends StatefulWidget {
  const EmpresaConfigScreen({super.key});

  @override
  State<EmpresaConfigScreen> createState() => _EmpresaConfigScreenState();
}

class _EmpresaConfigScreenState extends State<EmpresaConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _subtituloCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _contactoCtrl;
  late final TextEditingController _codigoCtrl;
  bool _saving = false;
  bool _obscureCodigo = true;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<EmpresaConfig>();
    _nombreCtrl = TextEditingController(text: cfg.nombre);
    _subtituloCtrl = TextEditingController(text: cfg.subtitulo);
    _direccionCtrl = TextEditingController(text: cfg.direccion);
    _nitCtrl = TextEditingController(text: cfg.nit);
    _contactoCtrl = TextEditingController(text: cfg.contacto);
    _codigoCtrl = TextEditingController(text: cfg.codigoEliminacion);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _subtituloCtrl.dispose();
    _direccionCtrl.dispose();
    _nitCtrl.dispose();
    _contactoCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await FirestoreService.instance.updateEmpresaConfig(
      EmpresaConfig(
        nombre: _nombreCtrl.text.trim(),
        subtitulo: _subtituloCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        nit: _nitCtrl.text.trim(),
        contacto: _contactoCtrl.text.trim(),
        codigoEliminacion: _codigoCtrl.text.trim(),
      ),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Información de empresa actualizada'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos de empresa'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar',
              onPressed: _guardar,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Esta información aparece en el encabezado de la guía de despacho (PDF).',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la empresa *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                  hintText: 'Ej: PLANTA DE BENEFICIO LAS MERCEDES',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subtituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subtítulo (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subtitles_outlined),
                  hintText: 'Ej: Planta de Beneficio de Aves Codigo Invima: 109AD',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'Ej: KM 4 VÍA PALMIRA',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NIT (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  hintText: 'Ej: 900.123.456-7',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono / Contacto (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: 'Ej: 314 456 7890',
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Seguridad de eliminación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Código que los supervisores deben ingresar para poder eliminar registros. '
                'Déjalo vacío para desactivar el bloqueo.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (_, setLocal) => TextFormField(
                  controller: _codigoCtrl,
                  obscureText: _obscureCodigo,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Código de eliminación (opcional)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Ej: 1234',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCodigo
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setLocal(() => _obscureCodigo = !_obscureCodigo),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
