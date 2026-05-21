import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/ciclo_config.dart';
import '../../../../shared/models/cliente.dart';
import '../../models/conductor.dart';
import '../../models/despacho.dart';
import '../../models/destino.dart';
import '../../../../shared/models/empresa_config.dart';
import '../../models/ingreso.dart';
import '../../models/rango.dart';
import '../../models/salida.dart';
import '../../models/vehiculo.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../../../shared/utils/constants.dart';
import '../../utils/despacho_pdf.dart';
import '../../../../shared/utils/formatters.dart';
import 'despacho_detalle_screen.dart';

class NuevoDespachoScreen extends StatefulWidget {
  const NuevoDespachoScreen({super.key});

  @override
  State<NuevoDespachoScreen> createState() => _NuevoDespachoScreenState();
}

class _NuevoDespachoScreenState extends State<NuevoDespachoScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Transporte ──────────────────────────────────────────────────────────
  Vehiculo? _vehiculo;
  Conductor? _conductor;
  final _capacidadCtrl = TextEditingController();
  TimeOfDay _horaSalida = TimeOfDay.now();

  // ── Destino y fechas ────────────────────────────────────────────────────
  Destino? _destino;
  DateTime _fechaDespacho = DateTime.now();
  DateTime _fechaBeneficio = DateTime.now();

  // ── Datos adicionales ───────────────────────────────────────────────────
  final _guiaCtrl = TextEditingController();
  final _precintoCtrl = TextEditingController();
  final _tempCanalCtrl = TextEditingController();
  final _tempMenudCtrl = TextEditingController();
  final _tempPreCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  // ── Lotes y vencimientos ─────────────────────────────────────────────────
  final _lotePolloCtrl = TextEditingController();
  final _loteMenudCtrl = TextEditingController();
  DateTime? _vencimientoPollo;
  DateTime? _vencimientoMenudencias;

  // ── Foto del precinto ────────────────────────────────────────────────────
  Uint8List? _fotoBytes;

  // ── Líneas de producto ───────────────────────────────────────────────────
  final List<DespachoLinea> _lineas = [];

  // ── Estado de envío ──────────────────────────────────────────────────────
  bool _submitting = false;
  bool _despachado = false;
  Despacho? _ultimoDespacho;
  /// Se activa al intentar confirmar sin fechas de vencimiento seleccionadas.
  bool _mostrarErrorVenc = false;

  // ── Helpers de peso ───────────────────────────────────────────────────────

  double get _pesoNeto =>
      _lineas.fold(0.0, (s, l) => s + l.peso);
  int get _totalCanastillas =>
      _lineas.fold(0, (s, l) => s + l.canastillas);
  double get _pesoBruto =>
      _pesoNeto + (_totalCanastillas * kPesoCanastillaKg);

  bool get _superaCapacidad =>
      _vehiculo != null && _lineas.isNotEmpty &&
      _pesoBruto > _vehiculo!.capacidadKg;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Compute next guía number after the first frame (providers ready)
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGuia());
  }

  @override
  void dispose() {
    _capacidadCtrl.dispose();
    _guiaCtrl.dispose();
    _precintoCtrl.dispose();
    _tempCanalCtrl.dispose();
    _tempMenudCtrl.dispose();
    _tempPreCtrl.dispose();
    _obsCtrl.dispose();
    _lotePolloCtrl.dispose();
    _loteMenudCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _horaSalidaStr {
    final h = _horaSalida.hourOfPeriod == 0 ? 12 : _horaSalida.hourOfPeriod;
    final m = _horaSalida.minute.toString().padLeft(2, '0');
    final p = _horaSalida.period == DayPeriod.am ? 'a.m.' : 'p.m.';
    return '$h:$m $p';
  }

  /// Calcula el siguiente número de guía a partir del historial.
  void _initGuia() {
    if (!mounted || _guiaCtrl.text.isNotEmpty) return;
    final despachos = context.read<List<Despacho>>();
    int maxNro = 0;
    for (final d in despachos) {
      final n = int.tryParse(d.guiaNro) ?? 0;
      if (n > maxNro) maxNro = n;
    }
    _guiaCtrl.text = (maxNro + 1).toString();
  }

  /// Limpia el formulario y prepara un nuevo despacho.
  void _resetForm() {
    setState(() {
      _vehiculo = null;
      _conductor = null;
      _destino = null;
      _fechaDespacho = DateTime.now();
      _fechaBeneficio = DateTime.now();
      _horaSalida = TimeOfDay.now();
      _capacidadCtrl.clear();
      _guiaCtrl.clear();
      _precintoCtrl.clear();
      _tempCanalCtrl.clear();
      _tempMenudCtrl.clear();
      _tempPreCtrl.clear();
      _obsCtrl.clear();
      _lotePolloCtrl.clear();
      _loteMenudCtrl.clear();
      _vencimientoPollo = null;
      _vencimientoMenudencias = null;
      _mostrarErrorVenc = false;
      _fotoBytes = null;
      _lineas.clear();
      _submitting = false;
      _despachado = false;
      _ultimoDespacho = null;
    });
    // Re-calcular guía después de limpiar
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initGuia());
  }

  // ── Foto del precinto ────────────────────────────────────────────────────

  Future<void> _pickFoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _fotoBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar la imagen: $e')),
        );
      }
    }
  }

  void _showFotoOptions() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Foto del precinto',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería / archivos'),
              onTap: () {
                Navigator.pop(context);
                _pickFoto(ImageSource.gallery);
              },
            ),
            if (_fotoBytes != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Quitar foto',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _fotoBytes = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Confirmar ─────────────────────────────────────────────────────────────

  Future<void> _confirmar() async {
    // Validar fechas de vencimiento (no participan en el Form)
    final faltanVenc =
        _vencimientoPollo == null || _vencimientoMenudencias == null;
    if (faltanVenc) {
      setState(() => _mostrarErrorVenc = true);
    }

    if (!_formKey.currentState!.validate() || faltanVenc) return;

    if (_vehiculo == null) {
      _showError('Selecciona un vehículo');
      return;
    }
    if (_conductor == null) {
      _showError('Selecciona un conductor');
      return;
    }
    if (_destino == null) {
      _showError('Selecciona un destino');
      return;
    }
    if (_lineas.isEmpty) {
      _showError('Agrega al menos una línea de producto');
      return;
    }

    if (_superaCapacidad) {
      _showError(
        'Peso bruto (${formatKg(_pesoBruto)}) supera la capacidad del '
        'vehículo (${formatKg(_vehiculo!.capacidadKg)}). '
        'Reduce el producto o cambia de vehículo.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final despachoId = FirestoreService.instance.newDespachoId();

      final despacho = Despacho(
        id: despachoId,
        guiaNro: _guiaCtrl.text.trim(),
        fechaDespacho: _fechaDespacho,
        fechaBeneficio: _fechaBeneficio,
        vehiculoId: _vehiculo!.id,
        placa: _vehiculo!.placa,
        plancha: _vehiculo!.plancha,
        conductorId: _conductor!.id,
        conductorNombre: _conductor!.nombre,
        conductorCedula: _conductor!.cedula,
        capacidadKg: double.parse(
            _capacidadCtrl.text.replaceAll(',', '.')),
        horaSalida: _horaSalidaStr,
        destinoId: _destino!.id,
        destinoNombre: _destino!.nombre,
        direccion: _destino!.direccion,
        municipio: _destino!.municipio,
        departamento: _destino!.departamento,
        precinto: _precintoCtrl.text.trim(),
        tempCanal: _tempCanalCtrl.text.trim(),
        tempMenudencias: _tempMenudCtrl.text.trim(),
        tempPreEnfriamiento: _tempPreCtrl.text.trim(),
        lotePollo: _lotePolloCtrl.text.trim(),
        vencimientoPollo: _vencimientoPollo,
        loteMenudencias: _loteMenudCtrl.text.trim(),
        vencimientoMenudencias: _vencimientoMenudencias,
        observaciones: _obsCtrl.text.trim(),
        lineas: _lineas,
        timestamp: DateTime.now(),
      );

      await FirestoreService.instance.addDespacho(
          despacho, predefinedId: despachoId);

      if (mounted) {
        setState(() {
          _submitting = false;
          _despachado = true;
          _ultimoDespacho = despacho;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showError('Error al guardar: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vehiculos = context.watch<List<Vehiculo>>();
    final conductores = context.watch<List<Conductor>>();
    final destinos = context.watch<List<Destino>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Banner de éxito (visible tras envío) ───────────────────────
          if (_despachado && _ultimoDespacho != null) ...[
            _SuccessBanner(
              guiaNro: _ultimoDespacho!.guiaNro,
              despacho: _ultimoDespacho!,
              fotoBytes: _fotoBytes,
              empresa: context.read<EmpresaConfig>(),
              onVerGuia: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DespachoDetalleScreen(despacho: _ultimoDespacho!),
                ),
              ),
              onNuevoDespacho: _resetForm,
            ),
            const SizedBox(height: 16),
          ],

          // ── Formulario (oculto detrás de AbsorbPointer tras envío) ─────
          AbsorbPointer(
            absorbing: _despachado,
            child: Opacity(
              opacity: _despachado ? 0.55 : 1.0,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Sección 1: Transporte ──────────────────────────
                    _SectionTitle(
                        icon: Icons.local_shipping, label: 'Transporte'),
                    const SizedBox(height: 12),

                    // ── Dropdown Vehículo ──────────────────────────────
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Vehículo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      initialValue: _vehiculo?.id,
                      items: vehiculos
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.placa),
                              ))
                          .toList(),
                      onChanged: (id) {
                        final sel =
                            vehiculos.firstWhere((v) => v.id == id);
                        setState(() {
                          _vehiculo = sel;
                          _capacidadCtrl.text =
                              formatNum(sel.capacidadKg);
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Selecciona un vehículo' : null,
                    ),

                    if (_vehiculo != null) ...[
                      const SizedBox(height: 8),
                      _InfoChip(children: [
                        _InfoRow(
                            icon: Icons.grid_view,
                            label: 'Plancha',
                            value: _vehiculo!.plancha),
                        _InfoRow(
                            icon: Icons.scale,
                            label: 'Capacidad',
                            value: '${formatNum(_vehiculo!.capacidadKg)} kg'),
                      ]),
                    ],
                    const SizedBox(height: 12),

                    // ── Dropdown Conductor ─────────────────────────────
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Conductor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      initialValue: _conductor?.id,
                      items: conductores
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nombre),
                              ))
                          .toList(),
                      onChanged: (id) => setState(() =>
                          _conductor =
                              conductores.firstWhere((c) => c.id == id)),
                      validator: (v) =>
                          v == null ? 'Selecciona un conductor' : null,
                    ),

                    if (_conductor != null) ...[
                      const SizedBox(height: 8),
                      _InfoChip(children: [
                        _InfoRow(
                            icon: Icons.badge,
                            label: 'CC',
                            value: _conductor!.cedula),
                      ]),
                    ],
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacidadCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Capacidad',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.scale),
                            suffixText: 'kg',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (double.tryParse(
                                    v.replaceAll(',', '.')) ==
                                null) {
                              return 'Inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _horaSalida,
                            );
                            if (t != null) {
                              setState(() => _horaSalida = t);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora de salida',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_horaSalidaStr),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Sección 2: Destino y fechas ────────────────────
                    _SectionTitle(
                        icon: Icons.location_on,
                        label: 'Destino y Fechas'),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Destino',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      initialValue: _destino?.id,
                      items: destinos
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.nombre),
                              ))
                          .toList(),
                      onChanged: (id) => setState(() =>
                          _destino =
                              destinos.firstWhere((d) => d.id == id)),
                      validator: (v) =>
                          v == null ? 'Selecciona un destino' : null,
                    ),

                    if (_destino != null) ...[
                      const SizedBox(height: 8),
                      _InfoChip(children: [
                        _InfoRow(
                            icon: Icons.location_on,
                            label: 'Dir.',
                            value: _destino!.direccion),
                        _InfoRow(
                            icon: Icons.location_city,
                            label: 'Ciudad',
                            value:
                                '${_destino!.municipio}, ${_destino!.departamento}'),
                      ]),
                    ],
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: _DateField(
                          label: 'Fecha de despacho',
                          date: _fechaDespacho,
                          onPicked: (d) =>
                              setState(() => _fechaDespacho = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Fecha de beneficio',
                          date: _fechaBeneficio,
                          onPicked: (d) =>
                              setState(() => _fechaBeneficio = d),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Sección 3: Datos adicionales ───────────────────
                    _SectionTitle(
                        icon: Icons.info_outline,
                        label: 'Datos adicionales'),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _guiaCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Guía N°',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Campo requerido'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _precintoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'N° Precinto',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tempCanalCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Temp. Canal (°C)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.thermostat),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _tempMenudCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Temp. Menud. (°C)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.thermostat),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _tempPreCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Temp. Pre-enf. (°C)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.thermostat),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    const SizedBox(height: 20),

                    // ── Sección 3b: Lotes y vencimientos ──────────────
                    _SectionTitle(
                        icon: Icons.qr_code_scanner,
                        label: 'Lotes y Vencimientos'),
                    const SizedBox(height: 12),

                    // Pollo en Canal
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lotePolloCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Lote Pollo en Canal *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obligatorio (INVIMA)'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Vencimiento Pollo *',
                          date: _vencimientoPollo,
                          onPicked: (d) =>
                              setState(() => _vencimientoPollo = d),
                          hasError: _mostrarErrorVenc &&
                              _vencimientoPollo == null,
                        ),
                      ),
                    ]),
                    if (_mostrarErrorVenc && _vencimientoPollo == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Selecciona la fecha de vencimiento del Pollo',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Menudencias
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loteMenudCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Lote Menudencias *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obligatorio (INVIMA)'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Vencimiento Menudencias *',
                          date: _vencimientoMenudencias,
                          onPicked: (d) =>
                              setState(() => _vencimientoMenudencias = d),
                          hasError: _mostrarErrorVenc &&
                              _vencimientoMenudencias == null,
                        ),
                      ),
                    ]),
                    if (_mostrarErrorVenc && _vencimientoMenudencias == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Selecciona la fecha de vencimiento de Menudencias',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // ── Observaciones ─────────────────────────────────
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.notes_outlined),
                        ),
                        alignLabelWithHint: true,
                        hintText:
                            'Condiciones del producto, novedades del viaje…',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Foto del precinto ──────────────────────────────
                    _PrecintoFotoWidget(
                      fotoBytes: _fotoBytes,
                      onTap: _showFotoOptions,
                    ),
                    const SizedBox(height: 20),

                    // ── Sección 4: Líneas de producto ──────────────────
                    _SectionTitle(
                        icon: Icons.list_alt, label: 'Líneas de producto'),
                    const SizedBox(height: 8),

                    if (_lineas.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Sin líneas agregadas. Usa el botón para añadir productos.',
                          style:
                              TextStyle(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._lineas.asMap().entries.map((e) {
                        final idx = e.key;
                        final l = e.value;
                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  l.rangoTipo == kTipoAves
                                      ? cs.primaryContainer
                                      : cs.tertiaryContainer,
                              child: Icon(
                                l.rangoTipo == kTipoAves
                                    ? Icons.set_meal
                                    : Icons.restaurant,
                                size: 14,
                                color: l.rangoTipo == kTipoAves
                                    ? cs.onPrimaryContainer
                                    : cs.onTertiaryContainer,
                              ),
                            ),
                            title: Text(
                                '${l.clienteNombre} · ${l.rangoNombre}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              '${formatNum(l.canastillas)} canast. · '
                              '${formatNum(l.unidades)} unid. · '
                              '${formatKg(l.peso)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                  size: 20),
                              onPressed: () => setState(
                                  () => _lineas.removeAt(idx)),
                            ),
                          ),
                        );
                      }),

                    if (_lineas.isNotEmpty) ...[
                      const Divider(),
                      // ── Totales ──────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${formatNum(_totalCanastillas)} canast. · '
                                  '${formatNum(_lineas.fold(0, (s, l) => s + l.unidades))} unid.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                Text(
                                  'Neto: ${formatKg(_pesoNeto)}   '
                                  'Bruto: ${formatKg(_pesoBruto)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _superaCapacidad
                                        ? Colors.red
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: _superaCapacidad
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_vehiculo != null)
                            _CapacidadChip(
                              pesoBruto: _pesoBruto,
                              capacidadKg: _vehiculo!.capacidadKg,
                            ),
                        ],
                      ),
                      // ── Alerta de sobrecarga ──────────────────────────
                      if (_superaCapacidad)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Peso bruto supera la capacidad del vehículo '
                                  '(${formatKg(_vehiculo!.capacidadKg)}). '
                                  'Reduce el producto o cambia de vehículo.',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed: () =>
                          _showAgregarLineaDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar línea de producto'),
                    ),
                    const SizedBox(height: 24),

                    // ── Botón confirmar ────────────────────────────────
                    FilledButton.icon(
                      onPressed:
                          (_submitting || _despachado) ? null : _confirmar,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Confirmar Despacho'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialog para agregar una línea ─────────────────────────────────────────

  void _showAgregarLineaDialog(BuildContext context) {
    final clientes = context.read<List<Cliente>>();
    final ciclo = context.read<CicloConfig>();
    // Solo movimientos del ciclo activo
    final ingresos = context
        .read<List<Ingreso>>()
        .where((i) => !i.timestamp.isBefore(ciclo.inicio))
        .toList();
    final salidas = context
        .read<List<Salida>>()
        .where((s) => !s.timestamp.isBefore(ciclo.inicio))
        .toList();

    // Compute saldo map
    final saldoMap = <String, ({int canastillas, int unidades, double peso})>{};
    for (final i in ingresos) {
      final k = '${i.clienteId}|${i.rangoId}';
      final p = saldoMap[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      saldoMap[k] = (
        canastillas: p.canastillas + i.canastillas,
        unidades: p.unidades + i.unidades,
        peso: p.peso + i.peso,
      );
    }
    for (final s in salidas) {
      final k = '${s.clienteId}|${s.rangoId}';
      final p = saldoMap[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      saldoMap[k] = (
        canastillas: p.canastillas - s.canastillas,
        unidades: p.unidades - s.unidades,
        peso: p.peso - s.peso,
      );
    }

    // Restar líneas ya comprometidas en este despacho (aún no guardadas en Firestore)
    for (final l in _lineas) {
      final k = '${l.clienteId}|${l.rangoId}';
      final p = saldoMap[k] ?? (canastillas: 0, unidades: 0, peso: 0.0);
      saldoMap[k] = (
        canastillas: p.canastillas - l.canastillas,
        unidades:    p.unidades    - l.unidades,
        peso:        p.peso        - l.peso,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => _AgregarLineaDialog(
        clientes: clientes,
        saldoMap: saldoMap,
        onAgregar: (linea) => setState(() => _lineas.add(linea)),
      ),
    );
  }
}

// ── Banner de éxito ──────────────────────────────────────────────────────────

class _SuccessBanner extends StatelessWidget {
  final String guiaNro;
  final Despacho despacho;
  final Uint8List? fotoBytes;
  final EmpresaConfig empresa;
  final VoidCallback onVerGuia;
  final VoidCallback onNuevoDespacho;

  const _SuccessBanner({
    required this.guiaNro,
    required this.despacho,
    required this.fotoBytes,
    required this.empresa,
    required this.onVerGuia,
    required this.onNuevoDespacho,
  });

  Future<void> _imprimirPdf(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (fmt) async =>
          (await buildDespachoPdf(despacho, empresa,
                  fotoBytes: fotoBytes))
              .save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Despacho confirmado',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green),
                      ),
                      Text(
                        'Guía N° $guiaNro guardada correctamente.',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (fotoBytes != null)
                        const Text(
                          'Imprime el PDF ahora para incluir la foto del precinto.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fila superior: imprimir PDF (destacado)
            FilledButton.icon(
              onPressed: () => _imprimirPdf(context),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Imprimir / Guardar PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            // Fila inferior: ver guía en pantalla | nuevo despacho
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onVerGuia,
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Ver guía'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNuevoDespacho,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo despacho'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget de foto del precinto ───────────────────────────────────────────────

class _PrecintoFotoWidget extends StatelessWidget {
  final Uint8List? fotoBytes;
  final VoidCallback onTap;

  const _PrecintoFotoWidget({
    required this.fotoBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (fotoBytes == null) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Adjuntar foto del precinto'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            fotoBytes!,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.lock, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Foto del precinto adjunta',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Cambiar'),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Dialog para seleccionar cliente, rango y cantidades ──────────────────────

class _AgregarLineaDialog extends StatefulWidget {
  final List<Cliente> clientes;
  final Map<String, ({int canastillas, int unidades, double peso})> saldoMap;
  final void Function(DespachoLinea) onAgregar;

  const _AgregarLineaDialog({
    required this.clientes,
    required this.saldoMap,
    required this.onAgregar,
  });

  @override
  State<_AgregarLineaDialog> createState() => _AgregarLineaDialogState();
}

class _AgregarLineaDialogState extends State<_AgregarLineaDialog> {
  String? _clienteId;
  Rango? _rango;
  final _canCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  bool _esCola = false;
  final _formKey = GlobalKey<FormState>();

  ({int canastillas, int unidades, double peso})? get _saldo {
    if (_clienteId == null || _rango == null) return null;
    return widget.saldoMap['$_clienteId|${_rango!.id}'];
  }

  int get _canastillas => int.tryParse(_canCtrl.text) ?? 0;
  int get _unidades {
    if (_rango == null) return 0;
    return FirestoreService.calcularUnidades(
        _esCola, _canastillas, _rango!.multiplicador);
  }

  @override
  void dispose() {
    _canCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saldo = _saldo;
    final esAves = _rango?.tipo == kTipoAves;

    return AlertDialog(
      title: const Text('Agregar línea'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cliente
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  initialValue: _clienteId,
                  items: widget.clientes
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _clienteId = v;
                    _rango = null;
                  }),
                  validator: (v) =>
                      v == null ? 'Selecciona un cliente' : null,
                ),
                const SizedBox(height: 12),

                // Rango (stream filtrado por stock)
                if (_clienteId != null)
                  StreamBuilder<List<Rango>>(
                    stream: FirestoreService.instance
                        .rangosStream(_clienteId!)
                        .map((rs) => rs.where((r) {
                              final s = widget.saldoMap[
                                  '$_clienteId|${r.id}'];
                              return s != null &&
                                  (s.canastillas > 0 || s.unidades > 0);
                            }).toList()),
                    builder: (_, snap) {
                      final rangos = snap.data ?? [];
                      final val =
                          rangos.any((r) => r.id == _rango?.id)
                              ? _rango?.id
                              : null;
                      if (rangos.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8),
                          child: Text(
                            'Sin rangos con inventario disponible.',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Rango',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        initialValue: val,
                        items: rangos
                            .map((r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.nombre),
                                ))
                            .toList(),
                        onChanged: (id) => setState(() {
                          _rango =
                              rangos.firstWhere((r) => r.id == id);
                          _esCola = false;
                          _canCtrl.clear();
                          _pesoCtrl.clear();
                        }),
                        validator: (v) =>
                            v == null ? 'Selecciona un rango' : null,
                      );
                    },
                  ),

                // Info stock disponible
                if (saldo != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2,
                            size: 14,
                            color: cs.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Disponible: ${formatNum(saldo.canastillas)} canast. · '
                            '${formatNum(saldo.unidades)} unid. · '
                            '${formatKg(saldo.peso)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Toggle Cola (solo aves)
                if (_rango != null && esAves) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Es Cola',
                        style: TextStyle(fontSize: 13)),
                    value: _esCola,
                    onChanged: (v) => setState(() {
                      _esCola = v;
                      _canCtrl.clear();
                    }),
                  ),
                ],

                if (_rango != null) ...[
                  const SizedBox(height: 8),
                  // Canastillas / Unidades
                  TextFormField(
                    controller: _canCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: InputDecoration(
                      labelText: _esCola
                          ? 'Unidades de cola'
                          : 'Canastillas',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.grid_on),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return 'Valor inválido';
                      if (saldo != null) {
                        if (_esCola && n > saldo.unidades) {
                          return 'Máx. ${saldo.unidades} unid.';
                        }
                        if (!_esCola && n > saldo.canastillas) {
                          return 'Máx. ${saldo.canastillas} canast.';
                        }
                      }
                      return null;
                    },
                  ),

                  // Preview unidades (solo aves no-cola)
                  if (esAves && !_esCola && _canastillas > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '→ ${formatNum(_unidades)} unidades a despachar',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),

                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      final n =
                          double.tryParse(v.replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Valor inválido';
                      if (saldo != null && n > saldo.peso + 0.001) {
                        return 'Máx. ${formatKg(saldo.peso)}';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _rango == null
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) return;
                  final peso = double.parse(
                      _pesoCtrl.text.replaceAll(',', '.'));
                  widget.onAgregar(
                    DespachoLinea(
                      clienteId: _clienteId!,
                      clienteNombre: widget.clientes
                          .firstWhere((c) => c.id == _clienteId)
                          .nombre,
                      rangoId: _rango!.id,
                      rangoNombre: _rango!.nombre,
                      rangoTipo: _rango!.tipo,
                      canastillas: _esCola ? 1 : _canastillas,
                      unidades: _unidades,
                      peso: peso,
                      esCola: _esCola,
                    ),
                  );
                  Navigator.pop(context);
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final List<Widget> children;
  const _InfoChip({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSecondaryContainer),
        const SizedBox(width: 4),
        Text('$label  ',
            style: TextStyle(
                fontSize: 12, color: cs.onSecondaryContainer)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer)),
        ),
      ],
    );
  }
}

// ── Chip de capacidad del vehículo ────────────────────────────────────────────

class _CapacidadChip extends StatelessWidget {
  final double pesoBruto;
  final double capacidadKg;
  const _CapacidadChip(
      {required this.pesoBruto, required this.capacidadKg});

  @override
  Widget build(BuildContext context) {
    final pct = capacidadKg > 0 ? (pesoBruto / capacidadKg) : 0.0;
    final supera = pct > 1.0;
    final color = supera
        ? Colors.red
        : pct > 0.9
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            supera ? '⚠ SOBRECARGA' : '${(pct * 100).toStringAsFixed(0)}% cargado',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text(
            '${formatKg(pesoBruto)} / ${formatKg(capacidadKg)}',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final void Function(DateTime) onPicked;
  /// Cuando true muestra borde y texto en rojo (validación fallida).
  final bool hasError;
  const _DateField({
    required this.label,
    required this.date,
    required this.onPicked,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderSide: BorderSide(color: errorColor, width: 2))
              : const OutlineInputBorder(),
          labelStyle: hasError ? TextStyle(color: errorColor) : null,
          prefixIcon: Icon(Icons.calendar_today,
              color: hasError ? errorColor : null),
        ),
        child: Text(
          date != null ? formatDate(date!) : '—',
          style: hasError && date == null
              ? TextStyle(color: errorColor)
              : null,
        ),
      ),
    );
  }
}
