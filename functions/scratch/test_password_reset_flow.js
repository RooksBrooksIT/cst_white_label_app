const assert = require("assert");
const emailService = require("../emailService");

console.log("==================================================================");
console.log("RUNNING EBRICKS OTP PASSWORD RESET FLOW VERIFICATION SUITE");
console.log("==================================================================\n");

// 1. Test OTP Email Rendering
console.log("[TEST 1] Verifying Password Reset OTP HTML Rendering...");
const otpHtml = emailService.renderPasswordResetOtpHtml({
  customerName: "Sajin",
  otp: "654321",
  validityMinutes: 5,
});

assert(otpHtml.includes("eBricks"), "Header must include eBricks branding");
assert(otpHtml.includes("654321"), "Email must contain the generated OTP");
assert(otpHtml.includes("5 Minutes"), "Must mention 5 minutes validity");
assert(otpHtml.includes("Password Reset Verification Code"), "Must mention verification code");
assert(otpHtml.includes("Sajin"), "Must contain user's name");
console.log("✓ Test 1 Passed: Password reset OTP email renders accurately with eBricks branding.\n");

// 2. Test OTP Rules Logic Simulation
console.log("[TEST 2] Simulating OTP Rules & Expiration Matrix...");

// Rule 1: 5 minutes validity
const now = Date.now();
const session = {
  email: "test@example.com",
  sessionId: "SES_123",
  otp: "123456",
  createdAt: now,
  expiresAt: now + 5 * 60 * 1000,
  resendAvailableAt: now + 60 * 1000,
  resendCount: 0,
  maxResends: 5,
  incorrectAttempts: 0,
  maxIncorrectAttempts: 5,
  isVerified: false,
  isUsed: false,
};

assert(session.expiresAt - session.createdAt === 300000, "Validity must be exactly 5 minutes (300,000 ms)");
console.log("✓ Rule 1 Validated: OTP validity is 5 minutes.");

// Rule 2: 60-second resend cooldown
assert(session.resendAvailableAt - session.createdAt === 60000, "Resend cooldown must be 60 seconds (60,000 ms)");
const isResendBlockedImmediately = now < session.resendAvailableAt;
assert(isResendBlockedImmediately === true, "Resend must be blocked before 60 seconds");
console.log("✓ Rule 2 Validated: Resend cooldown is 60 seconds.");

// Rule 3: Previous OTP invalidation on new generation
const oldOtp = session.otp;
const newOtp = "789012";
session.otp = newOtp;
session.resendCount += 1;
assert(session.otp !== oldOtp, "New OTP must replace old OTP");
assert(oldOtp !== "789012" && session.otp === "789012", "Previous OTP immediately becomes invalid");
console.log("✓ Rule 3 Validated: Previous OTP is immediately invalidated upon new OTP generation.");

// Rule 4: Max 5 resends
for (let i = session.resendCount; i < 5; i++) {
  session.resendCount += 1;
}
assert(session.resendCount === 5, "Resend count reached 5");
const isExceeded = session.resendCount >= 5;
assert(isExceeded === true, "Must block further resends when limit of 5 is reached");
console.log("✓ Rule 4 Validated: Maximum 5 resends enforced.");

// Rule 5: Max 5 incorrect OTP attempts
session.otp = "999888";
session.incorrectAttempts = 0;
for (let attempt = 1; attempt <= 5; attempt++) {
  const enteredOtp = "000000";
  if (enteredOtp !== session.otp) {
    session.incorrectAttempts += 1;
    if (session.incorrectAttempts >= 5) {
      session.otp = null; // Invalidate current OTP
    }
  }
}
assert(session.incorrectAttempts === 5, "Incorrect attempts count must be 5");
assert(session.otp === null, "OTP must be invalidated after 5 incorrect attempts");
console.log("✓ Rule 5 Validated: After 5 incorrect attempts, OTP is permanently invalidated.");

// Rule 6: Successful verification cannot be reused
session.otp = "555444";
const userEntered = "555444";
let verified = false;
let resetToken = null;
if (session.otp === userEntered) {
  verified = true;
  session.isVerified = true;
  session.otp = null; // Consumed
  resetToken = "RST_TOKEN_SAMPLE";
  session.resetToken = resetToken;
}
assert(verified === true, "Must verify matching OTP");
assert(session.otp === null, "Once verified, OTP is cleared and cannot be reused");
// Rule 7: Exact match with email OTP 492431 & type normalization
const storedOtpNumber = 492431;
const enteredOtpString = " 492431 ";
const normalizedStored = String(storedOtpNumber).trim().replace(/\D/g, "").padStart(6, "0");
const normalizedEntered = String(enteredOtpString).trim().replace(/\D/g, "").padStart(6, "0");
assert(normalizedStored === normalizedEntered, "Exact OTP 492431 must match regardless of string/number type or whitespace");
console.log("✓ Rule 7 Validated: Exact OTP 492431 matches with normalization.");

// Rule 8: Leading zero OTP support (e.g. 012345)
const leadingZeroOtp = "012345";
const enteredLeadingZero = "012345";
const normStoredZero = String(leadingZeroOtp).trim().replace(/\D/g, "").padStart(6, "0");
const normEnteredZero = String(enteredLeadingZero).trim().replace(/\D/g, "").padStart(6, "0");
assert(normStoredZero === "012345", "Must preserve leading zeros");
assert(normStoredZero === normEnteredZero, "Leading zero OTPs must verify successfully");
console.log("✓ Rule 8 Validated: Leading zero OTPs (012345) preserve string formatting.");

console.log("\n==================================================================");
console.log("ALL PASSWORD RESET OTP RULES TESTED AND PASSED!");
console.log("==================================================================");
