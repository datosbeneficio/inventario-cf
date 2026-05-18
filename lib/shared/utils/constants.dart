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
