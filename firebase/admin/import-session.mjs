// Imports a session recorded with the terminal tool (`make record`) into
// kuusense-test, as if the mobile app had recorded and uploaded it: uploads
// raw.csv, sync.csv, events.csv and signals.csv to Storage and writes the
// session document with the same fields the app writes (stats from stats.json).
// `make import-session` first runs `emotibit preview` to (re)build
// signals.csv and stats.json.
//
// The session id comes from the folder name, so importing the same folder
// twice updates the same session instead of duplicating it.
//
// The child (NNA) must already exist: children are only registered from the
// apps, by a tutor.
//
// Usage (from firebase/), with Application Default Credentials:
//   node admin/import-session.mjs --project kuusense-test --dir <recording folder> --child <childId>
// Optional: --place home|school|therapy|other  --activity <SessionActivity name>
import { readFileSync, existsSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

const ALLOWED_PROJECTS = { 'kuusense-test': 'kuusense-test.firebasestorage.app' };
const FILES = ['raw.csv', 'sync.csv', 'events.csv'];
const OPTIONAL_FILES = ['signals.csv'];
// Same filter as TypeTag.sensorStreams + TypeTag.derived in packages/emotibit.
const STREAM_TAGS = new Set([
  'EA', 'EL', 'ER', 'PI', 'PR', 'PG', 'O2', 'T0', 'T1', 'TH', 'H0',
  'AX', 'AY', 'AZ', 'GX', 'GY', 'GZ', 'MX', 'MY', 'MZ',
  'HR', 'BI', 'SA', 'SF', 'SR',
]);

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) {
      const next = all[i + 1];
      acc.push([a.slice(2), next && !next.startsWith('--') ? next : true]);
    }
    return acc;
  }, []),
);
const { project, dir, child } = args;
const place = args.place ?? 'other';
const activity = args.activity ?? 'rest';

function fail(msg) {
  console.error(msg);
  process.exit(1);
}
if (!project || !dir || !child) {
  fail('Uso: node admin/import-session.mjs --project kuusense-test --dir <carpeta> --child <id>');
}
if (!ALLOWED_PROJECTS[project]) fail(`Proyecto no permitido: ${project}`);
const folder = resolve(dir);
for (const f of FILES) {
  if (!existsSync(join(folder, f))) fail(`Falta ${f} en ${folder}`);
}

// ---------------------------------------------------------------- read the recording
const rawLines = readFileSync(join(folder, 'raw.csv'), 'utf8').split('\n').filter(Boolean);
const tags = new Set();
const latest = {};
for (const line of rawLines) {
  const parts = line.split(',');
  const tag = parts[3];
  if (STREAM_TAGS.has(tag)) tags.add(tag);
  const value = Number(parts[parts.length - 1]);
  if (parts.length > 6 && Number.isFinite(value)) latest[tag] = value;
}
const syncRows = readFileSync(join(folder, 'sync.csv'), 'utf8')
  .split('\n').slice(1).filter(Boolean).map((l) => Number(l.split(',')[0]));
if (syncRows.length < 2) fail('sync.csv no tiene suficientes filas para saber inicio y fin.');
const startedAtMs = syncRows[0];
const endedAtMs = syncRows[syncRows.length - 1];

const statsPath = join(folder, 'stats.json');
const stats = existsSync(statsPath) ? JSON.parse(readFileSync(statsPath, 'utf8')) : null;

const summary = readFileSync(join(folder, 'resumen.txt'), 'utf8');
const deviceId = summary.match(/^EmotiBit (\S+)/m)?.[1] ?? args.device ?? 'desconocido';

// ---------------------------------------------------------------- write to Firebase
initializeApp({ credential: applicationDefault(), projectId: project, storageBucket: ALLOWED_PROJECTS[project] });
const db = getFirestore();
const bucket = getStorage().bucket();

const childId = child;
const childSnap = await db.collection('children').doc(childId).get();
if (!childSnap.exists) fail(`No existe el NNA ${childId}`);
const ownerUid = childSnap.get('ownerUid');

const sessionId = 'rec-' + basename(folder).replace(/[^A-Za-z0-9-]/g, '-');
const dirPath = `children/${childId}/sessions/${sessionId}`;
const files = {};
for (const f of [...FILES, ...OPTIONAL_FILES.filter((f) => existsSync(join(folder, f)))]) {
  const dest = `${dirPath}/${f}`;
  await bucket.upload(join(folder, f), { destination: dest, contentType: 'text/csv' });
  files[f] = dest;
}

await db.collection('children').doc(childId).collection('sessions').doc(sessionId).set({
  childId,
  deviceId,
  createdByUid: ownerUid,
  startedAtMs,
  endedAtMs,
  status: 'uploaded',
  packetCount: rawLines.length,
  streams: [...tags].sort(),
  files,
  live: {
    updatedAtMs: endedAtMs,
    heartRate: latest.HR ?? null,
    eda: latest.EA ?? null,
    temperature: latest.T0 ?? latest.TH ?? null,
    batteryPercent: latest['B%'] ?? null,
  },
  appVersion: 'importada-terminal',
  context: { place, activity, present: [] },
  events: [],
  stats,
});

const mins = ((endedAtMs - startedAtMs) / 60000).toFixed(1);
console.log(`Sesión ${sessionId} importada en ${project}: NNA ${childId}, ${rawLines.length} paquetes, ${mins} min, `
  + `${tags.size} señales, archivos: ${Object.keys(files).join(', ')}`);
