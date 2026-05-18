/**
 * Script de migración: renombrar colecciones de Firestore al namespace cf_
 *
 * CUÁNDO ejecutar: UNA sola vez, antes de desplegar la versión con Fase 1.3.
 *
 * CÓMO ejecutar (Node.js con firebase-admin):
 *   1. npm install firebase-admin
 *   2. Descargar clave de servicio: Firebase Console → Configuración del proyecto
 *      → Cuentas de servicio → Generar nueva clave privada
 *   3. node migrate_collections.js /ruta/a/serviceAccountKey.json
 *
 * COLECCIONES que se migran:
 *   ingresos  → cf_ingresos
 *   salidas   → cf_salidas
 *   despachos → cf_despachos
 *   vehiculos → cf_vehiculos
 *   destinos  → cf_destinos
 *
 * COLECCIONES que NO se migran (ya correctas):
 *   clientes, config, users
 *
 * El script copia todos los documentos de cada colección vieja a la nueva,
 * preservando los IDs y todos los campos. NO elimina las colecciones viejas
 * (se pueden borrar manualmente desde la consola una vez verificado).
 */

const admin = require('firebase-admin');

const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  console.error('Uso: node migrate_collections.js <ruta/serviceAccountKey.json>');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const MIGRATIONS = [
  { from: 'ingresos',  to: 'cf_ingresos'  },
  { from: 'salidas',   to: 'cf_salidas'   },
  { from: 'despachos', to: 'cf_despachos' },
  { from: 'vehiculos', to: 'cf_vehiculos' },
  { from: 'destinos',  to: 'cf_destinos'  },
];

async function migrateCollection(from, to) {
  const snapshot = await db.collection(from).get();
  if (snapshot.empty) {
    console.log(`  [${from}] vacía, nada que migrar.`);
    return 0;
  }

  let count = 0;
  // Firestore admite máximo 500 escrituras por batch
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    batch.set(db.collection(to).doc(doc.id), doc.data());
    batchCount++;
    count++;
    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
      console.log(`  [${from}→${to}] ${count} documentos migrados…`);
    }
  }
  if (batchCount > 0) await batch.commit();
  return count;
}

async function main() {
  console.log('Iniciando migración de colecciones Firestore…\n');
  for (const { from, to } of MIGRATIONS) {
    process.stdout.write(`Migrando ${from} → ${to}… `);
    const n = await migrateCollection(from, to);
    console.log(`✓ ${n} documentos`);
  }
  console.log('\nMigración completada.');
  console.log('Verifica en Firebase Console que las colecciones cf_* tienen los datos.');
  console.log('Cuando estés seguro, puedes eliminar las colecciones antiguas manualmente.');
}

main().catch((err) => {
  console.error('Error durante la migración:', err);
  process.exit(1);
});
