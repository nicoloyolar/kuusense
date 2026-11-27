// Writes (or refreshes) every tutor's public card (tutors/{uid}/public/card:
// name, type and photo, never the email) from their tutor doc. Needed once
// for tutors created before cards existed; the apps keep cards in sync.
//
// Uses Application Default Credentials (`gcloud auth application-default login`).
//
// Usage (from firebase/):
//   node admin/backfill-tutor-cards.mjs --project kuusense-test
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const i = process.argv.indexOf('--project');
const project = i > 0 ? process.argv[i + 1] : undefined;
if (!project) {
  console.error('Uso: node admin/backfill-tutor-cards.mjs --project <id>');
  process.exit(1);
}
if (project.startsWith('demo-')) process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';

initializeApp({ credential: applicationDefault(), projectId: project });
const db = getFirestore();
const tutors = await db.collection('tutors').get();
for (const t of tutors.docs) {
  const d = t.data();
  await t.ref.collection('public').doc('card').set({
    displayName: d.displayName ?? '',
    type: d.type ?? 'family',
    photoPath: d.photoPath ?? null,
  });
  console.log(`  ${d.displayName} (${d.type})`);
}
console.log(`Tarjetas escritas: ${tutors.size}`);
