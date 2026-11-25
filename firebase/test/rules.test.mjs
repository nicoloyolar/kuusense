// Security-rules tests. Run with: cd firebase && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove, arrayUnion, collection, collectionGroup, deleteDoc, doc, getDoc, getDocs,
  query, setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';
import { ref, uploadString, getBytes } from 'firebase/storage';

let env;

// alice: owner of NNA c1 · carol: linked to c1 · bob: tutor, not linked
// dave: researcher (staff) · eve: account without tutor profile
const user = (uid, provider = 'password') => env.authenticatedContext(uid, {
  email: `${uid}@test.cl`, firebase: { sign_in_provider: provider },
});
const alice = () => user('alice');
const carol = () => user('carol');
const bob = () => user('bob');
const dave = () => user('dave');
const eve = () => user('eve');

const HOUR = 60 * 60 * 1000;
const C1 = 'c1';
const C2 = 'c2';
const INVITE = 'K7M2PQ';
const EXPIRED = 'EXP234';
const OTHER_CHILD_INVITE = 'QQQ234';

const tutor = (over = {}) => ({ displayName: 'Ana', type: 'family', createdAtMs: 1, ...over });
const child = (over = {}) => ({
  code: 'N-ABCD', birthYear: 2018, dunnQuadrant: null, ownerUid: 'alice',
  tutorUids: ['alice'], consentConfirmedAtMs: 1, createdAtMs: 1, ...over,
});
const profile = (over = {}) => ({ displayName: 'Tomi', avatarId: 'fox', ...over });
const session = (over = {}) => ({
  childId: C1, deviceId: 'MD-V5-0000001', createdByUid: 'alice', startedAtMs: 1, endedAtMs: null,
  status: 'recording', packetCount: 0, streams: [], files: {}, live: null, appVersion: '0.1.0', ...over,
});

const childRef = (ctx, id = C1) => doc(ctx.firestore(), 'children', id);
const profileRef = (ctx, id = C1) => doc(ctx.firestore(), 'children', id, 'private', 'profile');
const sessionRef = (ctx, id = 's1', childId = C1) =>
  doc(ctx.firestore(), 'children', childId, 'sessions', id);
const inviteRef = (ctx, code = INVITE) => doc(ctx.firestore(), 'invites', code);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-kuusense',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
    storage: { rules: readFileSync('storage.rules', 'utf8') },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of ['alice', 'bob', 'carol']) await setDoc(doc(db, 'tutors', uid), tutor());
    await setDoc(doc(db, 'staff', 'dave'), { role: 'researcher' });
    await setDoc(doc(db, 'children', C1), child({ tutorUids: ['alice', 'carol'] }));
    await setDoc(doc(db, 'children', C1, 'private', 'profile'), profile());
    await setDoc(doc(db, 'children', C2), child({ code: 'N-WXYZ', ownerUid: 'bob', tutorUids: ['bob'] }));
    await setDoc(doc(db, 'children', C1, 'sessions', 's1'), session());
    const now = Date.now();
    await setDoc(doc(db, 'invites', INVITE), { childId: C1, createdByUid: 'alice', createdAtMs: now, expiresAtMs: now + HOUR });
    await setDoc(doc(db, 'invites', EXPIRED), { childId: C1, createdByUid: 'alice', createdAtMs: 1, expiresAtMs: 2 });
    await setDoc(doc(db, 'invites', OTHER_CHILD_INVITE), { childId: C2, createdByUid: 'bob', createdAtMs: now, expiresAtMs: now + HOUR });
  });
});

describe('tutors', () => {
  test('a user creates and reads their own tutor profile', async () => {
    await assertSucceeds(setDoc(doc(eve().firestore(), 'tutors', 'eve'), tutor({ type: 'teacher' })));
    await assertSucceeds(getDoc(doc(eve().firestore(), 'tutors', 'eve')));
  });
  test('cannot read or write another tutor profile', async () => {
    await assertFails(getDoc(doc(bob().firestore(), 'tutors', 'alice')));
    await assertFails(setDoc(doc(bob().firestore(), 'tutors', 'alice'), tutor()));
  });
  test('rejects unknown tutor type and extra fields', async () => {
    await assertFails(setDoc(doc(eve().firestore(), 'tutors', 'eve'), tutor({ type: 'boss' })));
    await assertFails(setDoc(doc(eve().firestore(), 'tutors', 'eve'), tutor({ rut: '1-9' })));
  });
  test('anonymous users cannot become tutors', async () => {
    const anon = user('anon', 'anonymous');
    await assertFails(setDoc(doc(anon.firestore(), 'tutors', 'anon'), tutor()));
  });
  test('staff reads tutor profiles; staff docs are read-only for clients', async () => {
    await assertSucceeds(getDoc(doc(dave().firestore(), 'tutors', 'alice')));
    await assertSucceeds(getDoc(doc(dave().firestore(), 'staff', 'dave')));
    await assertFails(setDoc(doc(eve().firestore(), 'staff', 'eve'), { role: 'admin' }));
    await assertFails(getDoc(doc(eve().firestore(), 'staff', 'dave')));
  });
});

describe('registering a child (NNA)', () => {
  const register = (ctx, id, data = child({ ownerUid: 'bob', tutorUids: ['bob'] }), prof = profile()) => {
    const b = writeBatch(ctx.firestore());
    b.set(childRef(ctx, id), data);
    b.set(profileRef(ctx, id), prof);
    return b.commit();
  };

  test('a tutor registers a child with its private profile in one batch', async () => {
    await assertSucceeds(register(bob(), 'new'));
  });
  test('requires a tutor profile', async () => {
    await assertFails(register(eve(), 'new', child({ ownerUid: 'eve', tutorUids: ['eve'] })));
  });
  test('cannot register a child for someone else or with extra tutors', async () => {
    await assertFails(register(bob(), 'new', child({ ownerUid: 'alice', tutorUids: ['alice'] })));
    await assertFails(register(bob(), 'new', child({ ownerUid: 'bob', tutorUids: ['bob', 'carol'] })));
  });
  test('consent confirmation is required', async () => {
    const { consentConfirmedAtMs, ...noConsent } = child({ ownerUid: 'bob', tutorUids: ['bob'] });
    await assertFails(register(bob(), 'new', noConsent));
  });
  test('rejects personal fields and invalid values', async () => {
    const base = { ownerUid: 'bob', tutorUids: ['bob'] };
    await assertFails(register(bob(), 'new', child({ ...base, fullName: 'Tomás Pérez' })));
    await assertFails(register(bob(), 'new', child({ ...base, code: 'Tomás' })));
    await assertFails(register(bob(), 'new', child({ ...base, birthYear: 3000 })));
    await assertFails(register(bob(), 'new', child({ ...base, dunnQuadrant: 'happy' })));
    await assertFails(register(bob(), 'new', undefined, profile({ photoUrl: 'http://x' })));
  });
});

describe('reading children', () => {
  test('two tutors linked to the same child both see it', async () => {
    for (const ctx of [alice(), carol()]) {
      await assertSucceeds(getDoc(childRef(ctx)));
      await assertSucceeds(getDoc(profileRef(ctx)));
    }
    await assertSucceeds(getDocs(query(collection(alice().firestore(), 'children'),
      where('tutorUids', 'array-contains', 'alice'))));
    await assertSucceeds(getDocs(query(collection(carol().firestore(), 'children'),
      where('tutorUids', 'array-contains', 'carol'))));
  });
  test('an unlinked tutor sees nothing of the child', async () => {
    await assertFails(getDoc(childRef(bob())));
    await assertFails(getDoc(profileRef(bob())));
    await assertFails(getDocs(collection(bob().firestore(), 'children')));
  });
  test('staff see the pseudonymous part but never the private profile', async () => {
    await assertSucceeds(getDocs(collection(dave().firestore(), 'children')));
    await assertFails(getDoc(profileRef(dave())));
  });
});

describe('editing children', () => {
  test('a linked tutor edits birth year and Dunn quadrant', async () => {
    await assertSucceeds(updateDoc(childRef(carol()), { dunnQuadrant: 'seeking', birthYear: 2017 }));
    await assertSucceeds(updateDoc(profileRef(carol()), { displayName: 'Tomás' }));
  });
  test('cannot change owner, code or consent', async () => {
    await assertFails(updateDoc(childRef(carol()), { ownerUid: 'carol' }));
    await assertFails(updateDoc(childRef(alice()), { code: 'N-ZZZZ' }));
    await assertFails(updateDoc(childRef(alice()), { consentConfirmedAtMs: 5 }));
  });
  test('unlinked tutors and staff cannot edit', async () => {
    await assertFails(updateDoc(childRef(bob()), { birthYear: 2017 }));
    await assertFails(updateDoc(childRef(dave()), { dunnQuadrant: 'seeking' }));
    await assertFails(updateDoc(profileRef(bob()), { displayName: 'x' }));
  });
});

describe('unlinking and deleting', () => {
  test('a non-owner tutor unlinks themself', async () => {
    await assertSucceeds(updateDoc(childRef(carol()), { tutorUids: arrayRemove('carol') }));
  });
  test('a non-owner cannot unlink others', async () => {
    await assertFails(updateDoc(childRef(carol()), { tutorUids: arrayRemove('alice') }));
  });
  test('the owner unlinks others but not themself', async () => {
    await assertSucceeds(updateDoc(childRef(alice()), { tutorUids: arrayRemove('carol') }));
    await assertFails(updateDoc(childRef(alice()), { tutorUids: arrayRemove('alice') }));
  });
  test('nobody adds tutors directly', async () => {
    await assertFails(updateDoc(childRef(alice()), { tutorUids: arrayUnion('bob') }));
    await assertFails(updateDoc(childRef(bob()), { tutorUids: arrayUnion('bob') }));
  });
  test('only the owner deletes the child', async () => {
    await assertFails(deleteDoc(childRef(carol())));
    const ctx = alice();
    const b = writeBatch(ctx.firestore());
    b.delete(profileRef(ctx));
    b.delete(childRef(ctx));
    await assertSucceeds(b.commit());
  });
});

describe('invites', () => {
  const join = (ctx, code = INVITE, childId = C1, uid = 'bob') => {
    const b = writeBatch(ctx.firestore());
    b.update(childRef(ctx, childId), { tutorUids: arrayUnion(uid), lastInviteCode: code });
    b.delete(inviteRef(ctx, code));
    return b.commit();
  };

  test('a linked tutor creates an invite valid for 48 h', async () => {
    const now = Date.now();
    await assertSucceeds(setDoc(inviteRef(carol(), 'ABC234'), {
      childId: C1, createdByUid: 'carol', createdAtMs: now, expiresAtMs: now + 48 * HOUR,
    }));
  });
  test('rejects invites for unlinked children, too long, or overwriting a code', async () => {
    const now = Date.now();
    await assertFails(setDoc(inviteRef(bob(), 'ABC234'), {
      childId: C1, createdByUid: 'bob', createdAtMs: now, expiresAtMs: now + HOUR,
    }));
    await assertFails(setDoc(inviteRef(alice(), 'ABC234'), {
      childId: C1, createdByUid: 'alice', createdAtMs: now, expiresAtMs: now + 72 * HOUR,
    }));
    await assertFails(setDoc(inviteRef(carol(), INVITE), {
      childId: C1, createdByUid: 'carol', createdAtMs: now, expiresAtMs: now + HOUR,
    }));
  });
  test('tutors look up a code but cannot list codes', async () => {
    await assertSucceeds(getDoc(inviteRef(bob())));
    await assertFails(getDocs(collection(bob().firestore(), 'invites')));
    await assertFails(getDoc(inviteRef(eve())));
  });
  test('a tutor joins with a valid invite, which is consumed', async () => {
    await assertSucceeds(join(bob()));
    await assertSucceeds(getDoc(profileRef(bob())));
    let stillThere = true;
    await env.withSecurityRulesDisabled(async (ctx) => {
      stillThere = (await getDoc(inviteRef(ctx))).exists();
    });
    if (stillThere) throw new Error('invite should be deleted');
  });
  test('an invite cannot be reused', async () => {
    await join(bob());
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'tutors', 'eve'), tutor()));
    await assertFails(join(eve(), INVITE, C1, 'eve'));
  });
  test('joining without consuming the invite fails', async () => {
    await assertFails(updateDoc(childRef(bob()), { tutorUids: arrayUnion('bob'), lastInviteCode: INVITE }));
  });
  test('expired or mismatched invites fail', async () => {
    await assertFails(join(bob(), EXPIRED));
    // bob is not linked to C1 and holds an invite that belongs to C2.
    await assertFails(join(bob(), OTHER_CHILD_INVITE, C1, 'bob'));
  });
  test('an already linked tutor cannot "join" again', async () => {
    await assertFails(join(carol(), INVITE, C1, 'carol'));
  });
  test('cannot add someone else with an invite', async () => {
    await assertFails(join(bob(), INVITE, C1, 'eve'));
  });
  test('the inviting tutor can cancel an invite', async () => {
    await assertSucceeds(deleteDoc(inviteRef(carol())));
    await assertFails(deleteDoc(inviteRef(alice(), OTHER_CHILD_INVITE)));
  });
});

describe('sessions', () => {
  test('a linked tutor records a session', async () => {
    await assertSucceeds(setDoc(sessionRef(carol(), 's2'), session({ createdByUid: 'carol' })));
  });
  test('unlinked tutors cannot record; nobody impersonates another tutor', async () => {
    await assertFails(setDoc(sessionRef(bob(), 's2'), session({ createdByUid: 'bob' })));
    await assertFails(setDoc(sessionRef(carol(), 's2'), session({ createdByUid: 'alice' })));
    await assertFails(setDoc(sessionRef(carol(), 's2'), session({ createdByUid: 'carol', childId: C2 })));
  });
  test('the recording phone updates live values but not the child', async () => {
    await assertSucceeds(updateDoc(sessionRef(alice()), { live: { heartRate: 70, updatedAtMs: 2 } }));
    await assertFails(updateDoc(sessionRef(alice()), { childId: C2 }));
    await assertFails(updateDoc(sessionRef(carol()), { status: 'uploaded' }));
  });
  test('a session stores its context and marked events', async () => {
    const context = { place: 'school', activity: 'classwork', present: ['teacher'] };
    await assertSucceeds(setDoc(sessionRef(carol(), 's2'), session({ createdByUid: 'carol', context, events: [] })));
    await assertSucceeds(updateDoc(sessionRef(alice()), {
      events: arrayUnion({ atMs: 5, kind: 'crisisStart' }),
      context: { place: 'home', activity: null, present: [] },
    }));
  });
  test('context only accepts known kinds, without free text', async () => {
    const bad = [
      { place: 'Colegio San Juan' },
      { activity: 'swimming' },
      { present: ['grandma'] },
      { place: 'home', childName: 'Ana' },
    ];
    for (const context of bad) {
      await assertFails(setDoc(sessionRef(carol(), 's2'), session({ createdByUid: 'carol', context })));
      await assertFails(updateDoc(sessionRef(alice()), { context }));
    }
  });
  test('events must be a bounded list; only the recording phone writes them', async () => {
    await assertFails(updateDoc(sessionRef(alice()), { events: 'crisis' }));
    const tooMany = Array.from({ length: 1001 }, (_, i) => ({ atMs: i, kind: 'restless' }));
    await assertFails(updateDoc(sessionRef(alice()), { events: tooMany }));
    await assertFails(updateDoc(sessionRef(carol()), { events: arrayUnion({ atMs: 5, kind: 'calmed' }) }));
  });
  test('linked tutors and staff read sessions; others cannot', async () => {
    await assertSucceeds(getDocs(collection(carol().firestore(), 'children', C1, 'sessions')));
    await assertSucceeds(getDocs(collection(dave().firestore(), 'children', C1, 'sessions')));
    await assertFails(getDocs(collection(bob().firestore(), 'children', C1, 'sessions')));
  });
  test('staff list all sessions across children; tutors cannot', async () => {
    await assertSucceeds(getDocs(collectionGroup(dave().firestore(), 'sessions')));
    await assertFails(getDocs(collectionGroup(alice().firestore(), 'sessions')));
  });
  test('sessions cannot be deleted from the apps', async () => {
    await assertFails(deleteDoc(sessionRef(alice())));
  });
});

describe('storage', () => {
  const path = `children/${C1}/sessions/s1`;

  test('the recording tutor uploads raw.csv', async () => {
    await assertSucceeds(uploadString(ref(alice().storage(), `${path}/raw.csv`), '1,1,1,EA,1,100,2.0\n'));
  });
  test('other tutors and other file names are rejected', async () => {
    await assertFails(uploadString(ref(carol().storage(), `${path}/raw.csv`), 'x'));
    await assertFails(uploadString(ref(alice().storage(), `${path}/evil.html`), 'x'));
  });
  test('staff download raw data; tutors cannot', async () => {
    await uploadString(ref(alice().storage(), `${path}/raw.csv`), 'data');
    await assertSucceeds(getBytes(ref(dave().storage(), `${path}/raw.csv`)));
    await assertFails(getBytes(ref(carol().storage(), `${path}/raw.csv`)));
  });
});
