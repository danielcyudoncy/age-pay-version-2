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
