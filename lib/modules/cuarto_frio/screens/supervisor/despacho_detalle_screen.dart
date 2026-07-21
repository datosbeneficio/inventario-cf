import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../models/despacho.dart';
import '../../../../shared/models/empresa_config.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../utils/despacho_pdf.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';

class DespachoDetalleScreen extends StatelessWidget {
  final Despacho despacho;
  const DespachoDetalleScreen({super.key, required this.despacho});

  @override
  Widget build(BuildContext context) {
    final empresa = context.watch<EmpresaConfig>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Guía N° ${despacho.guiaNro}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimir / Guardar PDF',
            onPressed: () => _imprimir(context, empresa),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Eliminar despacho',
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Encabezado empresa ──────────────────────────────────────
            if (empresa.nombre.isNotEmpty) ...[
              Center(
                child: Column(
                  children: [
                    Text(
                      empresa.nombre.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (empresa.subtitulo.isNotEmpty)
                      Text(empresa.subtitulo,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center),
                    if (empresa.direccion.isNotEmpty)
                      Text(empresa.direccion,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center),
                    if (empresa.nit.isNotEmpty || empresa.contacto.isNotEmpty)
                      Text(
                        [
                          if (empresa.nit.isNotEmpty) 'NIT. ${empresa.nit}',
                          if (empresa.contacto.isNotEmpty)
                            'Contacto: ${empresa.contacto}',
                        ].join(' - '),
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Fila identificación ─────────────────────────────────────
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GUÍA N°:  ${despacho.guiaNro}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                    Text(
                      despacho.destinoNombre.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Grid de datos ───────────────────────────────────────────
            _InfoGrid(d: despacho),
            const SizedBox(height: 16),

            // ── Observaciones ───────────────────────────────────────────
            if (despacho.observaciones.isNotEmpty) ...[
              Text('Observaciones',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(despacho.observaciones,
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Tabla de líneas ─────────────────────────────────────────
            Text('Productos despachados',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _LineasCard(d: despacho),
            const SizedBox(height: 16),

            // ── Descartes ───────────────────────────────────────────────
            if (despacho.descartes.isNotEmpty) ...[
              Text('Descartes',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _DescartesCard(d: despacho),
              const SizedBox(height: 16),
            ],

            // ── Firmas ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('ENCARGADO DESPACHO',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Nombre: ${despacho.encargadoNombre}',
                          style: const TextStyle(fontSize: 12)),
                      Text('C.C. ${despacho.encargadoCedula}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.black45)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Firma y sello Supervisor',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: Column(
                    children: [
                      const Text('ENCARGADO TRANSPORTE',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Nombre: ${despacho.conductorNombre}',
                          style: const TextStyle(fontSize: 12)),
                      Text('C.C. ${despacho.conductorCedula}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.black45)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Firma Conductor',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Botón imprimir ──────────────────────────────────────────
            FilledButton.icon(
              onPressed: () => _imprimir(context, empresa),
              icon: const Icon(Icons.print),
              label: const Text('Imprimir / Guardar PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimir(BuildContext context, EmpresaConfig empresa) async {
    await Printing.layoutPdf(
      onLayout: (fmt) async =>
          (await buildDespachoPdf(despacho, empresa)).save(),
    );
  }

  Future<void> _eliminar(BuildContext context) async {
    final ok = await showConfirmDelete(
        context, 'Guía N° ${despacho.guiaNro}');
    if (ok && context.mounted) {
      await FirestoreService.instance.deleteDespacho(despacho.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ── Grid informativo ────────────────────────────────────────────────────────

class _InfoGrid extends StatelessWidget {
  final Despacho d;
  const _InfoGrid({required this.d});

  @override
  Widget build(BuildContext context) {
    final vencPollo = d.vencimientoPollo != null
        ? formatDate(d.vencimientoPollo!)
        : '';
    final vencMenud = d.vencimientoMenudencias != null
        ? formatDate(d.vencimientoMenudencias!)
        : '';

    final rows = [
      ['Fecha despacho', formatDate(d.fechaDespacho),
        'Dirección destino', d.direccion],
      ['Fecha beneficio', formatDate(d.fechaBeneficio),
        'Municipio y depto.', '${d.municipio}, ${d.departamento}'],
      ['Placa vehículo', d.placa,
        'Temp. canal', d.tempCanal],
      ['Capacidad', '${formatNum(d.capacidadKg)} kg',
        'Temp. menudencias', d.tempMenudencias],
      ['Hora de salida', d.horaSalida,
        'Temp. pre-enfriam.', d.tempPreEnfriamiento],
      ['Conductor', d.conductorNombre,
        'N° precinto', d.precinto],
      ['CC / Plancha',
        '${d.conductorCedula} / ${d.plancha}', '', ''],
      ['Lote Pollo Canal', d.lotePollo,
        'Vence Pollo', vencPollo],
      ['Lote Menudencias', d.loteMenudencias,
        'Vence Menudencias', vencMenud],
      ['Dictamen',
        d.dictamen == 'aprobado' ? 'Aprobado' : 'Aprob. Condicional',
        'Liberación', d.liberado ? 'Sí' : 'No'],
    ];

    return Table(
      border: TableBorder.all(color: Colors.black26, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.6),
      },
      children: rows
          .map((r) => TableRow(children: [
                _TCell(r[0], isLabel: true),
                _TCell(r[1]),
                _TCell(r[2], isLabel: true),
                _TCell(r[3]),
              ]))
          .toList(),
    );
  }
}

class _TCell extends StatelessWidget {
  final String text;
  final bool isLabel;
  const _TCell(this.text, {this.isLabel = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isLabel ? Colors.black54 : Colors.black87,
          fontWeight: isLabel ? FontWeight.normal : FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Tabla de líneas de producto ─────────────────────────────────────────────

class _LineasCard extends StatelessWidget {
  final Despacho d;
  const _LineasCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(cs.secondaryContainer),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Rango')),
            DataColumn(label: Text('Unidades'), numeric: true),
            DataColumn(label: Text('Peso (kg)'), numeric: true),
            DataColumn(label: Text('Peso promedio'), numeric: true),
            DataColumn(label: Text('Canastillas'), numeric: true),
          ],
          rows: [
            ...d.lineas.map(
              (l) => DataRow(cells: [
                DataCell(
                  l.esRemanente
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.rangoNombre),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'DÍA ANT.',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(l.rangoNombre),
                ),
                DataCell(Text(formatNum(l.unidades))),
                DataCell(Text(formatKg(l.peso))),
                DataCell(Text(l.rangoTipo == 'aves' && l.unidades > 0
                    ? formatPesoAve(l.peso, l.unidades)
                    : '—')),
                DataCell(Text(formatNum(l.canastillas))),
              ]),
            ),
            // Fila de totales
            DataRow(
              color: WidgetStateProperty.all(cs.surfaceContainerHigh),
              cells: [
                const DataCell(Text('TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(formatNum(d.totalUnidades),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(formatNum(d.totalPeso),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                DataCell(Text(formatNum(d.totalCanastillas),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabla de descartes ──────────────────────────────────────────────────────

class _DescartesCard extends StatelessWidget {
  final Despacho d;
  const _DescartesCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Table(
        border: TableBorder.all(color: Colors.black26, width: 0.5),
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
          2: IntrinsicColumnWidth(),
        },
        children: [
          // Encabezado
          TableRow(
            decoration: BoxDecoration(color: cs.errorContainer),
            children: [
              _DCell('Sigla',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onErrorContainer)),
              _DCell('Descripción',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onErrorContainer)),
              _DCell('Cant.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onErrorContainer)),
            ],
          ),
          // Filas
          ...d.descartes.map(
            (e) => TableRow(children: [
              _DCell(e.sigla,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              _DCell(e.tipo),
              _DCell(formatNum(e.cantidad),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _DCell(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(text, style: style ?? const TextStyle(fontSize: 13)),
    );
  }
}
