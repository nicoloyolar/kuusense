// Creates (if needed) a Firebase Auth account and marks it as staff
// (admin or researcher) by writing staff/{uid}. Staff docs cannot be written
// from the apps, so this is the only way to grant web-platform access.
//
// Uses Application Default Credentials (`gcloud auth application-default login`).
//
// Usage (from firebase/):
//   node admin/set-staff.mjs --project kuusense-test --email a@b.cl --role admin [--password X]
//   node admin/set-staff.mjs --project kuusense-test --email a@b.cl --remove
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) {
      const next = all[i + 1];
      acc.push([a.slice(2), next && !next.startsWith('--') ? next : true]);
    }
    return acc;
  }, []),
);

const { project, email, password } = args;
const role = args.role ?? 'admin';
if (!project || !email) {
  console.error('Uso: node admin/set-staff.mjs --project <id> --email <correo> [--role admin|researcher] [--password <clave>] [--remove]');
  process.exit(1);
}
if (project.startsWith('demo-')) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
}
if (!['admin', 'researcher'].includes(role)) {
  console.error(`Rol no válido: ${role}`);
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: project });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(email);
  console.log(`Cuenta existente: ${email} (${user.uid})`);
} catch (e) {
  if (e.code !== 'auth/user-not-found') throw e;
  if (!password) {
    console.error('La cuenta no existe: agrega --password para crearla.');
    process.exit(1);
  }
  user = await auth.createUser({ email, password, emailVerified: false });
  console.log(`Cuenta creada: ${email} (${user.uid})`);
}

const ref = db.collection('staff').doc(user.uid);
if (args.remove) {
  await ref.delete();
  console.log('Acceso de staff eliminado.');
} else {
  await ref.set({ role });
  console.log(`Rol asignado: ${role} en ${project}`);
}
