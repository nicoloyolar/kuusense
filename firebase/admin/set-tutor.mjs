// Enables an EXISTING sign-in account as a tutor (writes tutors/{uid}), or
// fills in the email of an existing tutor profile. New tutors are created by
// an admin from the web platform; use this only when the email already has
// an account (e.g. a staff member who also needs the app).
//
// Uses Application Default Credentials (`gcloud auth application-default login`).
//
// Usage (from firebase/):
//   node admin/set-tutor.mjs --project kuusense-test --email a@b.cl [--name "Ana"] [--type family|teacher|therapist]
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
const { project, email, name } = args;
const type = args.type ?? 'family';
if (!project || !email) {
  console.error('Uso: node admin/set-tutor.mjs --project <id> --email <correo> [--name <nombre>] [--type family|teacher|therapist]');
  process.exit(1);
}
if (!['family', 'teacher', 'therapist'].includes(type)) {
  console.error(`Tipo no válido: ${type}`);
  process.exit(1);
}
if (project.startsWith('demo-')) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
}

initializeApp({ credential: applicationDefault(), projectId: project });
const user = await getAuth().getUserByEmail(email); // fails if the account does not exist
const ref = getFirestore().collection('tutors').doc(user.uid);
const snap = await ref.get();
if (snap.exists) {
  await ref.update({ email: email.toLowerCase(), ...(name ? { displayName: name } : {}) });
  console.log(`Tutor existente actualizado: ${email} (${user.uid})`);
} else {
  if (!name) {
    console.error('La cuenta no es tutor todavía: agrega --name para crear su perfil.');
    process.exit(1);
  }
  await ref.set({ displayName: name, type, email: email.toLowerCase(), active: true, createdAtMs: Date.now() });
  console.log(`Cuenta habilitada como tutor: ${email} (${user.uid})`);
}
