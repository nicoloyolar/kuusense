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
import { ref, uploadString, getBytes, deleteObject } from 'firebase/storage';

let env;

// alice: owner of NNA c1 · carol: linked to c1 · bob: tutor, not linked
// dave: researcher (staff) · eve: account without tutor profile
// frank: admin (staff) · gina: deactivated tutor, still listed in c1
// hugo: deactivated researcher
const user = (uid, provider = 'password') => env.authenticatedContext(uid, {
  email: `${uid}@test.cl`, firebase: { sign_in_provider: provider },
});
const alice = () => user('alice');
const carol = () => user('carol');
const bob = () => user('bob');
const dave = () => user('dave');
const eve = () => user('eve');
const frank = () => user('frank');
const gina = () => user('gina');
const hugo = () => user('hugo');

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
    await setDoc(doc(db, 'tutors', 'gina'), tutor({ email: 'gina@test.cl', active: false }));
    await setDoc(doc(db, 'staff', 'dave'), { role: 'researcher' });
    await setDoc(doc(db, 'staff', 'frank'), { role: 'admin' });
    await setDoc(doc(db, 'staff', 'hugo'), {
      role: 'researcher', displayName: 'Hugo', email: 'hugo@test.cl', active: false, createdAtMs: 1,
    });
    await setDoc(doc(db, 'children', C1), child({ tutorUids: ['alice', 'carol', 'gina'] }));
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
  const newTutor = (over = {}) => tutor({ email: 'eve@test.cl', active: true, ...over });
  const tutorRef = (ctx, uid) => doc(ctx.firestore(), 'tutors', uid);

  test('only an admin creates tutors, with email and active', async () => {
    await assertFails(setDoc(tutorRef(eve(), 'eve'), newTutor()));
    await assertFails(setDoc(tutorRef(dave(), 'eve'), newTutor()));
    await assertFails(setDoc(tutorRef(alice(), 'eve'), newTutor()));
    await assertFails(setDoc(tutorRef(frank(), 'eve'), tutor()));
    await assertFails(setDoc(tutorRef(frank(), 'eve'), newTutor({ active: false })));
    await assertSucceeds(setDoc(tutorRef(frank(), 'eve'), newTutor()));
  });
  test('rejects unknown tutor type and extra fields', async () => {
    await assertFails(setDoc(tutorRef(frank(), 'eve'), newTutor({ type: 'boss' })));
    await assertFails(setDoc(tutorRef(frank(), 'eve'), newTutor({ rut: '1-9' })));
  });
  test('a tutor reads their profile and edits only name and type', async () => {
    await assertSucceeds(getDoc(tutorRef(alice(), 'alice')));
    await assertSucceeds(updateDoc(tutorRef(alice(), 'alice'), { displayName: 'Ana M.', type: 'teacher' }));
    await assertFails(updateDoc(tutorRef(alice(), 'alice'), { active: false }));
    await assertFails(updateDoc(tutorRef(alice(), 'alice'), { email: 'x@test.cl' }));
  });
  test('a tutor sets or clears their own photo path, only in their folder', async () => {
    await assertSucceeds(updateDoc(tutorRef(alice(), 'alice'), { photoPath: 'tutors/alice/photo-123.jpg' }));
    await assertSucceeds(updateDoc(tutorRef(alice(), 'alice'), { photoPath: null }));
    await assertFails(updateDoc(tutorRef(alice(), 'alice'), { photoPath: 'tutors/bob/photo-1.jpg' }));
    await assertFails(updateDoc(tutorRef(alice(), 'alice'), { photoPath: 'https://evil.example/x.jpg' }));
  });
  test('a deactivated tutor reads their profile but cannot edit it', async () => {
    await assertSucceeds(getDoc(tutorRef(gina(), 'gina')));
    await assertFails(updateDoc(tutorRef(gina(), 'gina'), { displayName: 'G' }));
    await assertFails(updateDoc(tutorRef(gina(), 'gina'), { active: true }));
  });
  test('an admin edits and deactivates tutors, but never deletes them', async () => {
    await assertSucceeds(updateDoc(tutorRef(frank(), 'alice'), { displayName: 'Ana', email: 'a@test.cl' }));
    await assertSucceeds(updateDoc(tutorRef(frank(), 'bob'), { active: false }));
    await assertFails(updateDoc(tutorRef(frank(), 'bob'), { createdAtMs: 9 }));
    await assertFails(deleteDoc(tutorRef(frank(), 'bob')));
  });
  test('admins list tutors; researchers and other tutors cannot read them', async () => {
    await assertSucceeds(getDocs(collection(frank().firestore(), 'tutors')));
    await assertFails(getDocs(collection(dave().firestore(), 'tutors')));
    await assertFails(getDoc(tutorRef(dave(), 'alice')));
    await assertFails(getDoc(tutorRef(bob(), 'alice')));
    await assertFails(setDoc(tutorRef(bob(), 'alice'), tutor()));
  });
  test('staff docs: each member reads their own; others cannot write', async () => {
    await assertSucceeds(getDoc(doc(dave().firestore(), 'staff', 'dave')));
    await assertFails(setDoc(doc(eve().firestore(), 'staff', 'eve'), { role: 'admin' }));
    await assertFails(setDoc(doc(frank().firestore(), 'staff', 'eve'), { role: 'admin' }));
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
    await assertFails(register(bob(), 'new', child({ ...base, birthYear: 1900 })));
  });
  test('adults can be registered (birth year from 1920)', async () => {
    const base = { ownerUid: 'bob', tutorUids: ['bob'] };
    await assertSucceeds(register(bob(), 'new', child({ ...base, birthYear: 1985 }),
      profile({ birthDate: '1985-03-14' })));
  });
  test('the full birth date lives only in the private profile', async () => {
    const base = { ownerUid: 'bob', tutorUids: ['bob'] };
    await assertSucceeds(register(bob(), 'new', undefined, profile({ birthDate: '2018-02-28' })));
    await assertFails(register(bob(), 'new2', child({ ...base, birthDate: '2018-02-28' })));
    await assertFails(register(bob(), 'new3', undefined, profile({ birthDate: '28-02-2018' })));
    await assertFails(register(bob(), 'new4', undefined, profile({ birthDate: '2018-13-01' })));
    await assertFails(register(bob(), 'new5', undefined, profile({ birthDate: 20180228 })));
  });
  test('a linked tutor adds the birth date to an older profile', async () => {
    await assertSucceeds(updateDoc(profileRef(alice()), { birthDate: '2018-05-01' }));
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
  test('tutors do not add tutors directly', async () => {
    await assertFails(updateDoc(childRef(alice()), { tutorUids: arrayUnion('bob') }));
    await assertFails(updateDoc(childRef(bob()), { tutorUids: arrayUnion('bob') }));
  });
  test('only the owner deletes the child', async () => {
    await assertFails(deleteDoc(childRef(carol())));
    await assertFails(deleteDoc(childRef(dave())));
    const ctx = alice();
    const b = writeBatch(ctx.firestore());
    b.delete(profileRef(ctx));
    b.delete(childRef(ctx));
    await assertSucceeds(b.commit());
  });
});

describe('admin manages children (NNA)', () => {
  const register = (ctx, id, data, prof = profile()) => {
    const b = writeBatch(ctx.firestore());
    b.set(childRef(ctx, id), data);
    b.set(profileRef(ctx, id), prof);
    return b.commit();
  };

  test('an admin registers a child for an existing tutor', async () => {
    await assertSucceeds(register(frank(), 'new', child({ ownerUid: 'bob', tutorUids: ['bob'] })));
  });
  test('the owner must be an existing tutor and the only linked one', async () => {
    await assertFails(register(frank(), 'new', child({ ownerUid: 'nobody', tutorUids: ['nobody'] })));
    await assertFails(register(frank(), 'new', child({ ownerUid: 'bob', tutorUids: ['bob', 'carol'] })));
  });
  test('researchers cannot register children', async () => {
    await assertFails(register(dave(), 'new', child({ ownerUid: 'bob', tutorUids: ['bob'] })));
  });
  test('admins read every private profile; researchers never', async () => {
    await assertSucceeds(getDoc(profileRef(frank())));
    await assertSucceeds(getDocs(collectionGroup(frank().firestore(), 'private')));
    await assertFails(getDocs(collectionGroup(dave().firestore(), 'private')));
    await assertFails(getDocs(collectionGroup(alice().firestore(), 'private')));
  });
  test('an admin links tutors and changes the owner, who stays linked', async () => {
    await assertSucceeds(updateDoc(childRef(frank()), { tutorUids: ['alice', 'carol', 'bob'] }));
    await assertSucceeds(updateDoc(childRef(frank()), { ownerUid: 'bob', tutorUids: ['bob'] }));
    await assertFails(updateDoc(childRef(frank()), { ownerUid: 'carol', tutorUids: ['bob'] }));
    await assertFails(updateDoc(childRef(frank()), { tutorUids: ['bob', 'bob'] }));
  });
  test('an admin edits the profile but never code or consent', async () => {
    await assertSucceeds(updateDoc(childRef(frank()), { birthYear: 2016, dunnQuadrant: 'avoiding' }));
    await assertSucceeds(updateDoc(profileRef(frank()), { displayName: 'Tomás' }));
    await assertFails(updateDoc(childRef(frank()), { code: 'N-ZZZZ' }));
    await assertFails(updateDoc(childRef(frank()), { consentConfirmedAtMs: 5 }));
  });
  test('an admin deletes a child with its profile', async () => {
    const ctx = frank();
    const b = writeBatch(ctx.firestore());
    b.delete(profileRef(ctx));
    b.delete(childRef(ctx));
    await assertSucceeds(b.commit());
  });
});

describe('deactivated tutors', () => {
  test('see nothing of the children they are still listed in', async () => {
    await assertFails(getDoc(childRef(gina())));
    await assertFails(getDoc(profileRef(gina())));
    await assertFails(getDocs(query(collection(gina().firestore(), 'children'),
      where('tutorUids', 'array-contains', 'gina'))));
    await assertFails(getDoc(sessionRef(gina())));
  });
  test('cannot register children, record or edit', async () => {
    const ctx = gina();
    const b = writeBatch(ctx.firestore());
    b.set(childRef(ctx, 'new'), child({ ownerUid: 'gina', tutorUids: ['gina'] }));
    b.set(profileRef(ctx, 'new'), profile());
    await assertFails(b.commit());
    await assertFails(setDoc(sessionRef(gina(), 's9'), session({ createdByUid: 'gina' })));
    await assertFails(updateDoc(childRef(gina()), { birthYear: 2017 }));
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
  test('the recording phone stores session figures; only known keys', async () => {
    const stats = {
      heartRate: { min: 54, mean: 65, max: 80 }, eda: { min: 2.7, mean: 6, max: 35 }, temperature: null,
      scrCount: 18, lossPercent: 0.8, batteryStart: 88, batteryEnd: 81,
    };
    await assertSucceeds(updateDoc(sessionRef(alice()), { stats }));
    await assertFails(updateDoc(sessionRef(alice()), { stats: 'ok' }));
    await assertFails(updateDoc(sessionRef(alice()), { stats: { ...stats, childName: 'Ana' } }));
    await assertFails(updateDoc(sessionRef(carol()), { stats }));
  });
  test('events must be a bounded list; only the recording phone writes them', async () => {
    await assertFails(updateDoc(sessionRef(alice()), { events: 'crisis' }));
    const tooMany = Array.from({ length: 1001 }, (_, i) => ({ atMs: i, kind: 'restless' }));
    await assertFails(updateDoc(sessionRef(alice()), { events: tooMany }));
    await assertFails(updateDoc(sessionRef(carol()), { events: arrayUnion({ atMs: 5, kind: 'calmed' }) }));
  });
  test('the recording phone stores how the session ended and its gaps', async () => {
    const gaps = [{ fromMs: 1000, toMs: 4000 }];
    await assertSucceeds(updateDoc(sessionRef(alice()), { endReason: 'deviceLost', gaps }));
    await assertSucceeds(updateDoc(sessionRef(alice()), { endReason: 'appClosed' }));
    await assertSucceeds(updateDoc(sessionRef(alice()), { endReason: 'stopped', gaps: [] }));
    await assertFails(updateDoc(sessionRef(alice()), { endReason: 'crashed' }));
    await assertFails(updateDoc(sessionRef(alice()), { gaps: 'none' }));
    const tooMany = Array.from({ length: 501 }, (_, i) => ({ fromMs: i, toMs: i + 1 }));
    await assertFails(updateDoc(sessionRef(alice()), { gaps: tooMany }));
    await assertFails(updateDoc(sessionRef(carol()), { endReason: 'stopped' }));
    await assertFails(setDoc(sessionRef(carol(), 's2'),
      session({ createdByUid: 'carol', endReason: 'oops' })));
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
  test('the recording tutor uploads the per-second summary', async () => {
    await assertSucceeds(uploadString(ref(alice().storage(), `${path}/signals.csv`), 'host_epoch_ms,heart_rate\n'));
  });
  test('other tutors and other file names are rejected', async () => {
    await assertFails(uploadString(ref(carol().storage(), `${path}/raw.csv`), 'x'));
    await assertFails(uploadString(ref(alice().storage(), `${path}/evil.html`), 'x'));
  });
  test('a tutor uploads, replaces and removes their own JPEG or PNG photo', async () => {
    const photo = (ctx, name = 'photo-1.jpg') => ref(ctx.storage(), `tutors/alice/${name}`);
    const jpeg = { contentType: 'image/jpeg' };
    await assertSucceeds(uploadString(photo(alice()), 'jpg', 'raw', jpeg));
    await assertSucceeds(uploadString(photo(alice(), 'photo-2.jpg'), 'jpg', 'raw', jpeg));
    await assertSucceeds(deleteObject(photo(alice())));
    await assertFails(uploadString(photo(bob()), 'jpg', 'raw', jpeg));
    await assertSucceeds(uploadString(photo(alice(), 'photo-3.png'), 'png', 'raw', { contentType: 'image/png' }));
    await assertFails(uploadString(photo(alice(), 'photo-5.gif'), 'x', 'raw', { contentType: 'image/gif' }));
    await assertFails(uploadString(photo(alice(), 'photo-4.jpg'), '<html>', 'raw', { contentType: 'text/html' }));
  });
  test('the tutor, admins and active tutors see a tutor photo; never staff researchers', async () => {
    const path = 'tutors/alice/photo-1.jpg';
    await uploadString(ref(alice().storage(), path), 'jpg', 'raw', { contentType: 'image/jpeg' });
    await assertSucceeds(getBytes(ref(alice().storage(), path)));
    await assertSucceeds(getBytes(ref(frank().storage(), path)));
    await assertSucceeds(getBytes(ref(carol().storage(), path)));
    await assertFails(getBytes(ref(dave().storage(), path)));
    await assertFails(getBytes(ref(eve().storage(), path)));
  });
  test('staff download raw data; tutors cannot', async () => {
    await uploadString(ref(alice().storage(), `${path}/raw.csv`), 'data');
    await assertSucceeds(getBytes(ref(dave().storage(), `${path}/raw.csv`)));
    await assertFails(getBytes(ref(carol().storage(), `${path}/raw.csv`)));
    await assertFails(getBytes(ref(hugo().storage(), `${path}/raw.csv`)));
  });
});

describe('researchers maintainer (staff)', () => {
  const staffRef = (ctx, uid) => doc(ctx.firestore(), 'staff', uid);
  const researcher = (over = {}) => ({
    role: 'researcher', displayName: 'Eva', email: 'eve@test.cl', active: true, createdAtMs: 1, ...over,
  });

  test('only an admin lists staff', async () => {
    await assertSucceeds(getDocs(collection(frank().firestore(), 'staff')));
    await assertFails(getDocs(collection(dave().firestore(), 'staff')));
    await assertFails(getDocs(collection(alice().firestore(), 'staff')));
  });
  test('an admin creates researchers, never admins', async () => {
    await assertSucceeds(setDoc(staffRef(frank(), 'eve'), researcher()));
    await assertFails(setDoc(staffRef(frank(), 'eve2'), researcher({ role: 'admin' })));
    await assertFails(setDoc(staffRef(frank(), 'eve3'), researcher({ active: false })));
    await assertFails(setDoc(staffRef(frank(), 'eve4'), researcher({ phone: '123' })));
    await assertFails(setDoc(staffRef(dave(), 'eve5'), researcher()));
    await assertFails(setDoc(staffRef(alice(), 'eve6'), researcher()));
  });
  test('an admin renames and deactivates a researcher, nothing else', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(staffRef(ctx, 'eve'), researcher()));
    await assertSucceeds(updateDoc(staffRef(frank(), 'eve'), { displayName: 'Eva P.', active: false }));
    await assertFails(updateDoc(staffRef(frank(), 'eve'), { role: 'admin' }));
    await assertFails(updateDoc(staffRef(frank(), 'eve'), { email: 'x@test.cl' }));
    await assertFails(updateDoc(staffRef(dave(), 'eve'), { active: false }));
    await assertFails(deleteDoc(staffRef(frank(), 'eve')));
  });
  test('admins are managed only with admin tooling', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(staffRef(ctx, 'ivan'),
      { role: 'admin', displayName: 'Iván', email: 'ivan@test.cl', active: true, createdAtMs: 1 }));
    await assertFails(updateDoc(staffRef(frank(), 'ivan'), { active: false }));
  });
  test('a deactivated researcher loses access to research data', async () => {
    await assertSucceeds(getDoc(doc(hugo().firestore(), 'staff', 'hugo')));
    await assertFails(getDoc(childRef(hugo())));
    await assertFails(getDoc(sessionRef(hugo())));
    await assertFails(getDocs(collectionGroup(hugo().firestore(), 'sessions')));
    await assertSucceeds(getDoc(childRef(dave())));
  });
});

describe('tutor public cards', () => {
  const cardRef = (ctx, uid) => doc(ctx.firestore(), 'tutors', uid, 'public', 'card');
  const tutorRef = (ctx, uid) => doc(ctx.firestore(), 'tutors', uid);
  const card = (over = {}) => ({ displayName: 'Ana', type: 'family', photoPath: null, ...over });

  test('active tutors and admins get a card; nobody lists them', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(cardRef(ctx, 'carol'), card()));
    await assertSucceeds(getDoc(cardRef(alice(), 'carol')));
    await assertSucceeds(getDoc(cardRef(frank(), 'carol')));
    await assertFails(getDoc(cardRef(dave(), 'carol')));
    await assertFails(getDoc(cardRef(gina(), 'carol')));
    await assertFails(getDoc(cardRef(eve(), 'carol')));
    await assertFails(getDocs(collectionGroup(alice().firestore(), 'public')));
  });
  test('the email never goes on the card', async () => {
    await assertFails(setDoc(cardRef(alice(), 'alice'), card({ email: 'alice@test.cl' })));
  });
  test('a tutor writes their own card, equal to their profile', async () => {
    await assertSucceeds(setDoc(cardRef(alice(), 'alice'), card()));
    await assertFails(setDoc(cardRef(alice(), 'alice'), card({ displayName: 'Otra' })));
    await assertFails(setDoc(cardRef(alice(), 'carol'), card()));
    await assertFails(setDoc(cardRef(gina(), 'gina'), card()));
  });
  test('profile and card change together in one batch', async () => {
    const ctx = alice();
    const b = writeBatch(ctx.firestore());
    b.update(tutorRef(ctx, 'alice'), { displayName: 'Alicia' });
    b.set(cardRef(ctx, 'alice'), card({ displayName: 'Alicia' }));
    await assertSucceeds(b.commit());
  });
  test('an admin writes any tutor card', async () => {
    await assertSucceeds(setDoc(cardRef(frank(), 'carol'), card()));
    await assertFails(setDoc(cardRef(dave(), 'carol'), card()));
  });
  test('co-tutors see the photo; researchers do not', async () => {
    const path = 'tutors/carol/photo-1.jpg';
    await uploadString(ref(carol().storage(), path), 'img', 'raw', { contentType: 'image/jpeg' });
    await assertSucceeds(getBytes(ref(alice().storage(), path)));
    await assertFails(getBytes(ref(dave().storage(), path)));
    await assertFails(getBytes(ref(gina().storage(), path)));
  });
});

describe('session comments', () => {
  test('a session context may carry a short comment', async () => {
    await assertSucceeds(updateDoc(sessionRef(alice()), {
      context: { place: 'home', activity: 'rest', present: [], comment: 'Sensor en la muñeca izquierda' },
    }));
    await assertFails(updateDoc(sessionRef(alice()), {
      context: { comment: 'x'.repeat(501) },
    }));
    await assertFails(updateDoc(sessionRef(alice()), { context: { comment: 42 } }));
  });
});
