import * as functions from 'firebase-functions';
/**
 * Firestore trigger: when a new levy is created,
 * auto-generate obligation documents for all active members.
 */
export declare const createObligationsOnLevy: functions.CloudFunction<functions.firestore.QueryDocumentSnapshot>;
/**
 * Callable function: create a levy and immediately generate obligations
 * for all active members atomically via batch.
 */
export declare const createLevyWithObligations: functions.HttpsFunction & functions.Runnable<any>;
/**
 * Callable function: initialize a Paystack transaction.
 * Returns an authorization_url for the client to open in a webview.
 */
export declare const initializePaystackPayment: functions.HttpsFunction & functions.Runnable<any>;
/**
 * Callable function: verify a Paystack transaction and record the payment.
 * Creates a Payment document, updates obligations, generates receipt.
 */
export declare const verifyPaystackTransaction: functions.HttpsFunction & functions.Runnable<any>;
/**
 * Callable function: record a cash payment.
 * Creates an APPROVED payment, updates obligations via batch, generates receipt.
 */
export declare const recordCashPayment: functions.HttpsFunction & functions.Runnable<any>;
/**
 * Callable function: submit a bank transfer for verification.
 * Creates a PENDING payment with transfer details and receipt URL.
 */
export declare const submitBankTransfer: functions.HttpsFunction & functions.Runnable<any>;
/**
 * Callable function: verify (approve or reject) a pending payment.
 * On approve: updates payment status, updates obligations, generates receipt.
 * On reject: updates status to rejected.
 */
export declare const verifyPayment: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=index.d.ts.map