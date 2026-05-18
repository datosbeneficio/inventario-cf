import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/despacho.dart';
import '../../../shared/models/empresa_config.dart';
import '../../../shared/utils/formatters.dart';

/// Construye el documento PDF de la guía de despacho.
/// [fotoBytes] son los bytes de la foto del precinto en memoria;
/// si se omiten el PDF se genera sin esa sección.
Future<pw.Document> buildDespachoPdf(
    Despacho d, EmpresaConfig empresa, {Uint8List? fotoBytes}) async {
  final pw.ImageProvider? precintoImg =
      fotoBytes != null ? pw.MemoryImage(fotoBytes) : null;

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
          _header(empresa, logoImg),
          pw.SizedBox(height: 8),
          _idRow(d),
          pw.SizedBox(height: 6),
          _infoGrid(d),
          pw.SizedBox(height: 10),
          _lineasTable(d),
          if (d.observaciones.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _observacionesSection(d.observaciones),
          ],
          if (precintoImg != null) ...[
            pw.SizedBox(height: 10),
            _precintoSection(precintoImg),
          ],
          pw.SizedBox(height: 16),
          _firmas(),
        ],
      ),
    ),
  );

  return doc;
}

// ── Encabezado empresa ──────────────────────────────────────────────────────

pw.Widget _header(EmpresaConfig e, pw.ImageProvider logo) {
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  return pw.Column(
    children: [
      pw.Center(
        child: pw.Image(logo, height: 48, fit: pw.BoxFit.contain),
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
    ['CC / CEL:', '${d.conductorCedula} / ${d.conductorCelular}', '', ''],
    ['LOTE POLLO EN CANAL:', d.lotePollo, 'VENCE POLLO:', vencPollo],
    ['LOTE MENUDENCIAS:', d.loteMenudencias, 'VENCE MENUDENCIAS:', vencMenud],
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

pw.Widget _lineasTable(Despacho d) {
  final headerStyle =
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  final cellStyle = const pw.TextStyle(fontSize: 8);
  final totalStyle =
      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1),
      4: pw.FlexColumnWidth(1),
    },
    children: [
      // Encabezado
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cell('CLIENTE', headerStyle),
          _cell('RANGO', headerStyle),
          _cell('CANAST.', headerStyle),
          _cell('UNIDADES', headerStyle),
          _cell('PESO (kg)', headerStyle),
        ],
      ),
      // Filas de datos
      ...d.lineas.map((l) => pw.TableRow(children: [
            _cell(l.clienteNombre, cellStyle),
            _cell(l.rangoNombre, cellStyle),
            _cell(formatNum(l.canastillas), cellStyle),
            _cell(formatNum(l.unidades), cellStyle),
            _cell(formatNum(l.peso), cellStyle),
          ])),
      // Fila de totales
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell('TOTAL', totalStyle),
          _cell('', totalStyle),
          _cell(formatNum(d.totalCanastillas), totalStyle),
          _cell(formatNum(d.totalUnidades), totalStyle),
          _cell(formatNum(d.totalPeso), totalStyle),
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

// ── Foto del precinto ───────────────────────────────────────────────────────

pw.Widget _precintoSection(pw.ImageProvider img) {
  final boldSm = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('FOTO PRECINTO DE SEGURIDAD', style: boldSm),
      pw.SizedBox(height: 4),
      pw.Container(
        height: 120,
        decoration: const pw.BoxDecoration(
          border: pw.Border.fromBorderSide(pw.BorderSide(width: 0.5)),
        ),
        child: pw.Center(
          child: pw.Image(img, fit: pw.BoxFit.contain),
        ),
      ),
    ],
  );
}

// ── Área de firmas ──────────────────────────────────────────────────────────

pw.Widget _firmas() {
  const style = pw.TextStyle(fontSize: 9);
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Column(
          children: [
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
          children: [
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
