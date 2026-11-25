// Loads or removes FICTIONAL demo data (no real children, no signal files) so
// the platform can be shown before real recordings exist.
//
// Every demo document id starts with `demo-`; the apps show those with a
// "Demo" label, and --clear removes exactly them. Refuses to run on any
// project other than kuusense-test (or the local demo-* emulator project).
//
// Usage (from firebase/), with Application Default Credentials:
//   node admin/demo-data.mjs --project kuusense-test --owner tutor@correo.cl [--tutors otro@correo.cl,otra@correo.cl]
//   node admin/demo-data.mjs --project kuusense-test --clear
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const ALLOWED_PROJECTS = ['kuusense-test'];
const PREFIX = 'demo-';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) {
      const next = all[i + 1];
      acc.push([a.slice(2), next && !next.startsWith('--') ? next : true]);
    }
    return acc;
  }, []),
);
const { project, owner, clear, tutors } = args;
if (!project || (!clear && !owner)) {
  console.error('Uso: node admin/demo-data.mjs --project <id> (--owner <correo> | --clear)');
  process.exit(1);
}
if (!ALLOWED_PROJECTS.includes(project) && !project.startsWith('demo-')) {
  console.error(`Proyecto no permitido para datos demo: ${project}`);
  process.exit(1);
}
if (project.startsWith('demo-')) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
}

initializeApp({ credential: applicationDefault(), projectId: project });
const db = getFirestore();

async function clearDemo() {
  const snap = await db.collection('children').get();
  const demo = snap.docs.filter((d) => d.id.startsWith(PREFIX));
  for (const d of demo) await db.recursiveDelete(d.ref); // includes sessions and private profile
  console.log(`Datos demo eliminados: ${demo.length} NNA con sus sesiones.`);
}

if (clear) {
  await clearDemo();
  process.exit(0);
}

const ownerUid = (await getAuth().getUserByEmail(owner)).uid;
// Extra tutors linked to every demo child (they see the same demo in the app).
const extraUids = [];
for (const email of (typeof tutors === 'string' ? tutors.split(',') : [])) {
  if (email.trim()) extraUids.push((await getAuth().getUserByEmail(email.trim())).uid);
}

// Deterministic pseudo-random numbers so every load looks the same.
let seed = 20261125;
const rand = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const pick = (xs) => xs[Math.floor(rand() * xs.length)];
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));

const DAY = 24 * 3600 * 1000;
const MIN = 60 * 1000;
const now = Date.now();

// Fictional first names (shown only to the linked tutor); the "Demo" badge
// comes from the `demo-` id, not the name.
const CHILDREN = [
  { nick: 'Sofía', avatar: 'sun', birthYear: 2017, dunn: 'avoiding', sessions: 9 },
  { nick: 'Mateo', avatar: 'rocket', birthYear: 2015, dunn: 'seeking', sessions: 8 },
  { nick: 'Emilia', avatar: 'bee', birthYear: 2019, dunn: 'sensitivity', sessions: 7 },
  { nick: 'Benjamín', avatar: 'star', birthYear: 2013, dunn: 'registration', sessions: 6 },
  { nick: 'Agustina', avatar: 'music', birthYear: 2016, dunn: 'avoiding', sessions: 6 },
  { nick: 'Tomás', avatar: 'rabbit', birthYear: 2020, dunn: null, sessions: 4 },
];
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const code = () => 'N-' + Array.from({ length: 4 }, () => pick(CODE_CHARS)).join('');

const ACTIVITIES = {
  home: ['freePlay', 'meal', 'rest', 'transition'],
  school: ['classwork', 'freePlay', 'transition', 'meal'],
  therapy: ['therapy', 'freePlay'],
  other: ['transition', 'freePlay', 'other'],
};
const PRESENT = { home: ['family'], school: ['teacher'], therapy: ['therapist'], other: ['family'] };
const NOTES = [
  'Ruido fuerte en la sala',
  'Cambio de actividad sin aviso',
  'Mucha gente en el lugar',
  'Rechazó la colación',
  'Pidió salir al patio',
  'Se usaron audífonos con cancelación de ruido',
];
const STREAMS = ['AX', 'AY', 'AZ', 'B%', 'BV', 'EA', 'EL', 'GX', 'GY', 'GZ', 'HR', 'MX', 'MY', 'MZ', 'PG', 'PI', 'PR', 'T1', 'TH'];

/// Behaviors spread over the session, following one of three patterns.
function makeEvents(startMs, durationMs) {
  const r = rand();
  let kinds;
  if (r < 0.35) kinds = rand() < 0.5 ? [] : ['restless'];
  else if (r < 0.7) kinds = ['restless', pick(['coversEars', 'repetitiveMovement']), 'strategyApplied', 'calmed'];
  else {
    kinds = ['restless', pick(['coversEars', 'repetitiveMovement']), 'crying', 'crisisStart',
      'strategyApplied', 'calmed', 'crisisEnd'];
  }
  const events = [];
  let t = startMs + durationMs * (0.1 + rand() * 0.3);
  const step = (durationMs * 0.5) / Math.max(kinds.length, 1);
  for (const kind of kinds) {
    events.push({ atMs: Math.round(t), kind });
    t += step * (0.5 + rand());
  }
  if (rand() < 0.4) {
    events.push({ atMs: Math.round(startMs + durationMs * rand() * 0.9), kind: 'note', note: pick(NOTES) });
  }
  return events.sort((a, b) => a.atMs - b.atMs);
}

await clearDemo(); // reloading replaces the previous demo set
const batch = db.batch();
let sessionCount = 0;
CHILDREN.forEach((c, i) => {
  const childId = `${PREFIX}${String(i + 1).padStart(2, '0')}`;
  const ref = db.collection('children').doc(childId);
  const createdAtMs = now - between(30, 40) * DAY;
  batch.set(ref, {
    code: code(),
    birthYear: c.birthYear,
    dunnQuadrant: c.dunn,
    ownerUid,
    tutorUids: [ownerUid, ...extraUids],
    consentConfirmedAtMs: createdAtMs,
    createdAtMs,
  });
  batch.set(ref.collection('private').doc('profile'), { displayName: c.nick, avatarId: c.avatar });

  for (let s = 0; s < c.sessions; s++) {
    const day = new Date(now - between(0, 27) * DAY);
    day.setHours(between(9, 18), between(0, 59), 0, 0);
    const startedAtMs = Math.min(day.getTime(), now - 2 * 3600 * 1000);
    const durationMs = between(12, 55) * MIN + between(0, 59) * 1000;
    const place = pick(['home', 'home', 'school', 'school', 'therapy', 'other']);
    const present = [...PRESENT[place]];
    if (place === 'therapy' && rand() < 0.5) present.push('family');
    const failed = rand() < 0.06;
    batch.set(ref.collection('sessions').doc(`${PREFIX}s${String(s + 1).padStart(2, '0')}`), {
      childId,
      deviceId: 'MD-V5-DEMO001',
      createdByUid: ownerUid,
      startedAtMs,
      endedAtMs: startedAtMs + durationMs,
      status: failed ? 'failed' : 'uploaded',
      packetCount: Math.round((durationMs / 1000) * between(55, 65)),
      streams: STREAMS,
      files: {},
      live: null,
      appVersion: '0.1.0',
      context: { place, activity: pick(ACTIVITIES[place]), present },
      events: makeEvents(startedAtMs, durationMs),
    });
    sessionCount++;
  }
});
await batch.commit();
console.log(`Datos demo cargados en ${project}: ${CHILDREN.length} NNA y ${sessionCount} sesiones, vinculados a ${owner}.`);
