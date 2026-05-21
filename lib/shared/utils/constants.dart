// ── Roles ─────────────────────────────────────────────────────────────────────
// Los roles se almacenan en Firestore: users/{uid} → { rol: String }
const String kRolCoordinador = 'coordinador';
const String kRolEncargado = 'encargado';
const String kRolSupervisor = 'supervisor';
const String kRolSupervisorMenudencias = 'supervisor_menudencias';

// ── Tipos de inventario ────────────────────────────────────────────────────────
const String kTipoAves = 'aves';
const String kTipoMenudencias = 'menudencias';

// Subtipos de menudencias
const String kSubtipoCanastillas = 'canastillas';
const String kSubtipoPaquetes = 'paquetes';

// ── Logística ─────────────────────────────────────────────────────────────────
/// Peso estándar de una canastilla vacía en kg.
/// Se usa para calcular Peso Bruto = Peso Neto + (canastillas × kPesoCanastillaKg).
const double kPesoCanastillaKg = 2.0;

// ── Descartes de despacho ──────────────────────────────────────────────────────
/// Siglas oficiales de descarte y su descripción completa.
/// La clave 'OTRO' permite registrar causas no estándar.
const Map<String, String> kDescartesSiglas = {
  'HG': 'Hígado Friable',
  'SC': 'Solicitud Cliente',
  'PC': 'Pescuezo Comido',
  'PP': 'Pérdida de Proceso',
  'PD': 'Pododermatitis',
  'OTRO': 'Otro',
};
