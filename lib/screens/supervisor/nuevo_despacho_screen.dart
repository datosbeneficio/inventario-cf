import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import '../../models/despacho.dart';
import '../../models/destino.dart';
import '../../models/ingreso.dart';
import '../../models/rango.dart';
import '../../models/salida.dart';
import '../../models/vehiculo.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'despacho_detalle_screen.dart';

class NuevoDespachoScreen extends StatefulWidget {
  const NuevoDespachoScreen({super.key});

  @override
  State<NuevoDespachoScreen> createState() => _NuevoDespachoScreenState();
}

class _NuevoDespachoScreenState extends State<NuevoDespachoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Transporte
  Vehiculo? _vehiculo;
  final _capacidadCtrl = TextEditingController();
  TimeOfDay _horaSalida = TimeOfDay.now();

  // Destino y fechas
  Destino? _destino;
  DateTime _fechaDespacho = DateTime.now();
  DateTime _fechaBeneficio = DateTime.now();

  // Datos adicionales
  final _guiaCtrl = TextEditingController();
  final _precintoCtrl = TextEditingController();
  final _tempCanalCtrl = TextEditingController();
  final _tempMenudCtrl = TextEditingController();
  final _tempPreCtrl = TextEditingController();

  // LÃ­neas de producto
  final List<DespachoLinea> _lineas = [];

  bool _submitting = false;

  @override
  void dispose() {
    _capacidadCtrl.dispose();
    _guiaCtrl.dispose();
    _precintoCtrl.dispose();
    _tempCanalCtrl.dispose();
    _tempMenudCtrl.dispose();
    _tempPreCtrl.dispose();
    super.dispose();
  }

  String get _horaSalidaStr {
    final h = _horaSalida.hourOfPeriod == 0 ? 12 : _horaSalida.hourOfPeriod;
    final m = _horaSalida.minute.toString().padLeft(2, '0');
    final p = _horaSalida.period == DayPeriod.am ? 'a.m.' : 'p.m.';
    return '$h:$m $p';
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehiculo == null) {
      _showError('Selecciona un vehÃ­culo');
      return;
    }
    if (_destino == null) {
      _showError('Selecciona un destino');
      return;
    }
    if (_lineas.isEmpty) {
      _showError('Agrega al menos una lÃ­nea de producto');
      return;
    }

    setState(() => _submitting = true);
    try {
      final despacho = Despacho(
        id: '',
        guiaNro: _guiaCtrl.text.trim(),
        fechaDespacho: _fechaDespacho,
        fechaBeneficio: _fechaBeneficio,
        vehiculoId: _vehiculo!.id,
        placa: _vehiculo!.placa,
        conductorNombre: _vehiculo!.conductorNombre,
        conductorCedula: _vehiculo!.conductorCedula,
        conductorCelular: _vehiculo!.conductorCelular,
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
        lineas: _lineas,
        timestamp: DateTime.now(),
      );
      await FirestoreService.instance.addDespacho(despacho);

      if (mounted) {
        // Recuperar el despacho reciÃ©n creado (el de mayor timestamp)
        final despachos = context.read<List<Despacho>>();
        // Navegar a detalle â€” buscamos en el stream; si aÃºn no llegÃ³, usamos la data local
        final reciente = despachos.isNotEmpty ? despachos.first : null;
        if (reciente != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DespachoDetalleScreen(despacho: reciente),
            ),
          );
        }
        // Limpiar el formulario
        setState(() {
          _vehiculo = null;
          _destino = null;
          _lineas.clear();
          _guiaCtrl.clear();
          _precintoCtrl.clear();
          _capacidadCtrl.clear();
          _tempCanalCtrl.clear();
          _tempMenudCtrl.clear();
          _tempPreCtrl.clear();
          _horaSalida = TimeOfDay.now();
          _fechaDespacho = DateTime.now();
          _fechaBeneficio = DateTime.now();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vehiculos = context.watch<List<Vehiculo>>();
    final destinos = context.watch<List<Destino>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ SecciÃ³n 1: Transporte â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionTitle(
                icon: Icons.local_shipping, label: 'Transporte'),
            const SizedBox(height: 12),

            // VehÃ­culo
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'VehÃ­culo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              initialValue: _vehiculo?.id,
              items: vehiculos
                  .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.placa} â€” ${v.conductorNombre}'),
                      ))
                  .toList(),
              onChanged: (id) {
                final sel = vehiculos.firstWhere((v) => v.id == id);
                setState(() {
                  _vehiculo = sel;
                  _capacidadCtrl.text =
                      formatNum(sel.capacidadKg);
                });
              },
              validator: (v) =>
                  v == null ? 'Selecciona un vehÃ­culo' : null,
            ),

            // Info del conductor (solo lectura, aparece al seleccionar)
            if (_vehiculo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                        icon: Icons.badge,
                        label: 'CC',
                        value: _vehiculo!.conductorCedula),
                    _InfoRow(
                        icon: Icons.phone,
                        label: 'Cel.',
                        value: _vehiculo!.conductorCelular),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            Row(children: [
              // Capacidad
              Expanded(
                child: TextFormField(
                  controller: _capacidadCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Capacidad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'InvÃ¡lido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Hora salida
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _horaSalida,
                    );
                    if (t != null) setState(() => _horaSalida = t);
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

            // â”€â”€ SecciÃ³n 2: Destino y fechas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionTitle(
                icon: Icons.location_on, label: 'Destino y Fechas'),
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
              onChanged: (id) => setState(
                  () => _destino = destinos.firstWhere((d) => d.id == id)),
              validator: (v) =>
                  v == null ? 'Selecciona un destino' : null,
            ),

            if (_destino != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                        icon: Icons.location_on,
                        label: 'Dir.',
                        value: _destino!.direccion),
                    _InfoRow(
                        icon: Icons.location_city,
                        label: 'Ciudad',
                        value:
                            '${_destino!.municipio}, ${_destino!.departamento}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _DateField(
                  label: 'Fecha de despacho',
                  date: _fechaDespacho,
                  onPicked: (d) => setState(() => _fechaDespacho = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Fecha de beneficio',
                  date: _fechaBeneficio,
                  onPicked: (d) => setState(() => _fechaBeneficio = d),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // â”€â”€ SecciÃ³n 3: Datos adicionales â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionTitle(
                icon: Icons.info_outline, label: 'Datos adicionales'),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _guiaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GuÃ­a NÂ°',
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
                    labelText: 'NÂ° Precinto',
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
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temp. Canal (Â°C)',
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
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temp. Menud. (Â°C)',
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
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temp. Pre-enf. (Â°C)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.thermostat),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // â”€â”€ SecciÃ³n 4: LÃ­neas de producto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionTitle(
                icon: Icons.list_alt, label: 'LÃ­neas de producto'),
            const SizedBox(height: 8),

            if (_lineas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sin lÃ­neas agregadas. Usa el botÃ³n para aÃ±adir productos.',
                  style: TextStyle(color: cs.onSurfaceVariant),
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
                      backgroundColor: l.rangoTipo == kTipoAves
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
                        '${l.clienteNombre} Â· ${l.rangoNombre}',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${formatNum(l.canastillas)} canast. Â· '
                      '${formatNum(l.unidades)} unid. Â· '
                      '${formatKg(l.peso)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () =>
                          setState(() => _lineas.removeAt(idx)),
                    ),
                  ),
                );
              }),

            // Total acumulado
            if (_lineas.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: '
                    '${formatNum(_lineas.fold(0, (s, l) => s + l.canastillas))} canast. Â· '
                    '${formatNum(_lineas.fold(0, (s, l) => s + l.unidades))} unid. Â· '
                    '${formatKg(_lineas.fold(0.0, (s, l) => s + l.peso))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () => _showAgregarLineaDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Agregar lÃ­nea de producto'),
            ),
            const SizedBox(height: 24),

            // â”€â”€ BotÃ³n confirmar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            FilledButton.icon(
              onPressed: _submitting ? null : _confirmar,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar Despacho'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Dialog para agregar una lÃ­nea â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showAgregarLineaDialog(BuildContext context) {
    final clientes = context.read<List<Cliente>>();
    final ingresos = context.read<List<Ingreso>>();
    final salidas = context.read<List<Salida>>();

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

// â”€â”€ Dialog para seleccionar cliente, rango y cantidades â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

    return AlertDialog(
      title: const Text('Agregar lÃ­nea'),
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

                // Rango (stream)
                if (_clienteId != null)
                  StreamBuilder<List<Rango>>(
                    stream: FirestoreService.instance
                        .rangosStream(_clienteId!)
                        .map((rs) => rs
                            .where((r) {
                              final s = widget.saldoMap[
                                  '$_clienteId|${r.id}'];
                              return s != null &&
                                  (s.canastillas > 0 ||
                                      s.unidades > 0);
                            })
                            .toList()),
                    builder: (_, snap) {
                      final rangos = snap.data ?? [];
                      final val = rangos.any((r) => r.id == _rango?.id)
                          ? _rango?.id
                          : null;
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
                          _rango = rangos.firstWhere((r) => r.id == id);
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
                            'Disponible: ${formatNum(saldo.canastillas)} canast. Â· '
                            '${formatNum(saldo.unidades)} unid. Â· '
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
                const SizedBox(height: 12),

                // Toggle cola (solo aves)
                if (_rango?.esAves == true)
                  SwitchListTile(
                    title: const Text('Tipo Cola'),
                    value: _esCola,
                    onChanged: (v) => setState(() {
                      _esCola = v;
                      _canCtrl.clear();
                    }),
                    dense: true,
                  ),

                // Canastillas / unidades
                TextFormField(
                  controller: _canCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: InputDecoration(
                    labelText:
                        _esCola ? 'Unidades (cola)' : 'Canastillas',
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        Icon(_esCola ? Icons.numbers : Icons.shopping_basket),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final n = int.tryParse(v) ?? 0;
                    if (n <= 0) return 'Debe ser > 0';
                    if (saldo != null) {
                      final max =
                          _esCola ? saldo.unidades : saldo.canastillas;
                      if (n > max) {
                        return 'MÃ¡x: ${formatNum(max)}';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Peso
                TextFormField(
                  controller: _pesoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'InvÃ¡lido';
                    if (saldo != null && n > saldo.peso) {
                      return 'MÃ¡x: ${formatKg(saldo.peso)}';
                    }
                    return null;
                  },
                ),

                // Preview unidades
                if (_rango != null && _canastillas > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _esCola
                          ? '${formatNum(_canastillas)} unidades de cola'
                          : '${formatNum(_canastillas)} canast. â†’ '
                              '${formatNum(_unidades)} unid.',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: cs.onPrimaryContainer),
                    ),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_rango == null) return;
            final cliente = widget.clientes
                .firstWhere((c) => c.id == _clienteId);
            final canastillas = _esCola ? 1 : _canastillas;
            widget.onAgregar(DespachoLinea(
              clienteId: cliente.id,
              clienteNombre: cliente.nombre,
              rangoId: _rango!.id,
              rangoNombre: _rango!.nombre,
              rangoTipo: _rango!.tipo,
              canastillas: canastillas,
              unidades: _unidades,
              peso: double.parse(
                  _pesoCtrl.text.replaceAll(',', '.')),
              esCola: _esCola,
            ));
            Navigator.pop(context);
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// â”€â”€ Widgets auxiliares â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                fontSize: 14,
                color: cs.primary)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.primary.withValues(alpha: 0.3))),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text('$label ', style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onPicked;
  const _DateField(
      {required this.label, required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(formatDate(date)),
      ),
    );
  }
}
