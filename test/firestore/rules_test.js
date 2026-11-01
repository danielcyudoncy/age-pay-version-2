const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = 'age-grade-finance-test';
const RULES_PATH = resolve(__dirname, '../../firestore.rules');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function getFirestore(auth) {
  return testEnv.authenticatedContext(auth.uid, auth.token || {}).firestore();
}

function getUnauthenticatedFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

// ─── Users collection ────────────────────────────────────────────────────
describe('Users collection', () => {
  const userId = 'user1';

  it('allows owner to read their own user doc', async () => {
    const db = getFirestore({ uid: userId });
    const ref = db.collection('users').doc(userId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(userId).set({
        role: 'member',
        email: 'user1@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('denies unauthenticated reads', async () => {
    const db = getUnauthenticatedFirestore();
    const ref = db.collection('users').doc(userId);
    await assertFails(ref.get());
  });

  it('allows treasurer to read any user doc', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('users').doc(userId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('users').doc(userId).set({
        role: 'member',
        email: 'user1@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('denies member from reading another user doc', async () => {
    const db = getFirestore({ uid: 'member2' });
    const ref = db.collection('users').doc(userId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('member2').set({
        role: 'member',
        email: 'member2@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('users').doc(userId).set({
        role: 'member',
        email: 'user1@test.com',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.get());
  });
});

// ─── Members collection ──────────────────────────────────────────────────
describe('Members collection', () => {
  const userId = 'user1';
  const memberId = 'member1';

  it('allows member to read their own member doc', async () => {
    const db = getFirestore({ uid: userId });
    const ref = db.collection('members').doc(memberId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(userId).set({
        role: 'member',
        email: 'user1@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('members').doc(memberId).set({
        userId: userId,
        fullName: 'John Doe',
        email: 'user1@test.com',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('allows treasurer to create member docs', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('members').doc('newMember');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.set({
      userId: 'newUser',
      fullName: 'New Member',
      email: 'new@test.com',
      phoneNumber: '+1234567890',
      dateOfBirth: new Date(),
      joinedDate: new Date(),
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
  });

  it('denies member from creating member docs for others', async () => {
    const db = getFirestore({ uid: 'member1' });
    const ref = db.collection('members').doc('newMember');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('member1').set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.set({
      userId: 'otherUser',
      fullName: 'Other',
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
  });
});

// ─── Obligations collection ──────────────────────────────────────────────
describe('Obligations collection', () => {
  const memberId = 'member1';

  it('allows member to read their own obligations', async () => {
    const db = getFirestore({ uid: memberId });
    const ref = db.collection('obligations').doc('obl1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(memberId).set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('obligations').doc('obl1').set({
        memberId: memberId,
        levyId: 'levy1',
        type: 'monthlyDue',
        title: 'June Due',
        description: 'Monthly due',
        amount: 100,
        paidAmount: 0,
        outstandingBalance: 100,
        status: 'unpaid',
        dueDate: new Date(),
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('allows treasurer to create obligations', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('obligations').doc('newObl');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.set({
      memberId: memberId,
      levyId: 'levy1',
      type: 'monthlyDue',
      title: 'July Due',
      description: 'Monthly due',
      amount: 100,
      paidAmount: 0,
      outstandingBalance: 100,
      status: 'unpaid',
      dueDate: new Date(),
      createdAt: new Date(),
    }));
  });
});

// ─── Payments collection ─────────────────────────────────────────────────
describe('Payments collection', () => {
  const memberId = 'member1';

  it('allows member to create their own payment', async () => {
    const db = getFirestore({ uid: memberId });
    const ref = db.collection('payments').doc('pay1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(memberId).set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.set({
      memberId: memberId,
      amount: 100,
      method: 'cash',
      status: 'pending',
      allocations: [],
      createdAt: new Date(),
    }));
  });

  it('denies member from creating payment for another member', async () => {
    const db = getFirestore({ uid: 'member1' });
    const ref = db.collection('payments').doc('pay1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('member1').set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.set({
      memberId: 'otherMember',
      amount: 100,
      method: 'cash',
      status: 'pending',
      allocations: [],
      createdAt: new Date(),
    }));
  });

  it('allows treasurer to read all payments', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('payments').doc('pay1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('payments').doc('pay1').set({
        memberId: 'member1',
        amount: 100,
        method: 'cash',
        status: 'pending',
        allocations: [],
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });
});

// ─── Expenses collection ─────────────────────────────────────────────────
describe('Expenses collection', () => {
  it('allows treasurer to create expenses', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('expenses').doc('exp1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.set({
      title: 'Office Supplies',
      description: 'Printer paper',
      amount: 50,
      category: 'administration',
      createdBy: 'treasurer1',
      expenseDate: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
  });

  it('denies member from reading expenses', async () => {
    const db = getFirestore({ uid: 'member1' });
    const ref = db.collection('expenses').doc('exp1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('member1').set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('expenses').doc('exp1').set({
        title: 'Office Supplies',
        amount: 50,
        category: 'administration',
        createdBy: 'treasurer1',
        expenseDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    await assertFails(ref.get());
  });
});

// ─── Levies collection ───────────────────────────────────────────────────
describe('Levies collection', () => {
  it('allows any authenticated user to read levies', async () => {
    const db = getFirestore({ uid: 'member1' });
    const ref = db.collection('levies').doc('levy1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('member1').set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('levies').doc('levy1').set({
        title: 'Building Fund',
        description: 'Community hall',
        type: 'projectContribution',
        amountPerMember: 1000,
        dueDate: new Date(),
        createdBy: 'treasurer1',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('denies unauthenticated reads', async () => {
    const db = getUnauthenticatedFirestore();
    const ref = db.collection('levies').doc('levy1');
    await assertFails(ref.get());
  });
});

// ─── Receipts collection ─────────────────────────────────────────────────
describe('Receipts collection', () => {
  const memberId = 'member1';

  it('allows member to read their own receipts', async () => {
    const db = getFirestore({ uid: memberId });
    const ref = db.collection('receipts').doc('rcp1');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(memberId).set({
        role: 'member',
        email: 'member1@test.com',
        createdAt: new Date(),
      });
      await context.firestore().collection('receipts').doc('rcp1').set({
        receiptNumber: 'RCP-001',
        paymentId: 'pay1',
        memberId: memberId,
        memberName: 'John Doe',
        amount: 150,
        method: 'cash',
        paymentDate: new Date(),
        allocatedObligations: [],
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('allows treasurer to create receipts', async () => {
    const db = getFirestore({ uid: 'treasurer1' });
    const ref = db.collection('receipts').doc('newRcp');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('treasurer1').set({
        role: 'treasurer',
        email: 'treasurer@test.com',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.set({
      receiptNumber: 'RCP-002',
      paymentId: 'pay2',
      memberId: memberId,
      memberName: 'John Doe',
      amount: 200,
      method: 'bankTransfer',
      paymentDate: new Date(),
      allocatedObligations: [],
      createdAt: new Date(),
    }));
  });
});

// ─── Calls collection ────────────────────────────────────────────────────
describe('Calls collection', () => {
  const callerId = 'caller1';
  const receiverId = 'receiver1';
  const callId = 'call123';

  it('allows receiver or caller to read calls', async () => {
    const db = getFirestore({ uid: receiverId });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'calling',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());

    const callerDb = getFirestore({ uid: callerId });
    await assertSucceeds(callerDb.collection('calls').doc(callId).get());
  });

  it('denies third-party user from reading call of others', async () => {
    const db = getFirestore({ uid: 'stranger' });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'calling',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.get());
  });

  it('allows superAdmin to read any call', async () => {
    const db = getFirestore({ uid: 'superadmin1', token: { email: 'danielcyudoncy@gmail.com' } });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'calling',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.get());
  });

  it('denies unauthenticated read', async () => {
    const db = getUnauthenticatedFirestore();
    const ref = db.collection('calls').doc(callId);
    await assertFails(ref.get());
  });

  it('allows caller to create a call session with their callerId', async () => {
    const db = getFirestore({ uid: callerId });
    const ref = db.collection('calls').doc('newCall');
    await assertSucceeds(ref.set({
      id: 'newCall',
      organizationId: 'org1',
      callerId: callerId,
      callerName: 'Caller User',
      callerRole: 'member',
      receiverId: receiverId,
      receiverName: 'Receiver User',
      status: 'calling',
      callType: 'audio',
      createdAt: new Date(),
    }));
  });

  it('denies user from creating call with another user callerId', async () => {
    const db = getFirestore({ uid: 'impostor' });
    const ref = db.collection('calls').doc('spoofedCall');
    await assertFails(ref.set({
      id: 'spoofedCall',
      organizationId: 'org1',
      callerId: callerId,
      receiverId: receiverId,
      status: 'calling',
      callType: 'audio',
      createdAt: new Date(),
    }));
  });

  it('allows receiver to update call status', async () => {
    const db = getFirestore({ uid: receiverId });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'calling',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.update({
      status: 'active',
      updatedAt: new Date(),
    }));
  });

  it('allows caller to update call status (e.g. end call)', async () => {
    const db = getFirestore({ uid: callerId });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'active',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.update({
      status: 'ended',
      endedAt: new Date(),
    }));
  });

  it('denies third-party non-admin user from updating call', async () => {
    const db = getFirestore({ uid: 'stranger' });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'calling',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.update({
      status: 'rejected',
    }));
  });

  it('denies non-superAdmin from deleting calls', async () => {
    const db = getFirestore({ uid: callerId });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'ended',
        createdAt: new Date(),
      });
    });
    await assertFails(ref.delete());
  });

  it('allows superAdmin to delete calls', async () => {
    const db = getFirestore({ uid: 'superadmin1', token: { email: 'danielcyudoncy@gmail.com' } });
    const ref = db.collection('calls').doc(callId);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('calls').doc(callId).set({
        id: callId,
        organizationId: 'org1',
        callerId: callerId,
        receiverId: receiverId,
        status: 'ended',
        createdAt: new Date(),
      });
    });
    await assertSucceeds(ref.delete());
  });
});

// ─── Announcements collection ────────────────────────────────────────────
describe('Announcements collection', () => {
  const orgId = 'org1';
  const announcementId = 'announcement1';

  async function seedUser(uid, role, nationalRole = null) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const data = {
        role: role,
        email: `${uid}@test.com`,
        createdAt: new Date(),
      };
      if (nationalRole) {
        data.nationalRole = nationalRole;
      }
      await context.firestore().collection('users').doc(uid).set(data);
    });
  }

  it('allows PRO, Secretary, President, and SuperAdmin to create, update, and delete announcements', async () => {
    const rolesToTest = [
      { uid: 'pro1', role: 'publicRelationsOfficer' },
      { uid: 'sec1', role: 'secretary' },
      { uid: 'pres1', role: 'president' },
      { uid: 'admin1', role: 'superAdmin' },
      { uid: 'nationalPro', role: 'member', nationalRole: 'publicRelationsOfficer' },
    ];

    for (const testUser of rolesToTest) {
      await seedUser(testUser.uid, testUser.role, testUser.nationalRole);
      const db = getFirestore({ uid: testUser.uid });
      const docId = `ann_${testUser.uid}`;
      const ref = db.collection('announcements').doc(docId);

      // Create
      await assertSucceeds(ref.set({
        organizationId: orgId,
        title: 'Meeting Notice',
        body: 'Important update',
        category: 'general',
        createdBy: testUser.uid,
        targetAudience: 'all',
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      // Update
      await assertSucceeds(ref.update({
        title: 'Updated Meeting Notice',
        updatedAt: new Date(),
      }));

      // Delete
      await assertSucceeds(ref.delete());
    }
  });

  it('denies regular member from creating, updating, or deleting announcements', async () => {
    const memberUid = 'regularMember';
    await seedUser(memberUid, 'member');
    const db = getFirestore({ uid: memberUid });
    const ref = db.collection('announcements').doc(announcementId);

    // Create should fail
    await assertFails(ref.set({
      organizationId: orgId,
      title: 'Unauthorized announcement',
      body: 'Should not succeed',
      category: 'general',
      createdBy: memberUid,
      targetAudience: 'all',
      createdAt: new Date(),
      updatedAt: new Date(),
    }));

    // Seed existing announcement
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('announcements').doc(announcementId).set({
        organizationId: orgId,
        title: 'Official announcement',
        body: 'Valid notice',
        category: 'general',
        createdBy: 'sec1',
        targetAudience: 'all',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    // Update should fail
    await assertFails(ref.update({
      title: 'Hacked title',
    }));

    // Delete should fail
    await assertFails(ref.delete());
  });
});

// ─── Notifications collection ────────────────────────────────────────────
describe('Notifications collection', () => {
  const orgId = 'org1';

  async function seedUser(uid, role, nationalRole = null) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const data = {
        role: role,
        email: `${uid}@test.com`,
        createdAt: new Date(),
      };
      if (nationalRole) {
        data.nationalRole = nationalRole;
      }
      await context.firestore().collection('users').doc(uid).set(data);
    });
  }

  async function seedNotification(id, data) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('notifications').doc(id).set({
        organizationId: orgId,
        title: 'Test Notification',
        body: 'Test Body',
        type: 'general',
        read: false,
        receivedAt: new Date(),
        ...data,
      });
    });
  }

  it('allows authenticated user to delete a notification targeted to them (targetUserId == request.auth.uid)', async () => {
    const userId = 'user1';
    await seedUser(userId, 'member');
    await seedNotification('notif_own', { targetUserId: userId });

    const db = getFirestore({ uid: userId });
    const ref = db.collection('notifications').doc('notif_own');

    await assertSucceeds(ref.delete());
  });

  it('denies authenticated user from deleting a notification targeted to another user unless admin/treasurer/superAdmin', async () => {
    const userId = 'user1';
    const otherUserId = 'otherUser';
    await seedUser(userId, 'member');
    await seedUser(otherUserId, 'member');
    await seedNotification('notif_other', { targetUserId: otherUserId });

    // Regular authenticated user cannot delete another user's notification
    const db = getFirestore({ uid: userId });
    const ref = db.collection('notifications').doc('notif_other');
    await assertFails(ref.delete());

    // Unauthenticated user cannot delete
    const unauthDb = getUnauthenticatedFirestore();
    const unauthRef = unauthDb.collection('notifications').doc('notif_other');
    await assertFails(unauthRef.delete());
  });

  it('allows Admin, Treasurer, or SuperAdmin to delete any notification', async () => {
    const privilegedRoles = [
      { uid: 'treasurerUser', role: 'treasurer' },
      { uid: 'presidentUser', role: 'president' },
      { uid: 'adminUser', role: 'superAdmin' },
    ];

    for (const pUser of privilegedRoles) {
      await seedUser(pUser.uid, pUser.role);
      const docId = `notif_for_${pUser.uid}`;
      await seedNotification(docId, { targetUserId: 'otherUser' });

      const db = getFirestore({ uid: pUser.uid });
      const ref = db.collection('notifications').doc(docId);
      await assertSucceeds(ref.delete());
    }

    // SuperAdmin via bootstrap email can also delete any notification
    const bootstrapUid = 'bootstrapAdmin';
    const bootstrapDocId = 'notif_for_bootstrap';
    await seedNotification(bootstrapDocId, { targetUserId: 'otherUser' });

    const bootstrapDb = getFirestore({
      uid: bootstrapUid,
      token: { email: 'danielcyudoncy@gmail.com' },
    });
    const bootstrapRef = bootstrapDb.collection('notifications').doc(bootstrapDocId);
    await assertSucceeds(bootstrapRef.delete());

    // Privileged users can also delete notifications without a targetUserId (broadcast notifications)
    const broadcastDocId = 'notif_broadcast';
    await seedNotification(broadcastDocId, { targetRole: 'all' });
    const adminDb = getFirestore({ uid: 'adminUser' });
    const broadcastRef = adminDb.collection('notifications').doc(broadcastDocId);
    await assertSucceeds(broadcastRef.delete());
  });
});
