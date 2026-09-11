try {
  require("dotenv").config();
} catch (_) {}

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const crypto = require("crypto");
const emailService = require("./emailService");

const logger = functions.logger;
const HttpsError = functions.https.HttpsError;

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Environment configuration for PayU
 * Defaults to production credentials or matches runtime payload data
 */
const getPayUConfig = (data = {}) => {
  const isProduction = (process.env.PAYU_ENVIRONMENT || data.environment || "production").toLowerCase() === "production" ||
      data.merchantKey === (process.env.PAYU_PROD_KEY || "a912BZ") ||
      data.key === (process.env.PAYU_PROD_KEY || "a912BZ");
  
  if (isProduction) {
    return {
      environment: "production",
      merchantId: process.env.PAYU_PROD_MERCHANT_ID || "13573851",
      merchantKey: process.env.PAYU_PROD_KEY || "a912BZ",
      merchantSalt: process.env.PAYU_PROD_SALT || "jgo9fpvFX8DO2QtQDaWJHvz4JByS8ytC",
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
  const udf1 = params.udf1 || "";
  const udf2 = params.udf2 || "";
  const udf3 = params.udf3 || "";
  const udf4 = params.udf4 || "ebricks";
  const udf5 = params.udf5 || "ebricks_subscription";

  const hashSequence = `${params.merchantKey}|${params.txnid}|${amountStr}|${productInfo}|${firstName}|${email}|${udf1}|${udf2}|${udf3}|${udf4}|${udf5}||||||${salt}`;

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
 * 1. Callable Cloud Function (v1): generatePayUHash
 * Can be called directly from Flutter app via Firebase Functions SDK or HTTP
 */
exports.generatePayUHash = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const { txnid, amount, productInfo, firstName, email, phone, pg, bankcode, udf1, udf2, udf3, udf4, udf5 } = payload;

    if (!txnid || !amount) {
      throw new HttpsError("invalid-argument", "Missing required parameters: txnid and amount");
    }

    const effectiveUdf4 = udf4 || "ebricks";
    const effectiveUdf5 = udf5 || "ebricks_subscription";

    const config = getPayUConfig(payload);
    const params = {
      merchantKey: config.merchantKey,
      txnid,
      amount,
      productInfo,
      firstName,
      email,
      udf1: udf1 || "",
      udf2: udf2 || "",
      udf3: udf3 || "",
      udf4: effectiveUdf4,
      udf5: effectiveUdf5,
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
      udf1: udf1 || "",
      udf2: udf2 || "",
      udf3: udf3 || "",
      udf4: effectiveUdf4,
      udf5: effectiveUdf5,
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
 * 2. Callable Cloud Function (v1): verifySubscription
 * Verifies PayU transaction, confirms response hash signature, activates Firestore subscription,
 * and sends authoritative invoice email through Gmail SMTP.
 */
exports.verifySubscription = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const { orgId, txnid, payuMoneyId, rawData, planDetails, state } = payload;

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

    const config = getPayUConfig({ ...payload, ...(rawData || {}) });
    let isVerified = false;
    const rawStatus = (rawData?.status || "").toLowerCase();
    const effectivePayuMoneyId = payuMoneyId || rawData?.mihpayid || rawData?.payuMoneyId || "";

    // Check response hash signature if provided
    if (rawData && rawData.hash) {
      const computedHash = computeResponseHash(rawData, config.merchantSalt, config.merchantKey);
      if (computedHash === rawData.hash.toLowerCase()) {
        isVerified = true;
      } else {
        logger.warn(`Hash mismatch for txnid ${txnid}: computed=${computedHash}, received=${rawData.hash}`);
      }
    } else if (state === "success" && effectivePayuMoneyId) {
      isVerified = true;
    }

    // Determine lifecycle state - strictly require verified success and valid payuMoneyId
    let finalStatus = "FAILED";
    let isSubscriptionActive = false;

    if (state === "cancelled" || rawStatus === "cancel" || rawStatus === "cancelled" || rawStatus === "user_cancelled") {
      finalStatus = "CANCELLED";
    } else if (state === "pending" || rawStatus === "pending") {
      finalStatus = "PENDING";
    } else if (isVerified && (rawStatus === "success" || state === "success") && effectivePayuMoneyId.length > 0) {
      finalStatus = "SUCCESS";
      isSubscriptionActive = true;
    } else if (rawData && rawData.hash && !isVerified) {
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

    if (isSubscriptionActive) {
      // Reset reminder flag for new/renewed subscription period so new reminder is scheduled cleanly
      subscriptionUpdate.lastExpiryReminderSentForEndDate = null;
    }

    if (planDetails) {
      if (planDetails.planType) subscriptionUpdate.subscriptionType = planDetails.planType;
      if (planDetails.maxProjects !== undefined) subscriptionUpdate.maxProjects = planDetails.maxProjects;
      if (planDetails.maxUsers !== undefined) subscriptionUpdate.maxUsers = planDetails.maxUsers;
      if (planDetails.maxManagers !== undefined) subscriptionUpdate.maxManagers = planDetails.maxManagers;
      if (planDetails.maxSupervisors !== undefined) subscriptionUpdate.maxSupervisors = planDetails.maxSupervisors;
    }

    await subRef.set(subscriptionUpdate, { merge: true });

    // Synchronize root organisation document in real-time
    await orgRef.set({
      isSubscriptionActive,
      subscriptionPlan: subscriptionUpdate.subscriptionPlan,
      subscriptionType: planType,
      subscriptionStartDate: subscriptionUpdate.subscriptionStartDate,
      subscriptionEndDate: subscriptionUpdate.subscriptionEndDate,
      paymentStatus: finalStatus,
      paymentTxnId: txnid,
      payuMoneyId: subscriptionUpdate.payuMoneyId,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => {});

    // Ensure we have the user's registered email - check Firestore admin & root org doc if missing from request
    let effectiveEmail = (subscriptionUpdate.payerEmail || "").trim();
    let orgName = "eBricks Workspace";
    let effectiveCustomerName = subscriptionUpdate.payerName || "Customer";

    try {
      const orgDoc = await orgRef.get();
      if (orgDoc.exists) {
        const orgData = orgDoc.data() || {};
        orgName = orgData.org_name || orgData.name || orgName;
        if (!effectiveEmail && orgData.email) {
          effectiveEmail = orgData.email.trim();
        }
      }

      if (!effectiveEmail || effectiveCustomerName === "Customer") {
        const adminDoc = await orgRef.collection("data").doc("admin").get();
        if (adminDoc.exists) {
          const adminData = adminDoc.data() || {};
          if (!effectiveEmail && adminData.email) {
            effectiveEmail = adminData.email.trim();
          }
          if (adminData.username && effectiveCustomerName === "Customer") {
            effectiveCustomerName = adminData.username;
          }
        }
      }
    } catch (fetchErr) {
      logger.warn(`Could not fetch supplementary org/admin info for ${orgId}:`, fetchErr.message || fetchErr);
    }

    if (effectiveEmail && effectiveEmail !== subscriptionUpdate.payerEmail) {
      subscriptionUpdate.payerEmail = effectiveEmail;
      await subRef.set({ payerEmail: effectiveEmail }, { merge: true }).catch(() => {});
    }

    // Send authoritative invoice email if payment is verified and email is resolved
    let emailResult = null;
    if (isSubscriptionActive && effectiveEmail) {
      try {
        const isFreeTrial = (planDetails?.planName || "").toLowerCase().includes("free trial") || subscriptionUpdate.paymentAmount === 0;
        const isUpgrade = Boolean(payload.isUpgrade || (txnid && String(txnid).startsWith("UPG")));

        emailResult = await emailService.sendSubscriptionInvoice({
          orgId,
          txnid,
          payerEmail: effectiveEmail,
          payerName: effectiveCustomerName,
          orgName,
          planName: planDetails?.planName || subscriptionUpdate.subscriptionPlan || "Silver",
          planType,
          amount: subscriptionUpdate.paymentAmount,
          payuMoneyId: subscriptionUpdate.payuMoneyId,
          paymentMethod: subscriptionUpdate.paymentMethod,
          startDate: now,
          endDate,
          isTrial: isFreeTrial,
          isUpgrade,
        }, db);
        
        logger.info(`[eBricks verifySubscription] Invoice email dispatch result for txnid ${txnid}:`, emailResult);
      } catch (emailErr) {
        logger.warn(`[eBricks verifySubscription] Invoice email dispatch error for txnid ${txnid}:`, emailErr.message || emailErr);
        // Important: Email failure must NOT rollback the active subscription
      }
    }

    return {
      success: isSubscriptionActive,
      txnid,
      orgId,
      status: finalStatus,
      isSubscriptionActive,
      payerName: effectiveCustomerName,
      payerEmail: effectiveEmail,
      emailSent: emailResult ? emailResult.success : false,
    };

  } catch (err) {
    logger.error("Error verifying and activating subscription:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Failed to process subscription");
  }
});

/**
 * Shared HTML status page renderer for Mobile WebView PayUBridge
 */
function renderBridgeHtml(rawData) {
  const status = (rawData.status || rawData.unmappedstatus || "success").toLowerCase();
  const payloadJson = JSON.stringify(rawData).replace(/</g, "\\u003c").replace(/>/g, "\\u003e");

  return `<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment ${status === "success" ? "Successful" : "Status"}</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      background: #f8fafc;
      color: #0f172a;
    }
    .card {
      background: white;
      padding: 24px;
      border-radius: 20px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.06);
      text-align: center;
      max-width: 320px;
    }
    .icon {
      width: 54px;
      height: 54px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 16px;
      font-size: 24px;
      color: white;
      background: ${status === "success" ? "#10b981" : "#ef4444"};
    }
    h2 { margin: 0 0 8px; font-size: 18px; font-weight: 800; }
    p { margin: 0; color: #64748b; font-size: 13px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">${status === "success" ? "✓" : "✕"}</div>
    <h2>${status === "success" ? "Payment Completed" : "Payment Failed"}</h2>
    <p>Returning to workspace...</p>
  </div>
  <script type="text/javascript">
    const responseData = ${payloadJson};
    responseData['_pageUrl'] = window.location.href;
    
    function notifyApp() {
      if (window.PayUBridge) {
        window.PayUBridge.postMessage(JSON.stringify(responseData));
      }
    }
    notifyApp();
    setTimeout(notifyApp, 250);
    setTimeout(notifyApp, 700);
  </script>
</body>
</html>`;
}

/**
 * 3. HTTP Webhook (v1): payuWebhook
 * Handles both PayU asynchronous server webhooks and browser redirect callbacks.
 * On verified success, updates Firestore and delivers invoice email via Gmail SMTP.
 */
exports.payuWebhook = functions.region("us-central1").https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const payload = req.body || req.query || {};
      logger.info("PayU Webhook/Callback Received Payload:", payload);

      const config = getPayUConfig();
      const { txnid, status, amount, email, firstname, productinfo, mihexpressid } = payload;
      const mihpayid = mihexpressid || payload.mihpayid || payload.payuMoneyId || "";
      const rawStatus = (status || "").toLowerCase();
      let isSuccess = rawStatus === "success";

      // Check if this request is a browser HTTP redirect (surl / furl hitting payuWebhook)
      const isBrowserRedirect = (req.headers["accept"] && req.headers["accept"].includes("text/html")) ||
          req.headers["sec-fetch-dest"] === "document" ||
          (req.headers["user-agent"] && req.headers["user-agent"].includes("Mozilla")) ||
          (payload && (payload.mihpayid || payload.payuMoneyId || payload.unmappedstatus || payload.status));

      // -------------------------------------------------------------
      // 1. RESPONSE SIGNATURE HASH VERIFICATION
      // -------------------------------------------------------------
      if (payload.hash) {
        const computedHash = computeResponseHash(payload, config.merchantSalt, config.merchantKey);
        if (computedHash !== payload.hash.toLowerCase()) {
          logger.warn(`[eBricks PayU Webhook] Hash signature mismatch for txnid ${txnid}: computed=${computedHash}, received=${payload.hash}`);
          // If hash mismatch, invalidate success status
          isSuccess = false;
        }
      }

      const db = admin.firestore();

      if (txnid) {
        const orgIdFromUdf = (payload.udf1 || "").trim();

        // -------------------------------------------------------------
        // 2. IDEMPOTENCY CHECK
        // Prevent duplicate processing on repeated PayU webhook deliveries
        // -------------------------------------------------------------
        const existingLogDoc = await db.collection("payment_logs").doc(txnid).get().catch(() => null);
        if (existingLogDoc && existingLogDoc.exists) {
          const logData = existingLogDoc.data() || {};
          if (logData.processedByApp === true && logData.status === "success" && isSuccess) {
            logger.info(`[eBricks PayU Webhook] Transaction ${txnid} already processed. Skipping duplicate execution.`);
            if (isBrowserRedirect) {
              res.set("Content-Type", "text/html");
              return res.status(200).send(renderBridgeHtml(payload));
            }
            return res.status(200).json({ status: "success", message: "Transaction already processed", txnid });
          }
        }

        // Record verified eBricks webhook audit log in Firestore
        await db.collection("payment_logs").doc(txnid).set({
          txnid,
          app: "eBricks",
          processedByApp: true,
          status: status || "UNKNOWN",
          amount: parseFloat(amount || 0),
          email: email || "",
          firstname: firstname || "",
          productinfo: productinfo || "",
          payuMoneyId: mihpayid,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          rawData: payload,
        }, { merge: true }).catch((err) => logger.warn("Log write warning:", err));

        // 3. If udf1 carries the orgId, update organisation and subscription document directly
        if (orgIdFromUdf && orgIdFromUdf !== "onboarding_temp") {
          const orgRef = db.collection("organisation").doc(orgIdFromUdf);
          await orgRef.set({
            isSubscriptionActive: isSuccess,
            paymentStatus: isSuccess ? "SUCCESS" : "FAILED",
            payuMoneyId: mihpayid,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }).catch(() => {});

          await orgRef.collection("data").doc("subscription").set({
            webhookStatus: status,
            webhookVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            isSubscriptionActive: isSuccess,
            paymentStatus: isSuccess ? "SUCCESS" : "FAILED",
            payuMoneyId: mihpayid,
            ...(isSuccess ? { lastExpiryReminderSentForEndDate: null } : {}),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }).catch(() => {});
        }

        // 4. Query top-level organisation collection by paymentTxnId
        const orgQuery = await db.collection("organisation")
          .where("paymentTxnId", "==", txnid)
          .get()
          .catch((err) => {
            logger.warn("Direct org query warning:", err);
            return { empty: true, docs: [] };
          });
        
        if (!orgQuery.empty) {
          for (const doc of orgQuery.docs) {
            await doc.ref.set({
              isSubscriptionActive: isSuccess,
              paymentStatus: isSuccess ? "SUCCESS" : "FAILED",
              payuMoneyId: mihpayid,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true }).catch(() => {});

            await doc.ref.collection("data").doc("subscription").set({
              webhookStatus: status,
              webhookVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
              isSubscriptionActive: isSuccess,
              paymentStatus: isSuccess ? "SUCCESS" : "FAILED",
              payuMoneyId: mihpayid,
              ...(isSuccess ? { lastExpiryReminderSentForEndDate: null } : {}),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true }).catch(() => {});
          }
        }

        // 5. Send invoice email on successful webhook (idempotent in emailService)
        if (isSuccess) {
          try {
            let payerEmail = email;
            let payerName = firstname || "Customer";
            let orgName = "eBricks Workspace";
            let planName = productinfo || "Silver";

            if (orgIdFromUdf && orgIdFromUdf !== "onboarding_temp") {
              const orgDoc = await db.collection("organisation").doc(orgIdFromUdf).get();
              if (orgDoc.exists) {
                const oData = orgDoc.data() || {};
                orgName = oData.org_name || oData.name || orgName;
                payerEmail = payerEmail || oData.email || oData.org_email;
              }
            }

            if (payerEmail) {
              const isFreeTrial = (planName || "").toLowerCase().includes("trial") || parseFloat(amount || 0) === 0;
              const isUpgrade = (planName || "").toLowerCase().includes("upgrade") || String(txnid).startsWith("UPG");

              await emailService.sendSubscriptionInvoice({
                orgId: orgIdFromUdf || "",
                txnid,
                payerEmail,
                payerName,
                orgName,
                planName,
                planType: "Subscription",
                amount: parseFloat(amount || 0),
                payuMoneyId: mihpayid,
                paymentMethod: payload.mode || "PayU",
                startDate: new Date(),
                endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
                isTrial: isFreeTrial,
                isUpgrade,
              }, db);
            }
          } catch (emailErr) {
            logger.warn(`Webhook invoice email send error for txnid ${txnid}:`, emailErr.message || emailErr);
          }
        }
      }

      if (isBrowserRedirect) {
        res.set("Content-Type", "text/html");
        return res.status(200).send(renderBridgeHtml(payload));
      }

      return res.status(200).json({ success: true, message: "Webhook processed and synchronized" });
    } catch (err) {
      logger.error("Error processing PayU Webhook/Callback:", err);
      res.set("Content-Type", "text/html");
      return res.status(200).send(renderBridgeHtml({ status: "failure", error: err.message }));
    }
  });
});

/**
 * 4. HTTP Endpoint (v1): payuResponse
 * Seamlessly handles POST/GET from PayU for surl and furl in Mobile WebView
 */
exports.payuResponse = functions.region("us-central1").https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const rawData = req.body || req.query || {};
      logger.info("PayU Response Callback Received:", rawData);

      const txnid = rawData.txnid || "";
      const status = (rawData.status || rawData.unmappedstatus || "success").toLowerCase();
      const mihpayid = rawData.mihpayid || rawData.payuMoneyId || "";

      if (txnid) {
        const db = admin.firestore();
        db.collection("payment_logs").doc(txnid).set({
          txnid,
          app: "eBricks",
          status,
          amount: parseFloat(rawData.amount || 0),
          email: rawData.email || "",
          firstname: rawData.firstname || "",
          payuMoneyId: mihpayid,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          rawData,
        }, { merge: true }).catch(() => {});
      }

      res.set("Content-Type", "text/html");
      return res.status(200).send(renderBridgeHtml(rawData));
    } catch (err) {
      logger.error("Error in payuResponse callback handler:", err);
      res.set("Content-Type", "text/html");
      return res.status(200).send(renderBridgeHtml({ status: "failure", error: err.message }));
    }
  });
});

/**
 * 5. Callable Cloud Function (v1): resendSubscriptionInvoice
 * Safely retries or resends an invoice email for an existing verified transaction
 */
exports.resendSubscriptionInvoice = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const { txnid, emailOverride } = payload;

    if (!txnid) {
      throw new HttpsError("invalid-argument", "Missing required parameter: txnid");
    }

    const db = admin.firestore();
    const invoiceRef = db.collection("invoices").doc(txnid);
    const invoiceSnap = await invoiceRef.get();

    if (!invoiceSnap.exists) {
      throw new HttpsError("not-found", `No invoice or transaction record found for txnid: ${txnid}`);
    }

    const invoiceData = invoiceSnap.data() || {};
    const targetEmail = (emailOverride || invoiceData.payerEmail || "").trim();

    if (!targetEmail || !emailService.isValidEmail(targetEmail)) {
      throw new HttpsError("invalid-argument", "No valid recipient email associated with this invoice");
    }

    const numAmount = parseFloat(invoiceData.amount || 0);
    const isFreeTrial = (invoiceData.planName || "").toLowerCase().includes("free trial") || (numAmount === 0 && (String(invoiceData.paymentMethod || "").toLowerCase().includes("trial") || String(invoiceData.invoiceType || "").toLowerCase().includes("trial") || String(invoiceData.planType || "").toLowerCase().includes("trial")));
    const isPlanUpgrade = String(invoiceData.paymentMethod).toLowerCase().includes("upgrade") || (txnid && String(txnid).startsWith("UPG"));

    const html = emailService.renderInvoiceHtml({
      customerName: invoiceData.payerName || "Customer",
      orgName: invoiceData.orgName || "eBricks Workspace",
      invoiceNo: invoiceData.invoiceNo || `INV-${txnid.slice(-6)}`,
      planName: invoiceData.planName || "Silver",
      planType: invoiceData.planType || "Monthly",
      amount: invoiceData.amount || 0,
      paymentMethod: invoiceData.paymentMethod || "UPI",
      txnid,
      payuMoneyId: invoiceData.payuMoneyId || "Confirmed by PayU",
      paymentDate: invoiceData.paymentDate || new Date().toLocaleDateString("en-IN"),
      startDate: invoiceData.startDate || "Today",
      endDate: invoiceData.endDate || "30 Days",
      isTrial: isFreeTrial,
      isUpgrade: isPlanUpgrade,
    });

    let subject = "";
    if (isFreeTrial) {
      subject = `Welcome to eBricks - Free Trial Subscription Invoice for ${invoiceData.orgName || "eBricks Workspace"}`;
    } else if (isPlanUpgrade) {
      subject = `eBricks Subscription Plan Update Invoice - ${invoiceData.orgName || "eBricks Workspace"} (${invoiceData.planName || "Plan"})`;
    } else {
      subject = `eBricks Subscription Invoice & Payment Receipt - ${invoiceData.orgName || "eBricks Workspace"} (${invoiceData.planName || "Plan"})`;
    }

    const result = await emailService.sendEmail({
      to: targetEmail,
      subject,
      html,
    });

    if (result.success) {
      await invoiceRef.set({
        emailStatus: "SENT",
        emailMessageId: result.messageId,
        emailSentAt: new Date(),
        resentAt: new Date(),
      }, { merge: true });
    }

    return {
      success: result.success,
      messageId: result.messageId,
      recipient: emailService.maskEmail(targetEmail),
      error: result.error,
    };
  } catch (err) {
    logger.error("resendSubscriptionInvoice error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Failed to resend invoice");
  }
});

/**
 * 6. Callable Cloud Function (v1): sendNewSubscriptionInvoice
 * Dispatches welcome / subscription invoice for any newly subscribed plan (Free Trial, Silver, Gold, Platinum, etc.)
 */
exports.sendNewSubscriptionInvoice = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const {
      orgId,
      txnid = `TXN-${Date.now()}`,
      planName = "Free Trial",
      planType = "Free Trial",
      amount = 0,
      payerEmail,
      payerName,
      paymentMethod = "Free Trial Activation",
      payuMoneyId = "Complimentary Access",
      isTrial,
      isUpgrade,
    } = payload;

    if (!orgId) {
      throw new HttpsError("invalid-argument", "Missing required parameter: orgId");
    }

    const db = admin.firestore();
    const orgRef = db.collection("organisation").doc(orgId);

    let effectiveEmail = (payerEmail || "").trim();
    let orgName = "eBricks Workspace";
    let effectiveCustomerName = payerName || "Customer";

    try {
      const orgDoc = await orgRef.get();
      if (orgDoc.exists) {
        const orgData = orgDoc.data() || {};
        orgName = orgData.org_name || orgData.name || orgName;
        if (!effectiveEmail && orgData.email) {
          effectiveEmail = orgData.email.trim();
        }
      }

      if (!effectiveEmail || effectiveCustomerName === "Customer") {
        const adminDoc = await orgRef.collection("data").doc("admin").get();
        if (adminDoc.exists) {
          const adminData = adminDoc.data() || {};
          if (!effectiveEmail && adminData.email) {
            effectiveEmail = adminData.email.trim();
          }
          if (adminData.username && effectiveCustomerName === "Customer") {
            effectiveCustomerName = adminData.username;
          }
        }
      }
    } catch (e) {
      logger.warn(`Supplementary lookup note for ${orgId}:`, e.message || e);
    }

    if (!effectiveEmail || !emailService.isValidEmail(effectiveEmail)) {
      throw new HttpsError("invalid-argument", `No valid registered email found for organisation ${orgId}`);
    }

    const now = new Date();
    let durationDays = 14;
    if (planType === "6 Months") durationDays = 180;
    else if (planType === "Yearly") durationDays = 365;
    else if (planType === "Monthly") durationDays = 30;

    const endDate = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

    const numAmount = parseFloat(amount || 0);
    const isFreeTrial = isTrial !== undefined ? isTrial : (planName.toLowerCase().includes("free trial") || numAmount === 0);
    const isPlanUpgrade = isUpgrade !== undefined ? isUpgrade : (String(paymentMethod).toLowerCase().includes("upgrade") || String(txnid).startsWith("UPG"));

    const result = await emailService.sendSubscriptionInvoice({
      orgId,
      txnid,
      payerEmail: effectiveEmail,
      payerName: effectiveCustomerName,
      orgName,
      planName,
      planType,
      amount: numAmount,
      payuMoneyId,
      paymentMethod,
      startDate: now,
      endDate,
      isTrial: isFreeTrial,
      isUpgrade: isPlanUpgrade,
    }, db);

    return {
      success: result.success,
      txnid,
      recipient: emailService.maskEmail(effectiveEmail),
      messageId: result.messageId,
      alreadySent: result.alreadySent || false,
    };
  } catch (err) {
    logger.error("sendNewSubscriptionInvoice error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Failed to deliver subscription invoice");
  }
});

// =============================================================================
// REAL-TIME PUSH NOTIFICATION ENGINE (FCM ADMIN SDK)
// =============================================================================

/**
 * Atomic idempotency check to prevent duplicate push notifications for the same activity/event.
 * Returns true if the event has already been processed or is currently in-flight.
 */
async function isEventAlreadyProcessed(idempotencyKey, eventDetails = {}) {
  if (!idempotencyKey) return false;
  const db = admin.firestore();
  const ref = db.collection("processed_events").doc(idempotencyKey);

  try {
    // .create() fails atomically with gRPC code 6 (ALREADY_EXISTS) if doc exists
    await ref.create({
      idempotencyKey,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expireAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      ...eventDetails,
    });
    return false; // Successfully acquired lock, not duplicate
  } catch (err) {
    if (err.code === 6 || err.code === "already-exists" || (err.message && err.message.includes("ALREADY_EXISTS"))) {
      logger.info(`[Idempotency] Duplicate event detected and dropped: ${idempotencyKey}`);
      return true; // Already processed!
    }
    // Fallback check
    try {
      const doc = await ref.get();
      if (doc.exists) {
        logger.info(`[Idempotency] Duplicate event confirmed via get(): ${idempotencyKey}`);
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/**
 * Helper to normalize user roles (handles British vs American spelling)
 */
const normalizeRole = (r) => {
  const s = String(r || "").toLowerCase().trim();
  if (s === "organisation" || s === "organization" || s === "org") return "organisation";
  return s;
};

/**
 * Processes a newly created notification document and dispatches real-time push notifications
 * using Firebase Cloud Messaging (FCM) Admin SDK to all active recipient devices.
 */
async function processNotificationAndSendPush(notificationData, docRef) {
  try {
    const {
      title = "New Notification",
      body = "",
      targetRole = "all",
      targetRoles: rawTargetRoles,
      forSupervisorName = "",
      forSupervisorId = "",
      forManagerName = "",
      forManagerId = "",
      userId: directUserId = "",
      forUserId = "",
      forOrgId = "",
      orgId: directOrgId = "",
      requestType = "general",
      requestId = "",
      docId = "",
      siteId = "",
      siteName = "",
      status = "",
      senderName = "",
      senderRole = "",
      senderId = "",
      data: customData = {},
    } = notificationData || {};

    if (!title && !body) {
      logger.warn("Notification skipped: Missing title and body", notificationData);
      return;
    }

    const orgId = (forOrgId || directOrgId || "").trim();
    const db = admin.firestore();
    const tokens = new Set();
    const tokenDocRefs = [];

    // Parse target roles into normalized lowercase set
    let targetRoles = [];
    if (Array.isArray(rawTargetRoles) && rawTargetRoles.length > 0) {
      targetRoles = rawTargetRoles.map((r) => normalizeRole(r));
    } else if (targetRole) {
      const tr = normalizeRole(targetRole);
      if (tr === "manager_and_organisation" || tr === "manager_and_organization") {
        targetRoles = ["manager", "organisation", "config"];
      } else {
        targetRoles = [tr];
      }
    } else {
      targetRoles = ["all"];
    }

    // Ensure organisation and organization synonyms both exist
    if (targetRoles.includes("organisation") && !targetRoles.includes("organization")) {
      targetRoles.push("organization");
    }

    const cleanSenderRole = normalizeRole(senderRole || "");
    const cleanSenderName = (senderName || "").trim().toLowerCase();
    const cleanSenderId = (senderId || "").trim().toLowerCase();

    // 1. Idempotency Check & Atomic Lock
    const explicitKey = notificationData.idempotencyKey ||
      (customData && customData.idempotencyKey) ||
      notificationData.eventId ||
      (customData && customData.eventId);

    const timeBucket = Math.floor(Date.now() / 25000);
    const targetEntity = siteId || notificationData.projectId || docId || requestId || "global";
    const effectiveReqType = requestType || notificationData.type || "general";
    const targetRolesStr = targetRoles.join("_");

    const idempotencyKey = explicitKey ?
      String(explicitKey).trim() :
      `evt_${orgId || "org"}_${effectiveReqType}_${targetEntity}_${targetRolesStr}_${cleanSenderName || "user"}_${timeBucket}`.replace(/[\/\s#]/g, "_");

    const alreadyProcessed = await isEventAlreadyProcessed(idempotencyKey, {
      title,
      body,
      orgId,
      requestType: effectiveReqType,
      targetEntity,
    });

    if (alreadyProcessed) {
      logger.info(`[Idempotency] Suppressed duplicate push for event key "${idempotencyKey}".`);
      if (docRef) {
        await docRef.update({
          pushDelivered: true,
          duplicateSuppressed: true,
          idempotencyKey,
        }).catch(() => {});
      }
      return { successCount: 0, failureCount: 0, suppressed: true };
    }

    // 2. Direct Token check (if single token dispatch requested)
    const directDeviceToken = (notificationData.token || (customData && customData.token) || "").trim();
    if (directDeviceToken) {
      tokens.add(directDeviceToken);
    } else {
      const targetUserIds = [directUserId, forUserId, forSupervisorId, forManagerId]
        .filter(Boolean)
        .map((s) => String(s).trim().toLowerCase());

      const evaluateTokenDoc = (doc) => {
        const d = doc.data() || {};
        const t = (d.token || "").trim();
        if (!t) return;

        const rawUType = (d.userType || "").toLowerCase().trim();
        const uType = normalizeRole(rawUType);
        const uName = (d.userName || "").toLowerCase().trim();
        const uId = (d.userId || doc.id || "").toLowerCase().trim();

        // Avoid self-notifications ONLY if the token belongs to the same role and same user.
        // (Do NOT suppress if sender is Manager and recipient is Organisation, even if both use username 'admin')
        const isSameRole = cleanSenderRole && (
          uType === cleanSenderRole ||
          (cleanSenderRole === "manager" && uType === "config") ||
          (cleanSenderRole === "organisation" && (uType === "config" || uType === "admin"))
        );
        if (isSameRole) {
          if (cleanSenderName && uName === cleanSenderName) return;
          if (cleanSenderId && (uId === cleanSenderId || doc.id.toLowerCase() === cleanSenderId || doc.id.toLowerCase().endsWith("_" + cleanSenderId))) return;
        }

        // 1. Direct user ID match
        if (targetUserIds.length > 0 && (targetUserIds.includes(uId) || targetUserIds.some((tId) => doc.id.toLowerCase().includes(tId)))) {
          tokens.add(t);
          tokenDocRefs.push(doc.ref);
          return;
        }

        // 2. Role matching (support organisation, organization, config, admin, manager, supervisor)
        const isOrgTarget = targetRoles.includes("organisation") || targetRoles.includes("organization");
        const isOrgUser = uType === "organisation" || rawUType === "organization" || uType === "config" || rawUType === "admin";
        const isManagerTarget = targetRoles.includes("manager") || targetRoles.includes("config");
        const isManagerUser = uType === "manager" || uType === "config";
        const isSupervisorTarget = targetRoles.includes("supervisor");
        const isSupervisorUser = uType === "supervisor";

        const isRoleMatch = targetRoles.includes("all") ||
          (isOrgTarget && isOrgUser) ||
          (isManagerTarget && isManagerUser) ||
          (isSupervisorTarget && isSupervisorUser) ||
          targetRoles.includes(uType) ||
          targetRoles.includes(rawUType);

        // 3. User-specific filtering:
        let isUserMatch = true;
        if (isSupervisorUser) {
          if (forSupervisorName || forSupervisorId) {
            const targetSup = (forSupervisorName || "").toLowerCase().trim();
            const targetSupId = (forSupervisorId || "").toLowerCase().trim();
            isUserMatch = (targetSup && (uName === targetSup || uName.includes(targetSup) || targetSup.includes(uName))) ||
                          (targetSupId && (uId === targetSupId || doc.id.toLowerCase().includes(targetSupId)));
          }
        } else if (isManagerUser) {
          if (forManagerName || forManagerId) {
            const targetMgr = (forManagerName || "").toLowerCase().trim();
            const targetMgrId = (forManagerId || "").toLowerCase().trim();
            isUserMatch = (targetMgr && (uName === targetMgr || uName.includes(targetMgr) || targetMgr.includes(uName))) ||
                          (targetMgrId && (uId === targetMgrId || doc.id.toLowerCase().includes(targetMgrId)));
          }
        }

        if (isRoleMatch && isUserMatch) {
          tokens.add(t);
          tokenDocRefs.push(doc.ref);
        }
      };

      // 1. Search in /organisation/{orgId}/fcmTokens
      if (orgId && orgId !== "uninitialized") {
        try {
          const orgSnap = await db.collection("organisation").doc(orgId).collection("fcmTokens").get();
          orgSnap.forEach(evaluateTokenDoc);
        } catch (e) {
          logger.warn(`Error querying org fcmTokens for ${orgId}:`, e.message);
        }
      }

      // 2. Search in global /fcmTokens by orgId
      try {
        let globalQuery = db.collection("fcmTokens");
        if (orgId && orgId !== "uninitialized") {
          const globalSnap = await globalQuery.where("orgId", "==", orgId).get();
          globalSnap.forEach(evaluateTokenDoc);
        }
      } catch (e) {
        logger.warn("Error querying global fcmTokens:", e.message);
      }

      // 3. Search in global /fcmTokens for doc ids starting with orgId or matching
      if (tokens.size === 0 && orgId && orgId !== "uninitialized") {
        try {
          const allSnap = await db.collection("fcmTokens").limit(200).get();
          allSnap.forEach((doc) => {
            const docId = doc.id;
            const d = doc.data() || {};
            if (docId.startsWith(orgId + "_") || (d.orgId && String(d.orgId).trim() === orgId)) {
              evaluateTokenDoc(doc);
            }
          });
        } catch (_) {}
      }

      // Fallback search in entire global collection if still 0 tokens
      if (tokens.size === 0) {
        try {
          const allSnap = await db.collection("fcmTokens").limit(100).get();
          allSnap.forEach(evaluateTokenDoc);
        } catch (_) {}
      }
    }

    const tokenList = Array.from(tokens);
    logger.info(`Resolved ${tokenList.length} direct FCM token(s) for "${title}" -> Target: ${targetRoles.join(",")} (Org: ${orgId})`);

    // Prepare string data payload (FCM requirement)
    const effectiveDocId = String(notificationData.notificationId || requestId || docId || Date.now());
    const effectiveType = String(requestType || notificationData.type || "general");
    const effectiveRoute = String(notificationData.actionRoute || `/${effectiveType}`);
    const stringData = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      notificationId: effectiveDocId,
      id: effectiveDocId,
      title: String(title),
      body: String(body),
      message: String(body),
      type: effectiveType,
      requestType: effectiveType,
      actionRoute: effectiveRoute,
      targetRole: String(targetRoles[0] || targetRole || ""),
      recipientRole: String(targetRoles[0] || targetRole || ""),
      recipientId: String(notificationData.recipientId || directUserId || forSupervisorId || forManagerId || "all"),
      requestId: String(requestId || docId || effectiveDocId),
      docId: String(docId || requestId || effectiveDocId),
      projectId: String(notificationData.projectId || siteId || ""),
      projectName: String(notificationData.projectName || siteName || ""),
      siteId: String(siteId || ""),
      siteName: String(siteName || ""),
      status: String(status || ""),
      priority: String(notificationData.priority || "high"),
      orgId: String(orgId || ""),
      tenantId: String(orgId || ""),
      senderName: String(senderName || ""),
      senderRole: String(senderRole || ""),
    };

    if (notificationData.actionData && typeof notificationData.actionData === "object") {
      for (const [k, v] of Object.entries(notificationData.actionData)) {
        if (v !== undefined && v !== null) {
          stringData[k] = typeof v === "string" ? v : JSON.stringify(v);
        }
      }
    }

    if (customData && typeof customData === "object") {
      for (const [k, v] of Object.entries(customData)) {
        if (v !== undefined && v !== null && stringData[k] === undefined) {
          stringData[k] = typeof v === "string" ? v : JSON.stringify(v);
        }
      }
    }

    // 3. Dispatch to Direct Device Tokens if available
    let successCount = 0;
    let failureCount = 0;

    if (tokenList.length > 0) {
      const message = {
        tokens: tokenList,
        notification: {
          title: title,
          body: body,
        },
        data: stringData,
        android: {
          priority: "high",
          ttl: 86400 * 1000, // 24 hours
          notification: {
            channelId: "cst_high_importance_channel",
            sound: "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            priority: "high",
            visibility: "public",
            notificationCount: 1,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: "default",
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      successCount = response.successCount;
      failureCount = response.failureCount;
      logger.info(`FCM Multicast delivery result for "${title}": Success ${successCount}, Failure ${failureCount}`);

      // Auto-prune dead/invalid registration tokens
      if (failureCount > 0) {
        const tokensToDelete = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              tokensToDelete.push(tokenDocRefs[idx]);
            }
          }
        });

        if (tokensToDelete.length > 0) {
          logger.info(`Pruning ${tokensToDelete.length} stale/expired FCM token documents.`);
          await Promise.all(tokensToDelete.map((ref) => (ref ? ref.delete().catch(() => {}) : Promise.resolve())));
        }
      }
    }

    // 4. Topic Broadcast Fallback (if direct tokens were 0 or failed)
    if (successCount === 0 && orgId && orgId !== "uninitialized") {
      const cleanOrgId = orgId.replace(/[^\w]/g, "_");
      const topicTargets = new Set();

      if (targetRoles.includes("all") || targetRoles.includes("manager_and_organisation") || targetRoles.includes("organisation") || targetRoles.includes("organization")) {
        topicTargets.add(`org_${cleanOrgId}`);
        topicTargets.add(`org_${cleanOrgId}_organisation`);
        topicTargets.add(`org_${cleanOrgId}_organization`);
      }
      targetRoles.forEach((role) => {
        if (role !== "all") {
          topicTargets.add(`org_${cleanOrgId}_${role}`);
        }
      });
      if (topicTargets.size === 0) {
        topicTargets.add(`org_${cleanOrgId}`);
      }

      for (const topic of topicTargets) {
        const topicMessage = {
          topic,
          notification: {
            title: title,
            body: body,
          },
          data: stringData,
          android: {
            priority: "high",
            ttl: 86400 * 1000,
            notification: {
              channelId: "cst_high_importance_channel",
              sound: "default",
              defaultSound: true,
              defaultVibrateTimings: true,
              priority: "high",
              visibility: "public",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title: title,
                  body: body,
                },
                sound: "default",
                badge: 1,
                contentAvailable: true,
              },
            },
          },
        };

        try {
          const res = await admin.messaging().send(topicMessage);
          logger.info(`FCM Topic push broadcast delivered to topic "${topic}": ${res}`);
          successCount++;
        } catch (topicErr) {
          logger.warn(`Failed sending FCM topic broadcast to "${topic}":`, topicErr.message || topicErr);
        }
      }
    }

    if (docRef) {
      await docRef.update({
        pushDelivered: successCount > 0,
        successCount: successCount,
        failureCount: failureCount,
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});
    }

    return { successCount, failureCount };
  } catch (err) {
    logger.error("processNotificationAndSendPush error:", err);
    return null;
  }
}

/**
 * 4. Firestore Trigger: onNotificationCreated
 * Automatically fires in real-time when any notification document is written to /notifications/{id}
 */
exports.onNotificationCreated = functions.region("us-central1").firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    logger.info(`Triggered onNotificationCreated for doc: ${context.params.notificationId}`);
    const data = snap.data() || {};
    const idempotencyKey = data.idempotencyKey || `notif_${context.params.notificationId}`;
    return processNotificationAndSendPush({ ...data, idempotencyKey, notificationId: context.params.notificationId }, snap.ref);
  });

/**
 * 5. Firestore Trigger: onOrgNotificationCreated
 * Automatically fires in real-time when any notification is written to /organisation/{orgId}/notifications/{id}
 */
exports.onOrgNotificationCreated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    logger.info(`Triggered onOrgNotificationCreated for org: ${context.params.orgId}, doc: ${context.params.notificationId}`);
    const data = snap.data() || {};
    const idempotencyKey = data.idempotencyKey || `notif_${context.params.orgId}_${context.params.notificationId}`;
    return processNotificationAndSendPush({ ...data, orgId: context.params.orgId, idempotencyKey, notificationId: context.params.notificationId }, snap.ref);
  });

/**
 * 6. Firestore Trigger: onProjectCreated
 * Automatically fires in real-time when a project is created under /projects/{projectId}
 */
exports.onProjectCreated = functions.region("us-central1").firestore
  .document("projects/{projectId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const projectId = context.params.projectId;
    const projectName = data.projectName || data.name || projectId;
    const siteId = data.siteId || "";
    const siteName = data.siteName || "";
    const orgId = data.orgId || data.forOrgId || "";
    const managerName = data.managerName || data.ownerName || "Manager";

    logger.info(`Triggered onProjectCreated for project: ${projectName} (${projectId})`);

    const title = "New Project Created";
    const body = `Manager has created a new project: ${projectName}`;
    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `project_created_${orgId || "all"}_${projectId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title,
      body,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "project_created",
      type: "project_created",
      projectId,
      docId: projectId,
      requestId: projectId,
      siteId,
      siteName,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/project_details",
      idempotencyKey,
      data: {
        projectId,
        projectName,
        siteId,
        siteName,
        type: "project_created",
        actionRoute: "/project_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 7. Firestore Trigger: onOrgProjectCreated
 * Automatically fires in real-time when a project is created under /organisation/{orgId}/projects/{projectId}
 */
exports.onOrgProjectCreated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/projects/{projectId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const orgId = context.params.orgId;
    const projectId = context.params.projectId;
    const projectName = data.projectName || data.name || projectId;
    const siteId = data.siteId || "";
    const siteName = data.siteName || "";
    const managerName = data.managerName || data.ownerName || "Manager";

    logger.info(`Triggered onOrgProjectCreated for org: ${orgId}, project: ${projectName} (${projectId})`);

    const title = "New Project Created";
    const body = `Manager has created a new project: ${projectName}`;
    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `project_created_${orgId}_${projectId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title,
      body,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "project_created",
      type: "project_created",
      projectId,
      docId: projectId,
      requestId: projectId,
      siteId,
      siteName,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/project_details",
      idempotencyKey,
      data: {
        projectId,
        projectName,
        siteId,
        siteName,
        type: "project_created",
        actionRoute: "/project_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 8. Firestore Trigger: onProjectUpdated
 * Automatically fires in real-time when a project is updated under /projects/{projectId}
 */
exports.onProjectUpdated = functions.region("us-central1").firestore
  .document("projects/{projectId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() || {};
    const afterData = change.after.data() || {};
    const projectId = context.params.projectId;
    const projectName = afterData.projectName || afterData.name || projectId;
    const siteId = afterData.siteId || "";
    const siteName = afterData.siteName || "";
    const orgId = afterData.orgId || afterData.forOrgId || "";
    const managerName = afterData.managerName || afterData.ownerName || "Manager";

    // Skip if only internal timestamp or notification flag changed
    if (beforeData.pushDelivered !== afterData.pushDelivered) return null;

    logger.info(`Triggered onProjectUpdated for project: ${projectName} (${projectId})`);

    const title = "Project Updated";
    const body = `Manager has updated the project: ${projectName}`;
    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `project_updated_${orgId || "all"}_${projectId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title,
      body,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "project_updated",
      type: "project_updated",
      projectId,
      docId: projectId,
      requestId: projectId,
      siteId,
      siteName,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/project_details",
      idempotencyKey,
      data: {
        projectId,
        projectName,
        siteId,
        siteName,
        type: "project_updated",
        actionRoute: "/project_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 9. Firestore Trigger: onOrgProjectUpdated
 * Automatically fires in real-time when a project is updated under /organisation/{orgId}/projects/{projectId}
 */
exports.onOrgProjectUpdated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/projects/{projectId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() || {};
    const afterData = change.after.data() || {};
    const orgId = context.params.orgId;
    const projectId = context.params.projectId;
    const projectName = afterData.projectName || afterData.name || projectId;
    const siteId = afterData.siteId || "";
    const siteName = afterData.siteName || "";
    const managerName = afterData.managerName || afterData.ownerName || "Manager";

    if (beforeData.pushDelivered !== afterData.pushDelivered) return null;

    logger.info(`Triggered onOrgProjectUpdated for org: ${orgId}, project: ${projectName} (${projectId})`);

    const title = "Project Updated";
    const body = `Manager has updated the project: ${projectName}`;
    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `project_updated_${orgId}_${projectId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title,
      body,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "project_updated",
      type: "project_updated",
      projectId,
      docId: projectId,
      requestId: projectId,
      siteId,
      siteName,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/project_details",
      idempotencyKey,
      data: {
        projectId,
        projectName,
        siteId,
        siteName,
        type: "project_updated",
        actionRoute: "/project_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 10. Firestore Trigger: onOrgSiteCreated
 * Automatically fires in real-time when a site is created under /organisation/{orgId}/Site/{siteId}
 */
exports.onOrgSiteCreated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/Site/{siteId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const orgId = context.params.orgId;
    const siteId = context.params.siteId;
    const siteName = data.siteName || data.name || data.SiteName || siteId;
    const managerName = data.managerName || data.createdByName || data.updatedBy || "Manager";
    const location = data.location || data.Location || data.siteLocation || "";

    logger.info(`Triggered onOrgSiteCreated for org: ${orgId}, site: ${siteName} (${siteId})`);

    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `site_mgmt_${orgId}_${siteId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title: "🏗️ New Site Registered",
      body: `Manager ${managerName} registered Site "${siteName}" at ${location || "Site Location"}.`,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "site_management",
      type: "site_created",
      siteId,
      siteName,
      docId: siteId,
      requestId: siteId,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/site_details",
      idempotencyKey,
      data: {
        siteId,
        siteName,
        location,
        type: "site_created",
        actionRoute: "/site_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 11. Firestore Trigger: onOrgSiteUpdated
 * Automatically fires in real-time when a manager updates any site values under /organisation/{orgId}/Site/{siteId}
 */
exports.onOrgSiteUpdated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/Site/{siteId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() || {};
    const afterData = change.after.data() || {};
    const orgId = context.params.orgId;
    const siteId = context.params.siteId;
    const siteName = afterData.siteName || afterData.name || afterData.SiteName || siteId;
    const managerName = afterData.managerName || afterData.updatedBy || afterData.modifiedBy || "Manager";
    const status = afterData.currentStatus || afterData.status || "Updated";

    if (beforeData.pushDelivered !== afterData.pushDelivered) return null;

    logger.info(`Triggered onOrgSiteUpdated for org: ${orgId}, site: ${siteName} (${siteId})`);

    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `site_mgmt_${orgId}_${siteId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title: "🏗️ Site Values Updated",
      body: `Manager ${managerName} updated values for Site "${siteName}" (Status: ${status}).`,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "site_management",
      type: "site_created",
      siteId,
      siteName,
      docId: siteId,
      requestId: siteId,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/site_details",
      idempotencyKey,
      data: {
        siteId,
        siteName,
        status,
        type: "site_created",
        actionRoute: "/site_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 12. Firestore Trigger: onOrgLowerSiteUpdated
 * Handles /organisation/{orgId}/sites/{siteId} lowercase collection path
 */
exports.onOrgLowerSiteUpdated = functions.region("us-central1").firestore
  .document("organisation/{orgId}/sites/{siteId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() || {};
    const afterData = change.after.data() || {};
    const orgId = context.params.orgId;
    const siteId = context.params.siteId;
    const siteName = afterData.siteName || afterData.name || afterData.SiteName || siteId;
    const managerName = afterData.managerName || afterData.updatedBy || afterData.modifiedBy || "Manager";
    const status = afterData.currentStatus || afterData.status || "Updated";

    if (beforeData.pushDelivered !== afterData.pushDelivered) return null;

    logger.info(`Triggered onOrgLowerSiteUpdated for org: ${orgId}, site: ${siteName} (${siteId})`);

    const timeBucket = Math.floor(Date.now() / 25000);
    const idempotencyKey = `site_mgmt_${orgId}_${siteId}_${timeBucket}`;

    return processNotificationAndSendPush({
      title: "🏗️ Site Values Updated",
      body: `Manager ${managerName} updated values for Site "${siteName}" (Status: ${status}).`,
      targetRole: "organisation",
      targetRoles: ["organisation"],
      requestType: "site_management",
      type: "site_created",
      siteId,
      siteName,
      docId: siteId,
      requestId: siteId,
      orgId,
      forOrgId: orgId,
      senderRole: "Manager",
      senderName: managerName,
      actionRoute: "/site_details",
      idempotencyKey,
      data: {
        siteId,
        siteName,
        status,
        type: "site_created",
        actionRoute: "/site_details",
        idempotencyKey,
      },
    }, null);
  });

/**
 * 13. Callable Cloud Function: sendPushNotification
 * Allows authorized client calls to trigger direct push notifications
 */
exports.sendPushNotification = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const result = await processNotificationAndSendPush(payload, null);
    return { success: true, ...result };
  } catch (err) {
    logger.error("sendPushNotification error:", err);
    throw new HttpsError("internal", err.message || "Failed to dispatch push notification");
  }
});

/**
 * Core processor for scheduled notifications.
 * Scans /scheduled_notifications for due items, delivers push, updates in-app records,
 * and handles recurring (daily/weekly) schedules with atomic write locks.
 */
async function executeScheduledNotificationsScan() {
  const db = admin.firestore();
  const now = new Date();
  const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

  logger.info(`Starting scheduled notifications scan at: ${now.toISOString()}`);

  try {
    const querySnap = await db.collection("scheduled_notifications")
      .where("status", "==", "pending")
      .where("scheduledAt", "<=", nowTimestamp)
      .limit(50)
      .get();

    if (querySnap.empty) {
      logger.info("No due scheduled notifications found.");
      return { processed: 0 };
    }

    logger.info(`Found ${querySnap.size} scheduled notification(s) due for delivery.`);
    let processedCount = 0;

    for (const doc of querySnap.docs) {
      const data = doc.data();
      const docRef = doc.ref;

      // Atomic lock: claim document to prevent duplicate execution
      const claimed = await db.runTransaction(async (transaction) => {
        const freshDoc = await transaction.get(docRef);
        if (!freshDoc.exists || freshDoc.data().status !== "pending") {
          return false;
        }
        transaction.update(docRef, {
          status: "processing",
          processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!claimed) {
        logger.info(`Skipping doc ${doc.id}, already claimed by another worker.`);
        continue;
      }

      try {
        // 1. Send FCM Push Notification
        await processNotificationAndSendPush(data, null);

        // 2. Also write an in-app notification record so it appears in notification lists
        const inAppRecord = {
          app_id: data.app_id || "cst-app",
          title: data.title,
          body: data.body,
          targetRole: data.targetRole || "all",
          forSupervisorName: data.forSupervisorName || null,
          forSupervisorId: data.forSupervisorId || null,
          forManagerName: data.forManagerName || null,
          forOrgId: data.orgId || data.forOrgId || "",
          orgId: data.orgId || data.forOrgId || "",
          requestType: data.requestType || "scheduled_alert",
          requestId: data.id || doc.id,
          docId: data.id || doc.id,
          siteId: data.siteId || "",
          siteName: data.siteName || "",
          status: "scheduled_delivered",
          senderRole: data.createdByRole || "System",
          senderName: data.createdByName || "eBricks Automated Schedule",
          isRead: false,
          isScheduled: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: data.data || {},
        };

        await db.collection("notifications").add(inAppRecord);

        if (data.orgId && data.orgId !== "uninitialized") {
          await db.collection("organisation").doc(data.orgId).collection("notifications").add(inAppRecord);
        }

        // 3. Handle Recurring Reschedule or Completion
        const repeat = (data.repeat || "none").toLowerCase();
        const deliveredCount = (data.deliveredCount || 0) + 1;

        if (repeat === "daily") {
          // Schedule for next day same time
          const currentSched = data.scheduledAt ? data.scheduledAt.toDate() : now;
          const nextDate = new Date(currentSched.getTime() + 24 * 60 * 60 * 1000);
          // If nextDate is still in the past, push it to tomorrow from now
          const targetDate = nextDate <= now ? new Date(now.getTime() + 24 * 60 * 60 * 1000) : nextDate;

          await docRef.update({
            status: "pending",
            scheduledAt: admin.firestore.Timestamp.fromDate(targetDate),
            lastDeliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredCount: deliveredCount,
          });
          logger.info(`Daily schedule ${doc.id} rescheduled to: ${targetDate.toISOString()}`);
        } else if (repeat === "weekly") {
          // Schedule for next week same time
          const currentSched = data.scheduledAt ? data.scheduledAt.toDate() : now;
          const nextDate = new Date(currentSched.getTime() + 7 * 24 * 60 * 60 * 1000);
          const targetDate = nextDate <= now ? new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) : nextDate;

          await docRef.update({
            status: "pending",
            scheduledAt: admin.firestore.Timestamp.fromDate(targetDate),
            lastDeliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredCount: deliveredCount,
          });
          logger.info(`Weekly schedule ${doc.id} rescheduled to: ${targetDate.toISOString()}`);
        } else {
          // One-time schedule completed
          await docRef.update({
            status: "delivered",
            deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            lastDeliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredCount: deliveredCount,
          });
          logger.info(`One-time schedule ${doc.id} marked as delivered.`);
        }

        processedCount++;
      } catch (sendErr) {
        logger.error(`Failed to execute schedule ${doc.id}:`, sendErr);
        await docRef.update({
          status: "failed",
          lastError: sendErr.message || "Execution error",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
      }
    }

    return { processed: processedCount };
  } catch (err) {
    logger.error("executeScheduledNotificationsScan error:", err);
    throw err;
  }
}

/**
 * 7. Scheduled Cron Trigger: processScheduledNotifications
 * Automatically executes every 5 minutes (Asia/Kolkata) to process due scheduled notifications
 */
exports.processScheduledNotifications = functions.region("us-central1")
  .pubsub.schedule("every 5 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    logger.info("Executing scheduled cron job: processScheduledNotifications");
    const result = await executeScheduledNotificationsScan();
    logger.info("Cron job result:", result);
    return null;
  });

/**
 * 8. Callable Cloud Function: triggerScheduledNotifications
 * Allows instant manual/client triggering of the scheduled notifications worker
 */
exports.triggerScheduledNotifications = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const result = await executeScheduledNotificationsScan();
    return { success: true, ...result };
  } catch (err) {
    logger.error("triggerScheduledNotifications callable error:", err);
    throw new HttpsError("internal", err.message || "Failed to run scheduled notifications scan");
  }
});

// =============================================================================
// SUBSCRIPTION EXPIRY REMINDER ENGINE (2 DAYS PRIOR TO EXPIRY)
// =============================================================================

/**
 * Scans all active subscriptions across organizations and dispatches
 * expiry reminder emails for subscriptions that are 2 days away from expiry.
 * 
 * Rules:
 * - Checks active subscriptions only (isSubscriptionActive === true)
 * - Fires when 2 days away from expiry (0 < diffDays <= 2.05)
 * - Sent only once for each subscription expiry period (checks lastExpiryReminderSentForEndDate)
 * - Does not send duplicate emails
 * - If subscription renewed or extended, old reminder is not sent
 * - Expired subscriptions (diffDays <= 0) do not receive reminders
 */
async function executeSubscriptionExpiryScan(db) {
  const now = new Date();
  logger.info(`Starting subscription expiry reminder scan at: ${now.toISOString()}`);

  let scannedCount = 0;
  let remindersSent = 0;
  let skippedCount = 0;

  try {
    const orgsSnap = await db.collection("organisation").get();
    scannedCount = orgsSnap.docs.length;

    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      if (!orgId || orgId === "uninitialized") continue;

      try {
        const subRef = orgDoc.ref.collection("data").doc("subscription");
        const subSnap = await subRef.get();
        if (!subSnap.exists) continue;

        const subData = subSnap.data() || {};
        const isSubscriptionActive = subData.isSubscriptionActive === true;
        if (!isSubscriptionActive) continue;

        const endDateTimestamp = subData.subscriptionEndDate;
        if (!endDateTimestamp || typeof endDateTimestamp.toDate !== "function") continue;

        const endDate = endDateTimestamp.toDate();
        const diffMs = endDate.getTime() - now.getTime();
        const diffDays = diffMs / (1000 * 60 * 60 * 24);

        // 1. Expired subscriptions must NOT receive reminders
        if (diffMs <= 0 || diffDays <= 0) {
          skippedCount++;
          continue;
        }

        // 2. Only target subscriptions that are 2 days away (e.g. <= 2.05 days and > 0 days)
        if (diffDays > 2.05) {
          // Expiry is more than 2 days away
          continue;
        }

        // 3. Prevent duplicate reminders for the same expiry period
        const endDateIso = endDate.toISOString();
        if (subData.lastExpiryReminderSentForEndDate === endDateIso) {
          logger.info(`Org ${orgId} has already received 2-day reminder for period ending ${endDateIso}. Skipping duplicate.`);
          skippedCount++;
          continue;
        }

        // 4. Resolve registered user email
        let payerEmail = (subData.payerEmail || "").trim();
        let payerName = subData.payerName || "Customer";
        let orgName = "Organization Workspace";

        const orgData = orgDoc.data() || {};
        orgName = orgData.org_name || orgData.name || orgName;
        if (!payerEmail && orgData.email) {
          payerEmail = orgData.email.trim();
        }

        if (!payerEmail || payerName === "Customer") {
          const adminDoc = await orgDoc.ref.collection("data").doc("admin").get().catch(() => null);
          if (adminDoc && adminDoc.exists) {
            const adminData = adminDoc.data() || {};
            if (!payerEmail && adminData.email) {
              payerEmail = adminData.email.trim();
            }
            if (adminData.username && payerName === "Customer") {
              payerName = adminData.username;
            }
          }
        }

        if (!payerEmail || !emailService.isValidEmail(payerEmail)) {
          logger.warn(`No valid email found to send expiry reminder for org ${orgId}`);
          skippedCount++;
          continue;
        }

        const daysRemaining = Math.max(1, Math.ceil(diffDays));
        const planName = subData.subscriptionPlan || "Subscription";

        logger.info(`Sending 2-day expiry reminder to ${emailService.maskEmail(payerEmail)} for org ${orgId} (Expires in ${daysRemaining} days on ${endDateIso})`);

        const emailResult = await emailService.sendSubscriptionExpiryReminder({
          orgId,
          payerEmail,
          payerName,
          orgName,
          planName: planName.toUpperCase(),
          expiryDate: endDate,
          daysRemaining,
        }, db);

        if (emailResult && emailResult.success) {
          remindersSent++;
        }
      } catch (orgErr) {
        logger.warn(`Error checking expiry for org ${orgDoc.id}:`, orgErr.message || orgErr);
      }
    }

    logger.info(`Subscription expiry scan completed. Scanned: ${scannedCount}, Reminders Sent: ${remindersSent}, Skipped: ${skippedCount}`);
    return {
      scanned: scannedCount,
      remindersSent,
      skipped: skippedCount,
      timestamp: now.toISOString(),
    };
  } catch (err) {
    logger.error("executeSubscriptionExpiryScan fatal error:", err);
    throw err;
  }
}

/**
 * 9. Scheduled Cron Trigger: checkSubscriptionExpiryReminders
 * Runs daily at 9:00 AM (Asia/Kolkata) to check active subscriptions
 * and send 2-day expiry reminders automatically.
 */
exports.checkSubscriptionExpiryReminders = functions.region("us-central1")
  .pubsub.schedule("0 9 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    logger.info("Executing scheduled cron job: checkSubscriptionExpiryReminders");
    const result = await executeSubscriptionExpiryScan(admin.firestore());
    logger.info("checkSubscriptionExpiryReminders completed:", result);
    return null;
  });

/**
 * 10. Callable Cloud Function: triggerSubscriptionExpiryCheck
 * Allows manual or test triggering of the subscription expiry reminder worker on-demand
 */
exports.triggerSubscriptionExpiryCheck = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    logger.info("Manual trigger requested for triggerSubscriptionExpiryCheck");
    const result = await executeSubscriptionExpiryScan(admin.firestore());
    return { success: true, ...result };
  } catch (err) {
    logger.error("triggerSubscriptionExpiryCheck callable error:", err);
    throw new HttpsError("internal", err.message || "Failed to execute subscription expiry scan");
  }
});



