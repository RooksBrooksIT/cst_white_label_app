try {
  require("dotenv").config();
} catch (_) {}

const nodemailer = require("nodemailer");
const functions = require("firebase-functions");
const logger = functions.logger;

/**
 * Mask email address for safe logging
 * e.g. "john.doe@example.com" -> "j***e@example.com"
 */
function maskEmail(email) {
  if (!email || typeof email !== "string") return "unknown";
  const parts = email.trim().split("@");
  if (parts.length !== 2) return "***";
  const [user, domain] = parts;
  if (user.length <= 2) {
    return `${user[0]}***@${domain}`;
  }
  return `${user[0]}***${user[user.length - 1]}@${domain}`;
}

/**
 * Validate email format
 */
function isValidEmail(email) {
  if (!email || typeof email !== "string") return false;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email.trim());
}

/**
 * Email Service Configuration
 */
function getEmailConfig() {
  const host = process.env.EMAIL_HOST || "smtp.gmail.com";
  const port = parseInt(process.env.EMAIL_PORT || "587", 10);
  const secure = process.env.EMAIL_SECURE === "true" || port === 465;
  const user = (process.env.EMAIL_USER || "support@rookstechnologies.com").trim();
  const password = (process.env.EMAIL_PASSWORD || "").trim();
  const from = (process.env.EMAIL_FROM || `Rooks & Brooks Support <${user}>`).trim();
  const mockMode = process.env.EMAIL_MOCK_MODE === "true";

  return {
    host,
    port,
    secure,
    user,
    password,
    from,
    mockMode,
  };
}

/**
 * Initialize Nodemailer SMTP Transporter
 */
let _cachedTransporter = null;

function getTransporter() {
  const config = getEmailConfig();

  if (config.mockMode) {
    logger.warn("Email service is running in MOCK MODE (EMAIL_MOCK_MODE=true). No real emails will be delivered.");
  }

  if (!config.user || !config.password) {
    if (!config.mockMode) {
      logger.error("Email configuration error: EMAIL_USER or EMAIL_PASSWORD is missing in backend environment.");
    }
  }

  if (!_cachedTransporter) {
    _cachedTransporter = nodemailer.createTransport({
      host: config.host,
      port: config.port,
      secure: config.secure, // true for 465, false for 587 (STARTTLS)
      auth: {
        user: config.user,
        pass: config.password,
      },
      tls: {
        rejectUnauthorized: true,
      },
      connectionTimeout: 10000, // 10s
      greetingTimeout: 10000,
      socketTimeout: 15000,
    });
  }

  return _cachedTransporter;
}

/**
 * Verify SMTP Connection
 */
async function verifyConnection() {
  const config = getEmailConfig();

  if (config.mockMode) {
    return {
      success: true,
      mock: true,
      message: "Email service in mock mode",
    };
  }

  if (!config.user || !config.password) {
    const errorMsg = "SMTP credentials not configured (EMAIL_USER or EMAIL_PASSWORD missing)";
    logger.error("Email service initialization failed:", errorMsg);
    return {
      success: false,
      error: errorMsg,
    };
  }

  try {
    const transporter = getTransporter();
    await transporter.verify();
    logger.info("Email service initialized successfully. SMTP connection verified for:", maskEmail(config.user));
    return {
      success: true,
      host: config.host,
      port: config.port,
      user: maskEmail(config.user),
    };
  } catch (err) {
    logger.error("Email service initialization failed. Reason:", err.message || err);
    return {
      success: false,
      error: err.message || "SMTP connection verification failed",
    };
  }
}

/**
 * Core sendEmail function
 *
 * @param {Object} options
 * @param {string} options.to - Recipient email
 * @param {string} options.subject - Email subject
 * @param {string} options.html - HTML body
 * @param {string} [options.text] - Plain text fallback
 * @param {string} [options.from] - Optional sender override
 */
async function sendEmail({ to, subject, html, text }) {
  // 1. Validate recipient
  if (!to || !isValidEmail(to)) {
    const err = `Invalid recipient email address: ${to}`;
    logger.error("sendEmail failed:", err);
    return { success: false, error: err };
  }

  // 2. Validate subject
  if (!subject || typeof subject !== "string" || subject.trim().length === 0) {
    const err = "Email subject is required";
    logger.error("sendEmail failed:", err);
    return { success: false, error: err };
  }

  // 3. Validate body
  if (!html && !text) {
    const err = "Email body (HTML or plain text) is required";
    logger.error("sendEmail failed:", err);
    return { success: false, error: err };
  }

  const config = getEmailConfig();

  // Handle Mock Mode explicitly (never silently mock if EMAIL_MOCK_MODE is false)
  if (config.mockMode) {
    logger.warn(`MOCK EMAIL SENT -> To: ${maskEmail(to)}, Subject: "${subject}"`);
    return {
      success: true,
      mock: true,
      messageId: `mock-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
    };
  }

  // 4. Verify credentials exist
  if (!config.user || !config.password) {
    const err = "Backend email configuration error: EMAIL_USER or EMAIL_PASSWORD not set.";
    logger.error("sendEmail failed:", err);
    return { success: false, error: err };
  }

  // 5. Send via SMTP
  try {
    const transporter = getTransporter();
    logger.info(`Sending email to ${maskEmail(to)} | Subject: "${subject}"`);

    const mailOptions = {
      from: config.from,
      to: to.trim(),
      subject: subject.trim(),
      html: html,
      text: text || html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(),
    };

    const info = await transporter.sendMail(mailOptions);
    logger.info(`Email provider accepted message for ${maskEmail(to)}. Message ID: ${info.messageId}`);

    return {
      success: true,
      messageId: info.messageId,
      accepted: info.accepted,
      response: info.response,
    };
  } catch (err) {
    // Safe logging - never log credentials
    logger.error(`Failed to deliver email to ${maskEmail(to)}. Error:`, err.message || err);
    return {
      success: false,
      error: err.message || "Failed to send email through SMTP provider",
    };
  }
}

/**
 * HTML Template: Test Email
 */
function renderTestEmailHtml({ to, timestamp, environment }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>eBricks Email Service Test</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0d1b2a; margin: 0; padding: 24px; color: #f8fafc; }
    .container { max-width: 540px; margin: 0 auto; background: #1b2a47; border-radius: 16px; border: 1px solid rgba(255,255,255,0.1); overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.4); }
    .header { background: linear-gradient(135deg, #1e3a8a, #2563eb); padding: 32px 24px; text-align: center; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px; }
    .header p { margin: 8px 0 0; font-size: 13px; color: #bfdbfe; }
    .content { padding: 28px 24px; }
    .badge { display: inline-block; background: rgba(16,185,129,0.2); border: 1px solid #10b981; color: #10b981; font-weight: 700; font-size: 12px; padding: 4px 12px; border-radius: 20px; margin-bottom: 16px; }
    .info-card { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 16px; margin: 20px 0; }
    .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 13px; }
    .info-row:last-child { border-bottom: none; }
    .label { color: #94a3b8; }
    .value { color: #f8fafc; font-weight: 600; text-align: right; }
    .footer { padding: 20px 24px; text-align: center; border-top: 1px solid rgba(255,255,255,0.06); font-size: 12px; color: #64748b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>eBricks Email Service</h1>
      <p>Gmail SMTP Integration Verification</p>
    </div>
    <div class="content">
      <div style="text-align: center;">
        <span class="badge">✓ SMTP CONNECTION VERIFIED</span>
      </div>
      <p style="font-size: 14px; line-height: 1.6; color: #cbd5e1; text-align: center; margin: 12px 0 24px;">
        This is a test email confirming that the <strong>eBricks</strong> email service is correctly configured and successfully delivering live messages through Gmail SMTP.
      </p>
      
      <div class="info-card">
        <div class="info-row">
          <span class="label">Sender Account</span>
          <span class="value">support@rookstechnologies.com</span>
        </div>
        <div class="info-row">
          <span class="label">Recipient</span>
          <span class="value">${to}</span>
        </div>
        <div class="info-row">
          <span class="label">Environment</span>
          <span class="value">${environment || "production"}</span>
        </div>
        <div class="info-row">
          <span class="label">Timestamp</span>
          <span class="value">${timestamp || new Date().toUTCString()}</span>
        </div>
      </div>
    </div>
    <div class="footer">
      &copy; ${new Date().getFullYear()} Rooks &amp; Brooks Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>`;
}

/**
 * HTML Template: Subscription Invoice / Payment Receipt
 */
function renderInvoiceHtml(data) {
  const {
    customerName = "Valued Customer",
    orgName = "Organization Workspace",
    invoiceNo = "INV-" + Date.now(),
    planName = "Silver",
    planType = "Monthly",
    amount = "0.00",
    paymentMethod = "UPI / Card",
    txnid = "N/A",
    payuMoneyId = "Confirmed by PayU",
    paymentDate = new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }),
    startDate = "Today",
    endDate = "30 Days",
  } = data;

  const numAmount = parseFloat(amount || 0);
  const isFreeTrial = planName.toLowerCase().includes("free trial") || numAmount === 0;
  const formattedAmount = numAmount.toFixed(2);
  const badgeText = isFreeTrial ? "✓ TRIAL ACTIVATED" : "✓ PAYMENT SUCCESSFUL";
  const amountSubtitle = isFreeTrial ? '<span style="font-size: 13px; color: #10b981; font-weight: 700; margin-left: 8px;">(100% Free Trial)</span>' : "";
  const effectivePaymentMethod = isFreeTrial && (paymentMethod === "UPI" || paymentMethod === "None") ? "Free Trial Activation" : paymentMethod;
  const effectivePayuId = isFreeTrial && (payuMoneyId === "Confirmed by PayU" || !payuMoneyId) ? "Complimentary Trial Access" : payuMoneyId;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Subscription Invoice - ${invoiceNo}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0d1b2a; margin: 0; padding: 24px; color: #f8fafc; }
    .container { max-width: 580px; margin: 0 auto; background: #1b2a47; border-radius: 20px; border: 1px solid rgba(255,255,255,0.1); overflow: hidden; box-shadow: 0 16px 40px rgba(0,0,0,0.45); }
    .header { background: linear-gradient(135deg, #0f172a, #1e3a8a); padding: 32px 28px; border-bottom: 1px solid rgba(255,255,255,0.08); }
    .brand-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .brand-title { font-size: 20px; font-weight: 900; color: #ffffff; letter-spacing: -0.5px; }
    .receipt-tag { background: rgba(16,185,129,0.18); border: 1px solid #10b981; color: #10b981; font-size: 11px; font-weight: 800; padding: 4px 10px; border-radius: 12px; letter-spacing: 0.5px; }
    .amount-box { background: rgba(255,255,255,0.04); border-radius: 14px; padding: 18px 22px; margin-top: 10px; }
    .amount-label { font-size: 11px; font-weight: 700; color: #94a3b8; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 4px; }
    .amount-val { font-size: 32px; font-weight: 900; color: #ffffff; }
    .content { padding: 28px; }
    .section-title { font-size: 12px; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.8px; margin: 20px 0 10px; }
    .table-details { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    .table-details td { padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.06); font-size: 13px; }
    .table-details tr:last-child td { border-bottom: none; }
    .table-label { color: #94a3b8; width: 45%; }
    .table-val { color: #f8fafc; font-weight: 600; text-align: right; }
    .highlight-card { background: rgba(37,99,235,0.1); border: 1px solid rgba(37,99,235,0.3); border-radius: 12px; padding: 16px; margin: 24px 0 16px; }
    .highlight-title { font-size: 13px; font-weight: 700; color: #93c5fd; margin: 0 0 6px; }
    .highlight-desc { font-size: 12px; color: #cbd5e1; margin: 0; line-height: 1.5; }
    .footer { padding: 24px 28px; text-align: center; border-top: 1px solid rgba(255,255,255,0.06); font-size: 12px; color: #64748b; line-height: 1.6; }
    .footer a { color: #60a5fa; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="brand-row">
        <div class="brand-title">eBricks Workspace</div>
        <span class="receipt-tag">${badgeText}</span>
      </div>
      <div class="amount-box">
        <div class="amount-label">${isFreeTrial ? "Subscription Amount" : "Total Amount Paid"}</div>
        <div class="amount-val">₹ ${formattedAmount} ${amountSubtitle}</div>
      </div>
    </div>

    <div class="content">
      <p style="font-size: 14px; color: #e2e8f0; margin: 0 0 20px; line-height: 1.5;">
        Dear <strong>${customerName}</strong>,<br>
        ${isFreeTrial 
          ? `Welcome to <strong>eBricks</strong>! Your <strong>Free Trial</strong> subscription for <strong>${orgName}</strong> has been activated successfully.`
          : `Thank you for your payment. Your subscription for <strong>${orgName}</strong> is now verified and active.`
        }
      </p>

      <div class="section-title">Invoice &amp; Subscription Details</div>
      <table class="table-details">
        <tr>
          <td class="table-label">Invoice Number</td>
          <td class="table-val">${invoiceNo}</td>
        </tr>
        <tr>
          <td class="table-label">Plan &amp; Cadence</td>
          <td class="table-val"><strong>${planName}</strong> (${planType})</td>
        </tr>
        <tr>
          <td class="table-label">Organization / Workspace</td>
          <td class="table-val">${orgName}</td>
        </tr>
        <tr>
          <td class="table-label">Reference ID / Txn</td>
          <td class="table-val" style="font-family: monospace; font-size: 12px;">${txnid}</td>
        </tr>
        <tr>
          <td class="table-label">Payment Gateway Reference</td>
          <td class="table-val" style="font-family: monospace; font-size: 12px;">${effectivePayuId}</td>
        </tr>
        <tr>
          <td class="table-label">Payment Method</td>
          <td class="table-val">${effectivePaymentMethod}</td>
        </tr>
        <tr>
          <td class="table-label">Activation / Payment Date</td>
          <td class="table-val">${paymentDate}</td>
        </tr>
        <tr>
          <td class="table-label">Subscription Valid Period</td>
          <td class="table-val">${startDate} to ${endDate}</td>
        </tr>
      </table>

      <div class="highlight-card">
        <div class="highlight-title">Your Workspace is Ready</div>
        <p class="highlight-desc">
          Your project and member limits have been configured automatically. You can now manage your sites, managers, supervisors, and progress reports seamlessly from the eBricks application.
        </p>
      </div>
    </div>

    <div class="footer">
      Need help or have questions regarding your invoice?<br>
      Contact support at <a href="mailto:support@rookstechnologies.com">support@rookstechnologies.com</a><br><br>
      &copy; ${new Date().getFullYear()} Rooks &amp; Brooks Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>`;
}

/**
 * High-level helper: Send Subscription Invoice with Firestore Idempotency & Status Tracking
 *
 * @param {Object} params
 * @param {string} params.orgId - Organisation Document ID
 * @param {string} params.txnid - Transaction ID
 * @param {string} params.payerEmail - Customer / Organisation email
 * @param {string} params.payerName - Customer name
 * @param {string} params.orgName - Organisation name
 * @param {string} params.planName - Plan name (e.g. Free Trial, Silver, Gold, Platinum)
 * @param {string} params.planType - Plan billing type (e.g. Free Trial, Monthly, 6 Months, Yearly)
 * @param {number|string} params.amount - Payment amount
 * @param {string} [params.payuMoneyId] - PayU transaction ID
 * @param {string} [params.paymentMethod] - Payment mode (UPI, Card, etc.)
 * @param {Date} [params.startDate] - Subscription start date
 * @param {Date} [params.endDate] - Subscription end date
 * @param {FirebaseFirestore.Firestore} db - Firestore admin instance
 */
async function sendSubscriptionInvoice(params, db) {
  const {
    orgId,
    txnid = `TXN-${Date.now()}`,
    payerEmail,
    payerName = "Customer",
    orgName = "Organization Workspace",
    planName = "Silver",
    planType = "Monthly",
    amount = 0,
    payuMoneyId = "Confirmed by PayU",
    paymentMethod = "UPI",
    startDate = new Date(),
    endDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  } = params;

  if (!payerEmail || !isValidEmail(payerEmail)) {
    logger.warn(`Cannot send invoice for txnid ${txnid}: invalid or missing payer email (${payerEmail})`);
    return {
      success: false,
      skipped: true,
      error: "Missing or invalid recipient email address",
    };
  }

  // 1. Check Idempotency in Firestore
  if (db && txnid) {
    try {
      const invoiceRef = db.collection("invoices").doc(txnid);
      const invoiceSnap = await invoiceRef.get();
      if (invoiceSnap.exists) {
        const invData = invoiceSnap.data() || {};
        if (invData.emailStatus === "SENT") {
          logger.info(`Invoice email already sent for txnid ${txnid} (MessageID: ${invData.emailMessageId}). Skipping duplicate.`);
          return {
            success: true,
            alreadySent: true,
            messageId: invData.emailMessageId,
          };
        }
      }
    } catch (e) {
      logger.warn("Idempotency check warning:", e.message || e);
    }
  }

  const invoiceNo = `INV-${Date.now().toString().slice(-6)}-${txnid.slice(-4)}`;
  const dateOptions = { day: "2-digit", month: "short", year: "numeric" };
  const formattedStartDate = startDate instanceof Date ? startDate.toLocaleDateString("en-IN", dateOptions) : String(startDate);
  const formattedEndDate = endDate instanceof Date ? endDate.toLocaleDateString("en-IN", dateOptions) : String(endDate);
  const formattedPaymentDate = new Date().toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

  const isFreeTrial = planName.toLowerCase().includes("free trial") || parseFloat(amount || 0) === 0;

  const html = renderInvoiceHtml({
    customerName: payerName,
    orgName: orgName || payerName,
    invoiceNo,
    planName,
    planType,
    amount,
    paymentMethod,
    txnid,
    payuMoneyId,
    paymentDate: formattedPaymentDate,
    startDate: formattedStartDate,
    endDate: formattedEndDate,
  });

  const subject = isFreeTrial
    ? `Welcome to eBricks & Subscription Invoice for ${orgName || "eBricks Workspace"}`
    : `Payment Receipt & Invoice for ${orgName || "eBricks Workspace"} (${planName} Plan)`;

  // 2. Dispatch Email
  const result = await sendEmail({
    to: payerEmail,
    subject,
    html,
  });

  // 3. Persist Delivery Audit Record in Firestore
  if (db && txnid) {
    try {
      const invoiceRecord = {
        txnid,
        orgId: orgId || "",
        invoiceNo,
        payerEmail,
        payerName,
        orgName,
        planName,
        planType,
        amount: parseFloat(amount || 0),
        payuMoneyId,
        paymentMethod,
        emailStatus: result.success ? "SENT" : "FAILED",
        emailMessageId: result.messageId || null,
        emailError: result.error || null,
        emailSentAt: result.success ? new Date() : null,
        updatedAt: new Date(),
      };

      await db.collection("invoices").doc(txnid).set(invoiceRecord, { merge: true });

      if (orgId) {
        await db.collection("organisation").doc(orgId).collection("data").doc("subscription").set({
          lastInvoice: {
            invoiceNo,
            emailStatus: result.success ? "SENT" : "FAILED",
            emailSentAt: result.success ? new Date() : null,
            emailMessageId: result.messageId || null,
          },
        }, { merge: true });
      }
    } catch (dbErr) {
      logger.warn("Failed to persist invoice audit record:", dbErr.message || dbErr);
    }
  }

  return result;
}

module.exports = {
  getEmailConfig,
  getTransporter,
  verifyConnection,
  sendEmail,
  sendSubscriptionInvoice,
  renderTestEmailHtml,
  renderInvoiceHtml,
  maskEmail,
  isValidEmail,
};
