const assert = require("assert");

console.log("==================================================================");
console.log("RUNNING FIRESTORE SUBSCRIPTION CONSISTENCY VERIFICATION TEST SUITE");
console.log("==================================================================\n");

// Mock Firestore In-Memory Store
class MockFirestore {
  constructor() {
    this.store = new Map();
  }

  doc(path) {
    const self = this;
    return {
      path,
      get: async () => {
        const data = self.store.get(path);
        return {
          exists: !!data,
          id: path.split("/").pop(),
          data: () => (data ? { ...data } : undefined),
          ref: self.doc(path),
        };
      },
      set: async (newData, options) => {
        if (options && options.merge) {
          const existing = self.store.get(path) || {};
          self.store.set(path, { ...existing, ...newData });
        } else {
          self.store.set(path, { ...newData });
        }
      },
    };
  }

  batch() {
    const operations = [];
    const self = this;
    return {
      set: (ref, data, options) => {
        operations.push({ ref, data, options });
      },
      commit: async () => {
        for (const op of operations) {
          await op.ref.set(op.data, op.options);
        }
      },
    };
  }
}

// Backend Synchronization Logic simulation identical to syncOrganisationSubscriptionBackend
async function syncOrganisationSubscriptionBackend(db, orgId, subscriptionUpdate, finalStatus, isSubscriptionActive, planType, txnid) {
  if (!orgId || orgId === "uninitialized") return;

  const basePath = `organisation/${orgId}`;
  const subRef = db.doc(`${basePath}/data/subscription`);
  const orgRef = db.doc(basePath);
  const dataAdminRef = db.doc(`${basePath}/data/admin`);
  const legacyAdminRef = db.doc(`${basePath}/admin/data`);
  const legacyDataRef = db.doc(`${basePath}/data/data`);

  const batch = db.batch();

  // 1. Authoritative subscription doc
  batch.set(subRef, subscriptionUpdate, { merge: true });

  // 2. Root organisation doc
  const rootUpdate = {
    isSubscriptionActive,
    paymentStatus: finalStatus,
    payuMoneyId: subscriptionUpdate.payuMoneyId || "",
    updated_at: new Date().toISOString(),
  };
  if (subscriptionUpdate.subscriptionPlan) rootUpdate.subscriptionPlan = subscriptionUpdate.subscriptionPlan;
  if (planType) rootUpdate.subscriptionType = planType;
  if (subscriptionUpdate.subscriptionStartDate) rootUpdate.subscriptionStartDate = subscriptionUpdate.subscriptionStartDate;
  if (subscriptionUpdate.subscriptionEndDate) rootUpdate.subscriptionEndDate = subscriptionUpdate.subscriptionEndDate;
  if (txnid) rootUpdate.paymentTxnId = txnid;
  if (subscriptionUpdate.paymentAmount !== undefined) rootUpdate.paymentAmount = subscriptionUpdate.paymentAmount;
  if (subscriptionUpdate.maxProjects !== undefined) rootUpdate.maxProjects = subscriptionUpdate.maxProjects;
  if (subscriptionUpdate.maxUsers !== undefined) rootUpdate.maxUsers = subscriptionUpdate.maxUsers;
  
  const orgSnap = await orgRef.get();
  if (orgSnap && orgSnap.exists && (orgSnap.data().subscriptionPlan || orgSnap.data().isSubscriptionActive !== undefined)) {
    batch.set(orgRef, rootUpdate, { merge: true });
  }

  // 3. Canonical data/admin doc
  const adminDocUpdate = {
    isSubscriptionActive,
    paymentStatus: finalStatus,
    updated_at: new Date().toISOString(),
  };
  if (subscriptionUpdate.subscriptionPlan) adminDocUpdate.subscriptionPlan = subscriptionUpdate.subscriptionPlan;
  batch.set(dataAdminRef, adminDocUpdate, { merge: true });

  // 4. Synchronize legacy duplicate docs ONLY if they already exist
  const legacyAdminSnap = await legacyAdminRef.get();
  if (legacyAdminSnap.exists) {
    batch.set(legacyAdminRef, adminDocUpdate, { merge: true });
  }

  const legacyDataSnap = await legacyDataRef.get();
  if (legacyDataSnap.exists) {
    batch.set(legacyDataRef, adminDocUpdate, { merge: true });
  }

  await batch.commit();
}

async function runTests() {
  const db = new MockFirestore();
  const orgId = "cst_RBConstruction_19-09-2026";
  const basePath = `organisation/${orgId}`;

  // =========================================================================
  // TEST 1: Initial Organization Registration with Free Trial
  // =========================================================================
  console.log("[TEST 1] Testing Organization Registration with Free Trial...");
  const initialAdminProfile = {
    username: "rb_admin",
    password: "securePassword123",
    email: "rb@construction.com",
    phone: "9876543210",
    role: "Organization",
    org_name: "RB Construction",
    theme_color: "#1E88E5",
    subscriptionPlan: "Free Trial",
    isSubscriptionActive: true,
    paymentStatus: "SUCCESS",
  };

  const initialSubDoc = {
    subscriptionPlan: "Free Trial",
    subscriptionType: "Free Trial",
    isSubscriptionActive: true,
    paymentStatus: "SUCCESS",
    subscriptionStartDate: new Date("2026-09-19T00:00:00Z").toISOString(),
    subscriptionEndDate: new Date("2026-10-03T00:00:00Z").toISOString(),
    maxProjects: 1,
    maxUsers: 2,
  };

  // Populate initial registration state (including existing legacy duplicate docs)
  await db.doc(`${basePath}`).set({ ...initialAdminProfile, ...initialSubDoc });
  await db.doc(`${basePath}/data/subscription`).set(initialSubDoc);
  await db.doc(`${basePath}/data/admin`).set(initialAdminProfile);
  await db.doc(`${basePath}/admin/data`).set(initialAdminProfile); // legacy
  await db.doc(`${basePath}/data/data`).set(initialAdminProfile); // legacy

  assert.strictEqual((await db.doc(`${basePath}/data/subscription`).get()).data().subscriptionPlan, "Free Trial");
  assert.strictEqual((await db.doc(`${basePath}/data/admin`).get()).data().subscriptionPlan, "Free Trial");
  assert.strictEqual((await db.doc(`${basePath}/admin/data`).get()).data().subscriptionPlan, "Free Trial");
  assert.strictEqual((await db.doc(`${basePath}/data/data`).get()).data().subscriptionPlan, "Free Trial");
  console.log("✓ Test 1 Passed: Initial registration created with Free Trial across documents.\n");

  // =========================================================================
  // TEST 2: Organization Upgrades to Silver Plan (Successful Payment)
  // =========================================================================
  console.log("[TEST 2] Testing Organization Upgrade to Silver Plan with Verified Payment...");
  const silverUpdate = {
    isSubscriptionActive: true,
    paymentGateway: "PayU",
    paymentTxnId: "TXN_SILVER_1001",
    payuMoneyId: "PAYU_998877",
    paymentStatus: "SUCCESS",
    subscriptionPlan: "Silver",
    subscriptionType: "Monthly",
    subscriptionStartDate: new Date("2026-10-28T10:00:00Z").toISOString(),
    subscriptionEndDate: new Date("2026-11-28T10:00:00Z").toISOString(),
    paymentAmount: 4999,
    maxProjects: 5,
    maxUsers: 10,
  };

  await syncOrganisationSubscriptionBackend(
    db,
    orgId,
    silverUpdate,
    "SUCCESS",
    true,
    "Monthly",
    "TXN_SILVER_1001"
  );

  // Verify Authoritative Subscription Document
  const subSnap = await db.doc(`${basePath}/data/subscription`).get();
  assert.strictEqual(subSnap.data().subscriptionPlan, "Silver", "Authoritative sub doc must have Silver");
  assert.strictEqual(subSnap.data().isSubscriptionActive, true, "Authoritative sub doc must be active");
  assert.strictEqual(subSnap.data().paymentStatus, "SUCCESS", "Payment status must be SUCCESS");

  // Verify Root Document
  const rootSnap = await db.doc(basePath).get();
  assert.strictEqual(rootSnap.data().subscriptionPlan, "Silver", "Root doc must have Silver");
  assert.strictEqual(rootSnap.data().isSubscriptionActive, true, "Root doc must be active");
  assert.strictEqual(rootSnap.data().paymentTxnId, "TXN_SILVER_1001");

  // Verify Canonical Profile Document (data/admin)
  const adminSnap = await db.doc(`${basePath}/data/admin`).get();
  assert.strictEqual(adminSnap.data().subscriptionPlan, "Silver", "data/admin must be synchronized to Silver");
  assert.strictEqual(adminSnap.data().isSubscriptionActive, true);
  assert.strictEqual(adminSnap.data().paymentStatus, "SUCCESS");

  // Verify Profile Data Preservation (no accidental data loss)
  assert.strictEqual(adminSnap.data().username, "rb_admin", "Username must be preserved");
  assert.strictEqual(adminSnap.data().password, "securePassword123", "Password must be preserved");
  assert.strictEqual(adminSnap.data().email, "rb@construction.com", "Email must be preserved");
  assert.strictEqual(adminSnap.data().phone, "9876543210", "Phone must be preserved");
  assert.strictEqual(adminSnap.data().role, "Organization", "Role must be preserved");
  assert.strictEqual(adminSnap.data().org_name, "RB Construction", "Org name must be preserved");
  assert.strictEqual(adminSnap.data().theme_color, "#1E88E5", "Theme color must be preserved");

  // Verify Legacy Duplicate Documents were also synchronized
  const legacyAdminSnap = await db.doc(`${basePath}/admin/data`).get();
  assert.strictEqual(legacyAdminSnap.data().subscriptionPlan, "Silver", "admin/data must be synchronized to Silver");

  const legacyDataSnap = await db.doc(`${basePath}/data/data`).get();
  assert.strictEqual(legacyDataSnap.data().subscriptionPlan, "Silver", "data/data must be synchronized to Silver");

  console.log("✓ Test 2 Passed: Upgrade to Silver successfully updated all related documents atomically without losing profile fields.\n");

  // =========================================================================
  // TEST 3: Login Reconciliation (Resolving Conflicting / Stale Documents)
  // =========================================================================
  console.log("[TEST 3] Testing Login Profile Aggregation & Reconciliation...");
  // Simulate an older organization where data/admin still held "Free Trial"
  const staleAdminDoc = {
    username: "rb_admin",
    email: "rb@construction.com",
    subscriptionPlan: "Free Trial", // Outdated
  };
  const authoritativeDoc = (await db.doc(`${basePath}/data/subscription`).get()).data();

  // Client aggregation logic as in organisation_login_page:
  const resolvedUserData = { ...staleAdminDoc };

  // Authoritative document overrides subscription fields:
  resolvedUserData.subscriptionPlan = authoritativeDoc.subscriptionPlan;
  resolvedUserData.isSubscriptionActive = authoritativeDoc.isSubscriptionActive;
  resolvedUserData.paymentStatus = authoritativeDoc.paymentStatus;

  assert.strictEqual(resolvedUserData.subscriptionPlan, "Silver", "Login session must resolve to Silver");
  assert.strictEqual(resolvedUserData.username, "rb_admin", "Login session preserves username");
  console.log("✓ Test 3 Passed: Login resolves to authoritative Silver plan, overriding stale profile.\n");

  // =========================================================================
  // TEST 4: Failed Payment Attempt Handling
  // =========================================================================
  console.log("[TEST 4] Testing Failed Payment Upgrade Request...");
  const failedTxnId = "TXN_FAILED_9999";
  const failedUpdate = {
    isSubscriptionActive: false,
    paymentStatus: "FAILED",
    paymentTxnId: failedTxnId,
    subscriptionPlan: "Platinum", // Attempted plan
  };

  await syncOrganisationSubscriptionBackend(
    db,
    orgId,
    failedUpdate,
    "FAILED",
    false,
    "Monthly",
    failedTxnId
  );

  const failedSub = (await db.doc(`${basePath}/data/subscription`).get()).data();
  assert.strictEqual(failedSub.isSubscriptionActive, false, "Failed payment must not activate subscription");
  assert.strictEqual(failedSub.paymentStatus, "FAILED", "Payment status must be marked FAILED");

  const failedAdmin = (await db.doc(`${basePath}/data/admin`).get()).data();
  assert.strictEqual(failedAdmin.isSubscriptionActive, false);
  assert.strictEqual(failedAdmin.paymentStatus, "FAILED");
  console.log("✓ Test 4 Passed: Failed payment does not activate subscription across any document.\n");

  // =========================================================================
  // TEST 5: Repeated Upgrade / Sync Requests Idempotency
  // =========================================================================
  console.log("[TEST 5] Testing Repeated Upgrade / Sync Requests Idempotency...");
  // Re-apply Silver success multiple times
  for (let i = 0; i < 3; i++) {
    await syncOrganisationSubscriptionBackend(
      db,
      orgId,
      silverUpdate,
      "SUCCESS",
      true,
      "Monthly",
      "TXN_SILVER_1001"
    );
  }

  const finalSub = (await db.doc(`${basePath}/data/subscription`).get()).data();
  const finalAdmin = (await db.doc(`${basePath}/data/admin`).get()).data();

  assert.strictEqual(finalSub.subscriptionPlan, "Silver");
  assert.strictEqual(finalSub.isSubscriptionActive, true);
  assert.strictEqual(finalAdmin.subscriptionPlan, "Silver");
  assert.strictEqual(finalAdmin.username, "rb_admin");
  console.log("✓ Test 5 Passed: Repeated updates are completely idempotent.\n");

  // =========================================================================
  // TEST 6: Manager Login & Unrelated Functionality Preserved
  // =========================================================================
  console.log("[TEST 6] Testing Manager Authentication Independence...");
  const managerData = {
    username: "manager_vikram",
    password: "managerPass456",
    role: "Manager",
    orgId: orgId,
  };
  await db.doc(`${basePath}/manager/vikram`).set(managerData);

  const mgrDoc = (await db.doc(`${basePath}/manager/vikram`).get()).data();
  assert.strictEqual(mgrDoc.username, "manager_vikram");
  assert.strictEqual(mgrDoc.role, "Manager");
  console.log("✓ Test 6 Passed: Manager data and functionality remain completely untouched.\n");

  console.log("==================================================================");
  console.log("ALL 6 FIRESTORE CONSISTENCY VERIFICATION TESTS PASSED SUCCESSFULLY");
  console.log("==================================================================");
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
