// Optional. Cloud Functions require the Blaze plan. The Flutter app now
// bootstraps the institution and creates users on the client so Spark works.
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

function requireAdmin(request) {
  if (!request.auth || request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

exports.bootstrapInstitution = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const institutionName = request.data.institutionName || "My Institution";
  const displayName = request.data.displayName || request.auth.token.email || "Admin";
  const existing = await db.collection("institutions").limit(1).get();
  if (!existing.empty) {
    throw new HttpsError("already-exists", "An institution is already bootstrapped.");
  }
  const institutionId = "default";
  const uid = request.auth.uid;
  await db.collection("institutions").doc(institutionId).set({
    name: institutionName,
    createdAt: FieldValue.serverTimestamp(),
    branding: {
      displayName: institutionName,
      tagline: "",
      primaryColor: "#0F6A8A",
      logoUrl: "",
      backgroundUrl: "",
    },
  });
  await getAuth().setCustomUserClaims(uid, {role: "admin", institutionId});
  await db.collection("institutions").doc(institutionId).collection("users").doc(uid).set({
    email: request.auth.token.email || "",
    displayName,
    role: "admin",
    institutionId,
    classIds: [],
    studentIds: [],
  });
  return {institutionId};
});

exports.createInstitutionUser = onCall(async (request) => {
  requireAdmin(request);
  const institutionId = request.auth.token.institutionId;
  const {email, password, displayName, role, classIds = [], studentIds = []} = request.data;
  if (!email || !password || !role) {
    throw new HttpsError("invalid-argument", "email, password, and role are required.");
  }
  const user = await getAuth().createUser({
    email,
    password,
    displayName: displayName || email,
  });
  await getAuth().setCustomUserClaims(user.uid, {role, institutionId});
  await db.collection("institutions").doc(institutionId).collection("users").doc(user.uid).set({
    email,
    displayName: displayName || email,
    role,
    institutionId,
    classIds,
    studentIds,
  });
  return {uid: user.uid};
});

exports.setUserClaims = onCall(async (request) => {
  requireAdmin(request);
  const {uid, role, institutionId} = request.data;
  await getAuth().setCustomUserClaims(uid, {
    role,
    institutionId: institutionId || request.auth.token.institutionId,
  });
  return {ok: true};
});

async function notifyTopic(institutionId, classId, title, body) {
  const topic = classId
    ? `institution_${institutionId}_class_${classId}`
    : `institution_${institutionId}_all`;
  await getMessaging().send({
    topic,
    notification: {title, body},
  }).catch((error) => {
    console.error("FCM send failed", error);
  });
}

exports.onAnnouncementCreated = onDocumentCreated(
  "institutions/{institutionId}/announcements/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.institutionId,
      data.audience === "all" ? null : (data.classIds || [])[0],
      data.title || "Announcement",
      data.body || "",
    );
  },
);

exports.onHomeworkCreated = onDocumentCreated(
  "institutions/{institutionId}/homework/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.institutionId,
      data.classId,
      data.title || "New homework",
      data.body || "",
    );
  },
);

exports.onReportCardPublished = onDocumentCreated(
  "institutions/{institutionId}/reportCards/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.institutionId,
      data.classId,
      "Report card published",
      data.examName || "A new report card is available.",
    );
  },
);

exports.onPtmBooked = onDocumentCreated(
  "institutions/{institutionId}/ptmBookings/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.institutionId,
      null,
      "PTM booking",
      "A parent-teacher meeting slot was booked.",
    );
  },
);
