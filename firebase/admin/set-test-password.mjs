// Test period only: sets the same password on EVERY sign-in account of the
// test project (tutors, researchers and admins), so the team can enter any
// account. Refuses to run against any other project. Accounts created later
// get a random password: run this again to include them.
//
// Uses Application Default Credentials (`gcloud auth application-default login`).
//
// Usage (from firebase/):
//   node admin/set-test-password.mjs --project kuusense-test --password <clave>
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) {
      const next = all[i + 1];
      acc.push([a.slice(2), next && !next.startsWith('--') ? next : true]);
    }
    return acc;
  }, []),
);

const ALLOWED = ['kuusense-test', 'demo-kuusense'];
const { project, password } = args;
if (!ALLOWED.includes(project) || typeof password !== 'string' || password.length < 6) {
  console.error(`Uso: node admin/set-test-password.mjs --project <${ALLOWED.join('|')}> --password <clave de 6+ caracteres>`);
  process.exit(1);
}
if (project.startsWith('demo-')) process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';

initializeApp({ credential: applicationDefault(), projectId: project });
const auth = getAuth();

let count = 0;
let pageToken;
do {
  const page = await auth.listUsers(1000, pageToken);
  for (const u of page.users) {
    await auth.updateUser(u.uid, { password });
    console.log(`  ${u.email ?? u.uid}`);
    count++;
  }
  pageToken = page.pageToken;
} while (pageToken);
console.log(`Contraseña de pruebas aplicada a ${count} cuentas de ${project}.`);
