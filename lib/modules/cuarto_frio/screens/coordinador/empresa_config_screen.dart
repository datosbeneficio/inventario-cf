import 'package:flutter/material.dart';
import '../../../../shared/models/empresa_config.dart';
import '../../../../shared/services/firestore_service.dart';

class EmpresaConfigScreen extends StatefulWidget {
  const EmpresaConfigScreen({super.key});

  @override
  State<EmpresaConfigScreen> createState() => _EmpresaConfigScreenState();
}

class _EmpresaConfigScreenState extends State<EmpresaConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _subtituloCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _loteEspCtrl = TextEditingController();
  final _diasVencEspCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  // Config tal como está en el servidor: se usa para preservar los campos
  // que esta pantalla no edita (codigoEliminacion, codigoEliminacionFecha)
  // al guardar, y así nunca sobreescribirlos con datos vacíos.
  EmpresaConfig? _actual;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Lee el documento directo del servidor en vez de depender del
  /// StreamProvider global, que en el momento de abrir esta pantalla puede
  /// aún no haber entregado su primer valor real (mostrando el formulario
  /// vacío pese a que sí hay datos guardados).
  Future<void> _cargar() async {
    final cfg = await FirestoreService.instance.getEmpresaConfigOnce();
    if (!mounted) return;
    _nombreCtrl.text = cfg.nombre;
    _subtituloCtrl.text = cfg.subtitulo;
    _direccionCtrl.text = cfg.direccion;
    _nitCtrl.text = cfg.nit;
    _contactoCtrl.text = cfg.contacto;
    _loteEspCtrl.text = cfg.loteEspecialConsecutivo.toString();
    _diasVencEspCtrl.text = cfg.diasVencimientoEspecial.toString();
    setState(() {
      _actual = cfg;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _subtituloCtrl.dispose();
    _direccionCtrl.dispose();
    _nitCtrl.dispose();
    _contactoCtrl.dispose();
    _loteEspCtrl.dispose();
    _diasVencEspCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final actual = _actual;
    if (actual == null) return;
    setState(() => _saving = true);
    await FirestoreService.instance.updateEmpresaConfig(
      EmpresaConfig(
        nombre: _nombreCtrl.text.trim(),
        subtitulo: _subtituloCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        nit: _nitCtrl.text.trim(),
        contacto: _contactoCtrl.text.trim(),
        // No editados en esta pantalla: se preservan tal cual estaban.
        codigoEliminacion: actual.codigoEliminacion,
        codigoEliminacionFecha: actual.codigoEliminacionFecha,
        loteEspecialConsecutivo:
            int.tryParse(_loteEspCtrl.text.trim()) ?? 1,
        diasVencimientoEspecial:
            int.tryParse(_diasVencEspCtrl.text.trim()) ?? 30,
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
          else if (!_loading)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar',
              onPressed: _guardar,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subtituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subtítulo (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.subtitles_outlined),
                        hintText:
                            'Ej: Planta de Beneficio de Aves Codigo Invima: 109AD',
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
                      'Lote especial',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Consecutivo base para el lote de rangos especiales. '
                      'Se asigna automáticamente al crear un despacho con producto especial '
                      'y se incrementa después de cada uso.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _loteEspCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Consecutivo actual *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.star_outline),
                              hintText: 'Ej: 1',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              if (int.tryParse(v.trim()) == null) {
                                return 'Número';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _diasVencEspCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Días de vencimiento *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.timer_outlined),
                              hintText: 'Ej: 30',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return 'Inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Seguridad de eliminación',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: Colors.black45),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El código que los supervisores necesitan para eliminar '
                              'registros ahora se genera solo, automáticamente, una vez '
                              'por día. Consúltalo con el ícono de llave en la barra '
                              'superior del inicio.',
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar cambios'),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Desarrollado por: Carlos Fernando Huérfano Gómez',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black26,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }
}
