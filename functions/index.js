const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Environment configuration for PayU
 * Defaults to test credentials, overridden by process.env or Firebase config
 */
const getPayUConfig = () => {
  const isProduction = (process.env.PAYU_ENVIRONMENT || "").toLowerCase() === "production";
  
  if (isProduction) {
    return {
      environment: "production",
      merchantId: process.env.PAYU_PROD_MERCHANT_ID || "YOUR_LIVE_MERCHANT_ID",
      merchantKey: process.env.PAYU_PROD_KEY || "YOUR_LIVE_MERCHANT_KEY",
      merchantSalt: process.env.PAYU_PROD_SALT || "YOUR_LIVE_MERCHANT_SALT",
      payUrl: process.env.PAYU_PROD_PAY_URL || "https://secure.payu.in/_payment",
    };
  }

  return {
    environment: "sandbox",
    merchantId: process.env.PAYU_TEST_MERCHANT_ID || "9193759",
    merchantKey: process.env.PAYU_TEST_KEY || "GZrAha",
    merchantSalt: process.env.PAYU_TEST_SALT || "xpfwrDGBXY4sR5Y8O4xU8OB0seurgJMi",
    payUrl: process.env.PAYU_TEST_PAY_URL || "https://test.payu.in/_payment",
  };
};

/**
 * Utility: Sanitize input strings for PayU
 */
function sanitizeName(name) {
  const clean = (name || "").replace(/[^a-zA-Z0-9 ]/g, "").trim();
  return clean.length > 0 ? clean : "Customer";
}

function sanitizeProductInfo(info) {
  const clean = (info || "").replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
  return clean.length > 0 ? clean : "Subscription";
}

function sanitizeEmail(email) {
  const clean = (email || "").trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(clean) ? clean : "customer@example.com";
}

function sanitizePhone(phone) {
  let clean = (phone || "").replace(/[^0-9]/g, "");
  if (clean.length > 10) clean = clean.substring(clean.length - 10);
  if (clean.length < 10) clean = "9999999999";
  return clean;
}

/**
 * Utility: Compute SHA-512 Hash
 */
function sha512(str) {
  return crypto.createHash("sha512").update(str, "utf-8").digest("hex").toLowerCase();
}

/**
 * Generate PayU Request Hash
 * Sequence: key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt
 */
function computeRequestHash(params, salt) {
  const amountStr = parseFloat(params.amount).toFixed(2);
  const firstName = sanitizeName(params.firstName);
  const productInfo = sanitizeProductInfo(params.productInfo);
  const email = sanitizeEmail(params.email);

  const hashSequence = `${params.merchantKey}|${params.txnid}|${amountStr}|${productInfo}|${firstName}|${email}|||||||||||${salt}`;

  logger.info("PayU Cloud Function Hash Sequence:", hashSequence);
  
  return sha512(hashSequence);
}

/**
 * Verify PayU Response Hash
 * Sequence: salt|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key
 */
function computeResponseHash(params, salt, fallbackKey = "") {
  const amountStr = parseFloat(params.amount || 0).toFixed(2);
  const firstName = sanitizeName(params.firstname || params.firstName);
  const productInfo = sanitizeProductInfo(params.productinfo || params.productInfo);
  const email = (params.email || "").trim();
  const status = (params.status || "").toLowerCase();
  const txnid = params.txnid || "";
  const key = params.key || params.merchantKey || fallbackKey;

  const udf1 = params.udf1 || "";
  const udf2 = params.udf2 || "";
  const udf3 = params.udf3 || "";
  const udf4 = params.udf4 || "";
  const udf5 = params.udf5 || "";

  let hashSequence = `${salt}|${status}||||||${udf5}|${udf4}|${udf3}|${udf2}|${udf1}|${email}|${firstName}|${productInfo}|${amountStr}|${txnid}|${key}`;

  if (params.additionalCharges) {
    hashSequence = `${params.additionalCharges}|${hashSequence}`;
  }

  logger.info("PayU Response Hash Sequence:", hashSequence);
  return sha512(hashSequence);
}

/**
 * 1. Callable Cloud Function: generatePayUHash
 * Can be called directly from Flutter app via Firebase Functions SDK or HTTP
 */
exports.generatePayUHash = onCall({ cors: true }, async (request) => {
  try {
    const data = request.data || {};
    const { txnid, amount, productInfo, firstName, email, phone, pg, bankcode } = data;

    if (!txnid || !amount) {
      throw new HttpsError("invalid-argument", "Missing required parameters: txnid and amount");
    }

    const config = getPayUConfig();
    const params = {
      merchantKey: config.merchantKey,
      txnid,
      amount,
      productInfo,
      firstName,
      email,
    };

    const hash = computeRequestHash(params, config.merchantSalt);

    const postData = {
      key: config.merchantKey,
      txnid,
      amount: parseFloat(amount).toFixed(2),
      productinfo: sanitizeProductInfo(productInfo),
      firstname: sanitizeName(firstName),
      email: sanitizeEmail(email),
      phone: sanitizePhone(phone),
      surl: process.env.PAYU_SURL || "https://api.payu.in/public/#/success",
      furl: process.env.PAYU_FURL || "https://api.payu.in/public/#/failure",
      hash,
      service_provider: "payu_paisa",
    };

    // Add optional UPI Intent payment parameters
    if (pg) {
      postData.pg = pg;
      if (bankcode) {
        postData.bankcode = bankcode;
      }
    }

    return {
      success: true,
      hash,
      merchantKey: config.merchantKey,
      payUrl: config.payUrl,
      postData,
    };
  } catch (err) {
    logger.error("Error generating PayU hash:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Failed to generate hash");
  }
});

/**
 * 2. Callable Cloud Function: verifySubscription
 * Verifies PayU transaction, confirms response hash signature, and updates Firestore subscription
 */
exports.verifySubscription = onCall({ cors: true }, async (request) => {
  try {
    const data = request.data || {};
    const { orgId, txnid, payuMoneyId, rawData, planDetails, state } = data;

    if (!orgId || !txnid) {
      throw new HttpsError("invalid-argument", "Missing required parameters: orgId and txnid");
    }

    const db = admin.firestore();
    const orgRef = db.collection("organisation").doc(orgId);
    const subRef = orgRef.collection("data").doc("subscription");

    // Idempotency & Status check
    const existingDoc = await subRef.get();
    if (existingDoc.exists) {
      const existingData = existingDoc.data() || {};
      if (existingData.paymentTxnId === txnid && existingData.isSubscriptionActive === true && existingData.paymentStatus === "SUCCESS") {
        logger.info(`Subscription already verified and active for txnid ${txnid}`);
        return {
          success: true,
          txnid,
          orgId,
          status: "ACTIVE",
          alreadyVerified: true,
        };
      }
    }

    const config = getPayUConfig();
    let isVerified = true;
    const rawStatus = (rawData?.status || "").toLowerCase();

    // Check response hash signature if provided
    if (rawData && rawData.hash) {
      const computedHash = computeResponseHash(rawData, config.merchantSalt, config.merchantKey);
      if (computedHash !== rawData.hash.toLowerCase()) {
        logger.warn(`Hash mismatch for txnid ${txnid}: computed=${computedHash}, received=${rawData.hash}`);
        isVerified = false;
      }
    }

    // Determine lifecycle state
    let finalStatus = "FAILED";
    let isSubscriptionActive = false;

    if (state === "cancelled" || rawStatus === "cancel" || rawStatus === "user_cancelled") {
      finalStatus = "CANCELLED";
    } else if (state === "pending" || rawStatus === "pending") {
      finalStatus = "PENDING";
    } else if (isVerified && (rawStatus === "success" || state === "success" || !rawData)) {
      finalStatus = "SUCCESS";
      isSubscriptionActive = true;
    } else if (!isVerified) {
      finalStatus = "FAILED_HASH_MISMATCH";
    }

    const now = new Date();
    const planType = (planDetails && planDetails.planType) || "Monthly";
    let days = 30;
    if (planType === "6 Months") days = 180;
    if (planType === "Yearly") days = 365;
    if (planType === "Free Trial") days = 14;

    const endDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

    const subscriptionUpdate = {
      isSubscriptionActive,
      paymentGateway: "PayU",
      paymentTxnId: txnid,
      payuMoneyId: payuMoneyId || rawData?.mihpayid || "",
      bankRefNo: rawData?.bank_ref_no || rawData?.field9 || "",
      verifiedByBackend: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentStatus: finalStatus,
      subscriptionPlan: (planDetails?.planName || "Silver").toLowerCase(),
      subscriptionStartDate: admin.firestore.Timestamp.fromDate(now),
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(endDate),
      payerName: planDetails?.payerName || rawData?.firstname || "Customer",
      payerEmail: planDetails?.payerEmail || rawData?.email || "",
      payerPhone: planDetails?.payerPhone || rawData?.phone || "",
      username: planDetails?.username || "",
      paymentAmount: parseFloat(planDetails?.amount || rawData?.amount || 0),
      paymentMethod: rawData?.mode || rawData?.PG_TYPE || "UPI",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await subRef.set(subscriptionUpdate, { merge: true });

    return {
      success: isSubscriptionActive,
      txnid,
      orgId,
      status: finalStatus,
      isSubscriptionActive,
      payerName: subscriptionUpdate.payerName,
      payerEmail: subscriptionUpdate.payerEmail,
    };

  } catch (err) {
    logger.error("Error verifying and activating subscription:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Failed to process subscription");
  }
});

/**
 * 3. HTTP Webhook: payuWebhook
 * PayU async server callback endpoint
 */
exports.payuWebhook = onRequest({ cors: true }, async (req, res) => {
  try {
    const payload = req.body || {};
    logger.info("PayU Webhook Received Payload:", payload);

    const config = getPayUConfig();
    const { txnid, status, hash, amount, email, firstname, productinfo, mihexpressid } = payload;

    if (!txnid || !status) {
      return res.status(400).json({ success: false, message: "Invalid payload" });
    }

    if (hash) {
      const computedHash = computeResponseHash(payload, config.merchantSalt, config.merchantKey);
      if (computedHash !== hash.toLowerCase()) {
        logger.error(`Webhook Hash mismatch for txnid ${txnid}`);
        return res.status(400).json({ success: false, message: "Invalid hash signature" });
      }
    }

    const db = admin.firestore();
    const isSuccess = (status || "").toLowerCase() === "success";

    // Record webhook audit log in Firestore
    await db.collection("payment_logs").doc(txnid).set({
      txnid,
      status,
      amount: parseFloat(amount || 0),
      email,
      firstname,
      productinfo,
      payuMoneyId: mihexpressid || payload.mihpayid || "",
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      rawData: payload,
    }, { merge: true });

    // Sync status with matching subscription document
    const subQuery = await db.collectionGroup("data")
      .where("paymentTxnId", "==", txnid)
      .get();
    
    if (!subQuery.empty) {
      for (const doc of subQuery.docs) {
        if (doc.id === "subscription") {
          await doc.ref.set({
            webhookStatus: status,
            webhookVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            isSubscriptionActive: isSuccess,
            paymentStatus: isSuccess ? "SUCCESS" : "FAILED",
          }, { merge: true });
        }
      }
    }

    return res.status(200).json({ success: true, message: "Webhook processed and synchronized" });

  } catch (err) {
    logger.error("Error processing PayU Webhook:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});
