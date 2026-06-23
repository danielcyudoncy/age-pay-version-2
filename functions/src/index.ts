import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();
const db = admin.firestore();

const paystackSecretKey = defineSecret('PAYSTACK_SECRET_KEY');
const PAYSTACK_BASE_URL = 'https://api.paystack.co';

/**
 * Firestore trigger: when a new levy is created,
 * auto-generate obligation documents for all active members.
 */
export const createObligationsOnLevy = functions.firestore
  .document('levies/{levyId}')
  .onCreate(async (snap, context) => {
    const levyId = context.params.levyId;
    const levy = snap.data();

    const createdAt = admin.firestore.FieldValue.serverTimestamp();

    // Query all active members
    const membersSnap = await db
      .collection('members')
      .where('isActive', '==', true)
      .get();

    if (membersSnap.empty) {
      console.log(`No active members found for levy ${levyId}`);
      return;
    }

    // Build batch writes for obligations
    const batch = db.batch();

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      const memberData = memberDoc.data();
      const userId = memberData['userId'] || memberId;

      const obligationRef = db.collection('obligations').doc();
      const amount = levy['amountPerMember'] || 0;

      batch.set(obligationRef, {
        memberId: memberId,
        userId: userId,
        levyId: levyId,
        type: levy['type'] || 'specialLevy',
        title: levy['title'] || 'New Levy',
        description: levy['description'] || '',
        amount: amount,
        paidAmount: 0,
        outstandingBalance: amount,
        status: 'unpaid',
        dueDate: levy['dueDate'] || null,
        createdAt: createdAt,
        updatedAt: createdAt,
      });
    }

    await batch.commit();
    console.log(
      `Created ${membersSnap.size} obligations for levy ${levyId}`
    );
  });

/**
 * Callable function: create a levy and immediately generate obligations
 * for all active members atomically via batch.
 */
export const createLevyWithObligations = functions.https.onCall(
  async (data, context) => {
    // Verify request is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }

    const callerUid = context.auth.uid;

    // Verify caller has treasurer or admin role
    const userDoc = await db.collection('users').doc(callerUid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const role = userDoc.data()!['role'];
    if (!['treasurer', 'president', 'superAdmin'].includes(role)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only treasurers, presidents, or admins can create levies'
      );
    }

    const {
      title,
      description,
      type,
      amountPerMember,
      dueDate,
      targetGroup,
    } = data;

    if (!title || !amountPerMember || !dueDate) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: title, amountPerMember, dueDate'
      );
    }

    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    const levyRef = db.collection('levies').doc();

    // Create levy document
    await levyRef.set({
      title,
      description: description || '',
      type: type || 'specialLevy',
      amountPerMember: Number(amountPerMember),
      dueDate: admin.firestore.Timestamp.fromDate(new Date(dueDate)),
      targetGroup: targetGroup || null,
      createdBy: callerUid,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    });

    // Fetch active members
    let memberQuery = db.collection('members').where('isActive', '==', true);
    if (targetGroup) {
      // If targetGroup is specified, filter by it (requires members to have a group field)
      memberQuery = memberQuery.where('group', '==', targetGroup);
    }
    const membersSnap = await memberQuery.get();

    if (membersSnap.empty) {
      console.log(`No active members found for new levy ${levyRef.id}`);
      return { levyId: levyRef.id, obligationsCreated: 0 };
    }

    // Batch create obligations
    const batchSize = 500; // Firestore batch limit
    let batch = db.batch();
    let count = 0;
    let obligationsCreated = 0;

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      const memberData = memberDoc.data();
      const userId = memberData['userId'] || memberId;

      const obligationRef = db.collection('obligations').doc();
      batch.set(obligationRef, {
        memberId: memberId,
        userId: userId,
        levyId: levyRef.id,
        type: type || 'specialLevy',
        title: title,
        description: description || '',
        amount: Number(amountPerMember),
        paidAmount: 0,
        outstandingBalance: Number(amountPerMember),
        status: 'unpaid',
        dueDate: admin.firestore.Timestamp.fromDate(new Date(dueDate)),
        createdAt: timestamp,
        updatedAt: timestamp,
      });

      count++;
      obligationsCreated++;

      if (count === batchSize) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    console.log(
      `Created levy ${levyRef.id} with ${obligationsCreated} obligations`
    );
    return { levyId: levyRef.id, obligationsCreated };
  }
);

/**
 * Callable function: initialize a Paystack transaction.
 * Returns an authorization_url for the client to open in a webview.
 */
export const initializePaystackPayment = functions
  .runWith({ secrets: ['PAYSTACK_SECRET_KEY'] })
  .https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { email, amountNaira, reference, metadata } = data;
    if (!email || !amountNaira || !reference) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: email, amountNaira, reference'
      );
    }

    const secretKey = process.env.PAYSTACK_SECRET_KEY || '';
    if (!secretKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Paystack secret key not configured'
      );
    }

    try {
      const response = await fetch(`${PAYSTACK_BASE_URL}/transaction/initialize`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${secretKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          amount: Math.round(amountNaira * 100), // Paystack uses kobo
          reference,
          metadata: metadata || {},
          callback_url: metadata?.callbackUrl || undefined,
        }),
      });

      const result = (await response.json()) as any;

      if (!result.status) {
        throw new Error(result.message || 'Paystack initialization failed');
      }

      return {
        authorizationUrl: result.data.authorization_url,
        accessCode: result.data.access_code,
        reference: result.data.reference,
      };
    } catch (error: any) {
      console.error('Paystack initialize error:', error);
      throw new functions.https.HttpsError(
        'internal',
        error.message || 'Payment initialization failed'
      );
    }
  }
);

/**
 * Callable function: verify a Paystack transaction and record the payment.
 * Creates a Payment document, updates obligations, generates receipt.
 */
export const verifyPaystackTransaction = functions
  .runWith({ secrets: ['PAYSTACK_SECRET_KEY'] })
  .https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { reference, memberId, obligationIds, amountPaid } = data;
    if (!reference || !memberId || !obligationIds || !amountPaid) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: reference, memberId, obligationIds, amountPaid'
      );
    }

    const secretKey = process.env.PAYSTACK_SECRET_KEY || '';
    if (!secretKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Paystack secret key not configured'
      );
    }

    try {
      // Verify with Paystack
      const response = await fetch(
        `${PAYSTACK_BASE_URL}/transaction/verify/${reference}`,
        {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${secretKey}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const result = (await response.json()) as any;

      if (!result.status || result.data.status !== 'success') {
        throw new Error(
          result.data?.gateway_response || 'Transaction verification failed'
        );
      }

      const verifiedAmount = result.data.amount / 100; // kobo to naira
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      const now = admin.firestore.Timestamp.now();

      // Build allocations
      const allocations = (obligationIds as string[]).map((id: string) => ({
        obligationId: id,
        amount: Number(verifiedAmount) / (obligationIds as string[]).length, // simple split for now
      }));

      // Create payment document
      const paymentRef = db.collection('payments').doc();
      await paymentRef.set({
        memberId,
        amount: verifiedAmount,
        method: 'online',
        status: 'approved',
        allocations,
        paystackReference: reference,
        paystackResponse: result.data,
        verifiedBy: 'system',
        verifiedAt: now,
        createdAt: now,
      });

      // Update obligations
      const batch = db.batch();
      for (const alloc of allocations) {
        const obligationRef = db.collection('obligations').doc(alloc.obligationId);
        const obligationSnap = await obligationRef.get();
        if (!obligationSnap.exists) continue;

        const obligationData = obligationSnap.data()!;
        const currentPaid = (obligationData['paidAmount'] as number) || 0;
        const totalAmount = (obligationData['amount'] as number) || 0;
        const newPaid = currentPaid + alloc.amount;
        const newOutstanding = Math.max(0, totalAmount - newPaid);
        const newStatus = newOutstanding <= 0.01 ? 'paid' : newPaid > 0 ? 'partial' : 'unpaid';

        batch.update(obligationRef, {
          paidAmount: newPaid,
          outstandingBalance: newOutstanding,
          status: newStatus,
          settledAt: newStatus === 'paid' ? now : obligationData['settledAt'] || null,
          updatedAt: now,
        });
      }
      await batch.commit();

      // Generate receipt
      const receiptRef = db.collection('receipts').doc();
      const receiptNumber = `RCP-${Date.now()}`;
      await receiptRef.set({
        paymentId: paymentRef.id,
        memberId,
        receiptNumber,
        amount: verifiedAmount,
        method: 'online',
        paystackReference: reference,
        createdAt: now,
        paidAt: now,
      });

      return {
        paymentId: paymentRef.id,
        receiptId: receiptRef.id,
        receiptNumber,
        verifiedAmount,
        status: 'approved',
      };
    } catch (error: any) {
      console.error('Paystack verify error:', error);
      throw new functions.https.HttpsError(
        'internal',
        error.message || 'Transaction verification failed'
      );
    }
  }
);

/**
 * Callable function: record a cash payment.
 * Creates an APPROVED payment, updates obligations via batch, generates receipt.
 */
export const recordCashPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const callerUid = context.auth.uid;

    // Verify caller has treasurer or admin role
    const userDoc = await db.collection('users').doc(callerUid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const role = userDoc.data()!['role'];
    if (!['treasurer', 'president', 'superAdmin'].includes(role)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only treasurers, presidents, or admins can record cash payments'
      );
    }

    const { memberId, obligationIds, amount, notes, recordedBy } = data;
    if (!memberId || !obligationIds || !amount || !recordedBy) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: memberId, obligationIds, amount, recordedBy'
      );
    }

    const now = admin.firestore.Timestamp.now();

    // Build allocations
    const allocations = (obligationIds as string[]).map((id: string) => ({
      obligationId: id,
      amount: Number(amount) / (obligationIds as string[]).length,
    }));

    // Create payment document
    const paymentRef = db.collection('payments').doc();
    await paymentRef.set({
      memberId,
      amount: Number(amount),
      method: 'cash',
      status: 'approved',
      allocations,
      notes: notes || '',
      recordedBy,
      verifiedBy: recordedBy,
      verifiedAt: now,
      createdAt: now,
    });

    // Update obligations
    const batch = db.batch();
    for (const alloc of allocations) {
      const obligationRef = db.collection('obligations').doc(alloc.obligationId);
      const obligationSnap = await obligationRef.get();
      if (!obligationSnap.exists) continue;

      const obligationData = obligationSnap.data()!;
      const currentPaid = (obligationData['paidAmount'] as number) || 0;
      const totalAmount = (obligationData['amount'] as number) || 0;
      const newPaid = currentPaid + alloc.amount;
      const newOutstanding = Math.max(0, totalAmount - newPaid);
      const newStatus = newOutstanding <= 0.01 ? 'paid' : newPaid > 0 ? 'partial' : 'unpaid';

      batch.update(obligationRef, {
        paidAmount: newPaid,
        outstandingBalance: newOutstanding,
        status: newStatus,
        settledAt: newStatus === 'paid' ? now : obligationData['settledAt'] || null,
        updatedAt: now,
      });
    }
    await batch.commit();

    // Generate receipt
    const receiptRef = db.collection('receipts').doc();
    const receiptNumber = `RCP-${Date.now()}`;
    await receiptRef.set({
      paymentId: paymentRef.id,
      memberId,
      receiptNumber,
      amount: Number(amount),
      method: 'cash',
      paymentDate: now,
      allocatedObligations: allocations.map((a) => ({
        obligationId: a.obligationId,
        amount: a.amount,
      })),
      createdAt: now,
    });

    return {
      paymentId: paymentRef.id,
      receiptId: receiptRef.id,
      receiptNumber,
    };
  }
);

/**
 * Callable function: submit a bank transfer for verification.
 * Creates a PENDING payment with transfer details and receipt URL.
 */
export const submitBankTransfer = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { memberId, obligationIds, amount, transferReference, bankName, receiptUrl, notes } = data;
    if (!memberId || !obligationIds || !amount || !transferReference || !bankName || !receiptUrl) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: memberId, obligationIds, amount, transferReference, bankName, receiptUrl'
      );
    }

    const now = admin.firestore.Timestamp.now();

    // Build allocations
    const allocations = (obligationIds as string[]).map((id: string) => ({
      obligationId: id,
      amount: Number(amount) / (obligationIds as string[]).length,
    }));

    // Create payment document
    const paymentRef = db.collection('payments').doc();
    await paymentRef.set({
      memberId,
      amount: Number(amount),
      method: 'bankTransfer',
      status: 'pending',
      allocations,
      transferReference,
      bankName,
      transferProofUrl: receiptUrl,
      notes: notes || '',
      createdAt: now,
    });

    return {
      paymentId: paymentRef.id,
    };
  }
);

/**
 * Callable function: verify (approve or reject) a pending payment.
 * On approve: updates payment status, updates obligations, generates receipt.
 * On reject: updates status to rejected.
 */
export const verifyPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const callerUid = context.auth.uid;

    // Verify caller has treasurer or admin role
    const userDoc = await db.collection('users').doc(callerUid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const role = userDoc.data()!['role'];
    if (!['treasurer', 'president', 'superAdmin'].includes(role)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only treasurers, presidents, or admins can verify payments'
      );
    }

    const { paymentId, action, verifiedBy, notes } = data;
    if (!paymentId || !action || !verifiedBy) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: paymentId, action, verifiedBy'
      );
    }

    if (!['approve', 'reject'].includes(action)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'action must be either "approve" or "reject"'
      );
    }

    const now = admin.firestore.Timestamp.now();

    // Fetch payment
    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }

    const paymentData = paymentSnap.data()!;

    if (action === 'reject') {
      await paymentRef.update({
        status: 'rejected',
        verifiedBy,
        verifiedAt: now,
        notes: notes || paymentData['notes'] || '',
        updatedAt: now,
      });

      return {
        success: true,
        paymentId,
      };
    }

    // Approve path
    const allocations = paymentData['allocations'] || [];

    // Update obligations
    const batch = db.batch();
    for (const alloc of allocations) {
      const obligationRef = db.collection('obligations').doc(alloc.obligationId);
      const obligationSnap = await obligationRef.get();
      if (!obligationSnap.exists) continue;

      const obligationData = obligationSnap.data()!;
      const currentPaid = (obligationData['paidAmount'] as number) || 0;
      const totalAmount = (obligationData['amount'] as number) || 0;
      const allocAmount = (alloc.amount as number) || 0;
      const newPaid = currentPaid + allocAmount;
      const newOutstanding = Math.max(0, totalAmount - newPaid);
      const newStatus = newOutstanding <= 0.01 ? 'paid' : newPaid > 0 ? 'partial' : 'unpaid';

      batch.update(obligationRef, {
        paidAmount: newPaid,
        outstandingBalance: newOutstanding,
        status: newStatus,
        settledAt: newStatus === 'paid' ? now : obligationData['settledAt'] || null,
        updatedAt: now,
      });
    }
    await batch.commit();

    // Update payment status
    await paymentRef.update({
      status: 'approved',
      verifiedBy,
      verifiedAt: now,
      notes: notes || paymentData['notes'] || '',
      updatedAt: now,
    });

    // Generate receipt
    const receiptRef = db.collection('receipts').doc();
    const receiptNumber = `RCP-${Date.now()}`;
    await receiptRef.set({
      paymentId,
      memberId: paymentData['memberId'],
      receiptNumber,
      amount: Number(paymentData['amount']),
      method: paymentData['method'] || 'bankTransfer',
      paymentDate: now,
      allocatedObligations: allocations.map((a: any) => ({
        obligationId: a.obligationId,
        amount: a.amount,
      })),
      createdAt: now,
    });

    return {
      success: true,
      paymentId,
      receiptId: receiptRef.id,
    };
  }
);
