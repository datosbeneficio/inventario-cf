import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/despacho.dart';
import '../../../shared/models/empresa_config.dart';
import '../../../shared/utils/constants.dart'; // kDescartesSiglas, kTipoAves
import '../../../shared/utils/formatters.dart';

/// Construye el documento PDF de la guía de despacho.
Future<pw.Document> buildDespachoPdf(Despacho d, EmpresaConfig empresa) async {
  // Cargar logo desde assets
  final logoData = await rootBundle.load('assets/images/logo.png');
  final logoImg = pw.MemoryImage(logoData.buffer.asUint8List());

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _titulo(),
          pw.SizedBox(height: 6),
          _header(empresa, logoImg,
              d.lineas.isNotEmpty ? d.lineas.first.clienteNombre : ''),
          pw.SizedBox(height: 8),
          _idRow(d),
          pw.SizedBox(height: 6),
          _infoGrid(d),
          pw.SizedBox(height: 10),
          _lineasTable(d, esEspecial: false),
          if (d.lineas.any((l) => l.esEspecial)) ...[
            pw.SizedBox(height: 10),
            _especialHeader(d),
            pw.SizedBox(height: 4),
            _lineasTable(d, esEspecial: true),
          ],
          if (d.descartes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _descartesSection(d.descartes),
          ],
          if (d.observaciones.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _observacionesSection(d.observaciones),
          ],
          pw.SizedBox(height: 16),
          _firmas(d),
        ],
      ),
    ),
  );

  return doc;
}

// ── Título del formato ───────────────────────────────────────────────────

pw.Widget _titulo() => pw.Center(
      child: pw.Text(
        'GUIA DE TRANSPORTE Y DESTINO',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
      ),
    );

// ── Encabezado empresa ──────────────────────────────────────────────────────

pw.Widget _header(EmpresaConfig e, pw.ImageProvider logo, String clienteNombre) {
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, height: 48, fit: pw.BoxFit.contain),
          if (clienteNombre.isNotEmpty) ...[
            pw.SizedBox(width: 16),
            pw.Text(
              clienteNombre.toUpperCase(),
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 20),
            ),
          ],
        ],
      ),
      pw.SizedBox(height: 4),
      if (e.nombre.isNotEmpty)
        pw.Text(e.nombre.toUpperCase(),
            style: bold.copyWith(fontSize: 13),
            textAlign: pw.TextAlign.center),
      if (e.subtitulo.isNotEmpty)
        pw.Text(e.subtitulo,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center),
      if (e.direccion.isNotEmpty)
        pw.Text(e.direccion,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center),
      if (e.nit.isNotEmpty || e.contacto.isNotEmpty)
        pw.Text(
          [
            if (e.nit.isNotEmpty) 'NIT. ${e.nit}',
            if (e.contacto.isNotEmpty) 'Contacto: ${e.contacto}',
          ].join(' - '),
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
    ],
  );
}

// ── Fila de identificación (DESCRIPCIÓN | Guía | DESTINO) ──────────────────

pw.Widget _idRow(Despacho d) {
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);

  const border = pw.Border.fromBorderSide(pw.BorderSide(width: 0.5));

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(2),
    },
    children: [
      pw.TableRow(children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
              border: border),
          child: pw.Text('DESCRIPCIÓN DEL DESPACHO', style: boldSm),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(
              color: PdfColors.red,
              border: border),
          child: pw.Text('Guía N°:  ${d.guiaNro}',
              style: boldSm.copyWith(color: PdfColors.white)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(border: border),
          child: pw.Text(d.destinoNombre.toUpperCase(), style: boldSm),
        ),
      ]),
    ],
  );
}

// ── Grid de datos del despacho ──────────────────────────────────────────────

pw.Widget _infoGrid(Despacho d) {
  final vencPollo = d.vencimientoPollo != null
      ? formatDate(d.vencimientoPollo!)
      : '';
  final vencMenud = d.vencimientoMenudencias != null
      ? formatDate(d.vencimientoMenudencias!)
      : '';

  final rows = [
    ['FECHA DE DESPACHO:', formatDate(d.fechaDespacho), 'DIRECCIÓN DESTINO:', d.direccion],
    ['FECHA DE BENEFICIO:', formatDate(d.fechaBeneficio), 'MUNICIPIO Y DEPTO:', '${d.municipio}, ${d.departamento}'],
    ['PLACA VEHÍCULO:', d.placa, 'TEMP. CANAL:', d.tempCanal],
    ['CAPACIDAD:', '${formatNum(d.capacidadKg)} KG', 'TEMP. MENUDENCIAS:', d.tempMenudencias],
    ['HORA SALIDA:', d.horaSalida, 'TEMP. PRE-ENFRIAM.:', d.tempPreEnfriamiento],
    ['CONDUCTOR:', d.conductorNombre, 'Nº PRECINTO:', d.precinto],
    ['CC / PLANCHA:', '${d.conductorCedula} / ${d.plancha}', '', ''],
    ['LOTE POLLO EN CANAL:', d.lotePollo, 'VENCE POLLO:', vencPollo],
    ['LOTE MENUDENCIAS:', d.loteMenudencias, 'VENCE MENUDENCIAS:', vencMenud],
    if (d.loteEspecial.isNotEmpty)
      ['LOTE ESPECIAL:', d.loteEspecial, 'VENCE ESPECIAL:',
       d.vencimientoEspecial != null ? formatDate(d.vencimientoEspecial!) : ''],
    ['DICTAMEN:',
     d.dictamen == 'aprobado' ? 'APROBADO' : 'APROB. CONDICIONAL',
     'LIBERACIÓN:', d.liberado ? 'SÍ' : 'NO'],
  ];

  const labelStyle = pw.TextStyle(fontSize: 8);
  final valueStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.5),
      1: pw.FlexColumnWidth(1.5),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
    },
    children: rows.map((r) {
      return pw.TableRow(children: [
        _cell(r[0], labelStyle),
        _cell(r[1], valueStyle),
        _cell(r[2], labelStyle),
        _cell(r[3], valueStyle),
      ]);
    }).toList(),
  );
}

pw.Widget _cell(String text, pw.TextStyle style) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: style),
    );

// ── Tabla de líneas de producto ─────────────────────────────────────────────

pw.Widget _especialHeader(Despacho d) {
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: const pw.BoxDecoration(
      color: PdfColors.red100,
      border: pw.Border.fromBorderSide(pw.BorderSide(width: 0.5)),
    ),
    child: pw.Text('PRODUCTO ESPECIAL', style: boldSm),
  );
}

pw.Widget _lineasTable(Despacho d, {required bool esEspecial}) {
  final headerStyle =
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  final cellStyle = const pw.TextStyle(fontSize: 8);
  final totalStyle =
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);

  final lineas = d.lineas.where((l) => l.esEspecial == esEspecial).toList();
  final totCan = lineas.fold(0, (s, l) => s + l.canastillas);
  final totUnid = lineas.fold(0, (s, l) => s + l.unidades);
  final totPeso = lineas.fold(0.0, (s, l) => s + l.peso);

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.3),
      3: pw.FlexColumnWidth(1.4),
      4: pw.FlexColumnWidth(1.3),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: esEspecial ? PdfColors.red50 : PdfColors.grey200,
        ),
        children: [
          _cell('RANGO', headerStyle),
          _cell('UNIDADES', headerStyle),
          _cell('PESO (KG)', headerStyle),
          _cell('PESO PROMEDIO', headerStyle),
          _cell('CANASTILLAS', headerStyle),
        ],
      ),
      ...lineas.map((l) {
        final esAves = l.rangoTipo == kTipoAves && l.unidades > 0;
        return pw.TableRow(children: [
          l.esRemanente
              ? pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(l.rangoNombre, style: cellStyle),
                      pw.Text(
                        'DÍA ANT.',
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange800,
                        ),
                      ),
                    ],
                  ),
                )
              : _cell(l.rangoNombre, cellStyle),
          _cell(formatNum(l.unidades), cellStyle),
          _cell(formatKg(l.peso), cellStyle),
          _cell(esAves ? formatPesoAve(l.peso, l.unidades) : '—', cellStyle),
          _cell(formatNum(l.canastillas), cellStyle),
        ]);
      }),
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: esEspecial ? PdfColors.red50 : PdfColors.grey100,
        ),
        children: [
          _cell('TOTAL${esEspecial ? ' ESPECIAL' : ''}', totalStyle),
          _cell(formatNum(totUnid), totalStyle),
          _cell(formatKg(totPeso), totalStyle),
          _cell('', totalStyle),
          _cell(formatNum(totCan), totalStyle),
        ],
      ),
    ],
  );
}

// ── Observaciones ───────────────────────────────────────────────────────────

pw.Widget _observacionesSection(String texto) {
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  final bodyStyle = const pw.TextStyle(fontSize: 9);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('OBSERVACIONES', style: boldSm),
      pw.SizedBox(height: 3),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(
          border: pw.Border.fromBorderSide(pw.BorderSide(width: 0.5)),
        ),
        child: pw.Text(texto, style: bodyStyle),
      ),
    ],
  );
}

// ── Descartes ───────────────────────────────────────────────────────────────

pw.Widget _descartesSection(List<DespachoDescarte> descartes) {
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  final headerStyle =
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  final cellStyle = const pw.TextStyle(fontSize: 8);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('DESCARTES', style: boldSm),
      pw.SizedBox(height: 3),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: const {
          0: pw.IntrinsicColumnWidth(),
          1: pw.FlexColumnWidth(),
          2: pw.IntrinsicColumnWidth(),
        },
        children: [
          // Encabezado
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColors.red50),
            children: [
              _cell('SIGLA', headerStyle),
              _cell('DESCRIPCIÓN', headerStyle),
              _cell('CANT.', headerStyle),
            ],
          ),
          // Filas
          ...descartes.map(
            (e) => pw.TableRow(children: [
              _cell(e.sigla,
                  pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8)),
              _cell(e.tipo, cellStyle),
              _cell(formatNum(e.cantidad), cellStyle),
            ]),
          ),
        ],
      ),
    ],
  );
}

// ── Área de firmas ──────────────────────────────────────────────────────────

pw.Widget _firmas(Despacho d) {
  const style = pw.TextStyle(fontSize: 9);
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('ENCARGADO DESPACHO', style: boldSm),
            pw.SizedBox(height: 2),
            pw.Text('Nombre: ${d.encargadoNombre}', style: style),
            pw.Text('C.C. ${d.encargadoCedula}', style: style),
            pw.SizedBox(height: 8),
            pw.Container(
                height: 40,
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(width: 0.5)))),
            pw.SizedBox(height: 4),
            pw.Text('Firma y sello Supervisor', style: style,
                textAlign: pw.TextAlign.center),
          ],
        ),
      ),
      pw.SizedBox(width: 40),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('ENCARGADO TRANSPORTE', style: boldSm),
            pw.SizedBox(height: 2),
            pw.Text('Nombre: ${d.conductorNombre}', style: style),
            pw.Text('C.C. ${d.conductorCedula}', style: style),
            pw.SizedBox(height: 8),
            pw.Container(
                height: 40,
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(width: 0.5)))),
            pw.SizedBox(height: 4),
            pw.Text('Firma Conductor', style: style,
                textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    ],
  );
}
