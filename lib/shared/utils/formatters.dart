import 'package:intl/intl.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _timeFormat = DateFormat('HH:mm');
final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
final _numberFormat = NumberFormat('#,##0.##', 'es');

String formatDate(DateTime dt) => _dateFormat.format(dt);
String formatTime(DateTime dt) => _timeFormat.format(dt);
String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);
String formatNum(num value) => _numberFormat.format(value);
String formatKg(double value) => '${_numberFormat.format(value)} kg';

/// Peso promedio por ave: "0.476 kg/ave". Devuelve "—" si unidades == 0.
String formatPesoAve(double pesoKg, int unidades) {
  if (unidades <= 0) return '—';
  return '${(pesoKg / unidades).toStringAsFixed(3)} kg/ave';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isInRange(DateTime dt, DateTime from, DateTime to) {
  final date = DateTime(dt.year, dt.month, dt.day);
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day);
  return !date.isBefore(f) && !date.isAfter(t);
}
