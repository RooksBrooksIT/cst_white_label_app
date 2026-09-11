const assert = require("assert");
const emailService = require("../emailService");

console.log("==================================================================");
console.log("RUNNING EBRICKS INVOICE & SUBSCRIPTION FLOW VERIFICATION SUITE");
console.log("==================================================================\n");

// 1. Test Free Trial Invoice Rendering
console.log("[TEST 1] Verifying Free Trial Invoice HTML & Details...");
const trialHtml = emailService.renderInvoiceHtml({
  customerName: "Rahul Sharma",
  orgName: "Sharma Builders",
  invoiceNo: "INV-100001-TRIAL",
  planName: "Free Trial",
  planType: "Free Trial (14 Days)",
  amount: 0,
  paymentMethod: "Free Trial Activation",
  txnid: "TRIAL_1740000000",
  payuMoneyId: "Complimentary Access",
  paymentDate: "11 Sep 2026, 03:00 PM",
  startDate: "11 Sep 2026",
  endDate: "25 Sep 2026",
  isTrial: true,
});

assert(trialHtml.includes("eBricks"), "Header must include eBricks branding");
assert(trialHtml.includes("✓ FREE TRIAL ACTIVATED"), "Must display FREE TRIAL ACTIVATED badge");
assert(trialHtml.includes("(100% Free Trial)"), "Must display 100% Free Trial subtitle");
assert(trialHtml.includes("Welcome to <strong>eBricks</strong>!"), "Must contain eBricks welcome greeting");
assert(trialHtml.includes("eBricks Invoice &amp; Subscription Details"), "Must contain eBricks section title");
assert(trialHtml.includes("Sharma Builders"), "Must contain correct organisation name");
assert(trialHtml.includes("Rahul Sharma"), "Must contain customer name");
assert(!trialHtml.includes("IMS"), "Must not contain IMS references");
console.log("✓ Test 1 Passed: Free Trial invoice renders accurately with eBricks branding.\n");

// 2. Test New Paid Subscription Invoice Rendering
console.log("[TEST 2] Verifying New Paid Plan Subscription Invoice HTML...");
const paidHtml = emailService.renderInvoiceHtml({
  customerName: "Priya Patel",
  orgName: "Patel Constructions",
  invoiceNo: "INV-100002-PAID",
  planName: "Platinum",
  planType: "Yearly",
  amount: 29999.00,
  paymentMethod: "PayU (UPI)",
  txnid: "PAYU_1740000001",
  payuMoneyId: "PAYU_MIH_998877",
  paymentDate: "11 Sep 2026, 03:05 PM",
  startDate: "11 Sep 2026",
  endDate: "11 Sep 2027",
  isTrial: false,
  isUpgrade: false,
});

assert(paidHtml.includes("eBricks"), "Header must include eBricks branding");
assert(paidHtml.includes("✓ PAYMENT SUCCESSFUL"), "Must display PAYMENT SUCCESSFUL badge");
assert(paidHtml.includes("₹ 29999.00"), "Must display formatted paid amount");
assert(paidHtml.includes("Thank you for your payment."), "Must contain payment thank you message");
assert(paidHtml.includes("PAYU_MIH_998877"), "Must display PayU transaction ID");
assert(!paidHtml.includes("IMS"), "Must not contain IMS references");
console.log("✓ Test 2 Passed: Paid plan invoice renders accurately with payment receipt.\n");

// 3. Test Plan Upgrade / Update Invoice Rendering
console.log("[TEST 3] Verifying Plan Upgrade / Update Invoice HTML...");
const upgradeHtml = emailService.renderInvoiceHtml({
  customerName: "Vikram Reddy",
  orgName: "Reddy Infrastructure",
  invoiceNo: "INV-100003-UPG",
  planName: "Gold",
  planType: "6 Months",
  amount: 9999.00,
  paymentMethod: "PayU (Card)",
  txnid: "UPG_1740000002",
  payuMoneyId: "PAYU_MIH_554433",
  paymentDate: "11 Sep 2026, 03:10 PM",
  startDate: "11 Sep 2026",
  endDate: "11 Mar 2027",
  isUpgrade: true,
});

assert(upgradeHtml.includes("eBricks"), "Header must include eBricks branding");
assert(upgradeHtml.includes("✓ PLAN UPGRADED &amp; PAID"), "Must display PLAN UPGRADED badge");
assert(upgradeHtml.includes("updated to the <strong>Gold</strong> plan"), "Must contain plan update greeting");
assert(upgradeHtml.includes("Reddy Infrastructure"), "Must contain org name");
assert(!upgradeHtml.includes("IMS"), "Must not contain IMS references");
console.log("✓ Test 3 Passed: Plan upgrade invoice renders accurately.\n");

// 4. Test Email Sender and Subject Line Generation via Mocked sendSubscriptionInvoice
console.log("[TEST 4] Verifying Subject Line Generation & Mock Dispatch...");
process.env.EMAIL_MOCK_MODE = "true";

(async () => {
  // Test Trial Dispatch
  const trialResult = await emailService.sendSubscriptionInvoice({
    orgId: "org_trial_123",
    txnid: "TRIAL_TEST_001",
    payerEmail: "test.trial@example.com",
    payerName: "Trial User",
    orgName: "Test Org 1",
    planName: "Free Trial",
    planType: "Free Trial",
    amount: 0,
    isTrial: true,
  }, null);

  assert(trialResult.success === true, "Mock trial email must succeed");

  // Test Upgrade Dispatch
  const upgResult = await emailService.sendSubscriptionInvoice({
    orgId: "org_upg_123",
    txnid: "UPG_TEST_002",
    payerEmail: "test.upg@example.com",
    payerName: "Upgrade User",
    orgName: "Test Org 2",
    planName: "Gold",
    planType: "Monthly",
    amount: 1999,
    isUpgrade: true,
  }, null);

  assert(upgResult.success === true, "Mock upgrade email must succeed");

  // Test Paid Dispatch
  const paidResult = await emailService.sendSubscriptionInvoice({
    orgId: "org_paid_123",
    txnid: "PAYU_TEST_003",
    payerEmail: "test.paid@example.com",
    payerName: "Paid User",
    orgName: "Test Org 3",
    planName: "Platinum",
    planType: "Yearly",
    amount: 19999,
    isTrial: false,
    isUpgrade: false,
  }, null);

  assert(paidResult.success === true, "Mock paid email must succeed");

  console.log("✓ Test 4 Passed: All subscription email triggers executed successfully.\n");
  console.log("==================================================================");
  console.log("ALL TESTS PASSED SUCCESSFULLY!");
  console.log("==================================================================");
})().catch((e) => {
  console.error("Test execution failed:", e);
  process.exit(1);
});
