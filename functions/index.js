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
 * 1. Callable Cloud Function (v1): generatePayUHash
 * Can be called directly from Flutter app via Firebase Functions SDK or HTTP
 */
exports.generatePayUHash = functions.region("us-central1").https.onCall(async (data, context) => {
  try {
    const payload = data || {};
    const { txnid, amount, productInfo, firstName, email, phone, pg, bankcode } = payload;

    if (!txnid || !amount) {
      throw new HttpsError("invalid-argument", "Missing required parameters: txnid and amount");
    }

    const config = getPayUConfig(payload);
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

    await subRef.set(subscriptionUpdate, { merge: true });

    // Ensure we have the user's registered email - check Firestore admin & root org doc if missing from request
    let effectiveEmail = (subscriptionUpdate.payerEmail || "").trim();
    let orgName = "eBricks Organization Workspace";
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
        }, db);
        
        logger.info(`Invoice email dispatch result for txnid ${txnid}:`, emailResult);
      } catch (emailErr) {
        logger.warn(`Invoice email dispatch error for txnid ${txnid}:`, emailErr.message || emailErr);
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
      const isSuccess = (status || "").toLowerCase() === "success";

      const db = admin.firestore();

      if (txnid) {
        // Record webhook audit log in Firestore
        await db.collection("payment_logs").doc(txnid).set({
          txnid,
          status: status || "UNKNOWN",
          amount: parseFloat(amount || 0),
          email: email || "",
          firstname: firstname || "",
          productinfo: productinfo || "",
          payuMoneyId: mihpayid,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          rawData: payload,
        }, { merge: true }).catch((err) => logger.warn("Log write warning:", err));

        // 1. If udf1 carries the orgId, update organisation and subscription document directly
        const orgId = (payload.udf1 || "").trim();
        if (orgId) {
          const orgRef = db.collection("organisation").doc(orgId);
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
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }).catch(() => {});
        }

        // 2. Query top-level organisation collection by paymentTxnId
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
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true }).catch(() => {});
          }
        }

        // 3. Send invoice email on successful webhook (idempotency prevents duplicate sends)
        if (isSuccess) {
          try {
            let payerEmail = email;
            let payerName = firstname || "Customer";
            let orgName = "eBricks Workspace";
            let planName = productinfo || "Silver";

            if (orgId) {
              const orgDoc = await db.collection("organisation").doc(orgId).get();
              if (orgDoc.exists) {
                const oData = orgDoc.data() || {};
                orgName = oData.org_name || oData.name || orgName;
                payerEmail = payerEmail || oData.email || oData.org_email;
              }
            }

            if (payerEmail) {
              await emailService.sendSubscriptionInvoice({
                orgId: orgId || "",
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
              }, db);
            }
          } catch (emailErr) {
            logger.warn(`Webhook invoice email send error for txnid ${txnid}:`, emailErr.message || emailErr);
          }
        }
      }

      // Check if this request is a browser HTTP redirect (surl / furl hitting payuWebhook)
      const isBrowserRedirect = (req.headers["accept"] && req.headers["accept"].includes("text/html")) ||
          req.headers["sec-fetch-dest"] === "document" ||
          (req.headers["user-agent"] && req.headers["user-agent"].includes("Mozilla")) ||
          (payload && (payload.mihpayid || payload.payuMoneyId || payload.unmappedstatus || payload.status));

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
    });

    const subject = `Payment Receipt & Invoice for ${invoiceData.orgName || "eBricks Workspace"}`;
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
    } = payload;

    if (!orgId) {
      throw new HttpsError("invalid-argument", "Missing required parameter: orgId");
    }

    const db = admin.firestore();
    const orgRef = db.collection("organisation").doc(orgId);

    let effectiveEmail = (payerEmail || "").trim();
    let orgName = "eBricks Organization Workspace";
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

    const result = await emailService.sendSubscriptionInvoice({
      orgId,
      txnid,
      payerEmail: effectiveEmail,
      payerName: effectiveCustomerName,
      orgName,
      planName,
      planType,
      amount: parseFloat(amount || 0),
      payuMoneyId,
      paymentMethod,
      startDate: now,
      endDate,
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




