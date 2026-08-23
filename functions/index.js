// Optional. Cloud Functions require the Blaze plan. The Flutter app now
// bootstraps the school and creates users on the client so Spark works.
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

exports.bootstrapSchool = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const schoolName = request.data.schoolName || "My School";
  const displayName = request.data.displayName || request.auth.token.email || "Admin";
  const existing = await db.collection("schools").limit(1).get();
  if (!existing.empty) {
    throw new HttpsError("already-exists", "A school is already bootstrapped.");
  }
  const schoolId = "default";
  const uid = request.auth.uid;
  await db.collection("schools").doc(schoolId).set({
    name: schoolName,
    createdAt: FieldValue.serverTimestamp(),
  });
  await getAuth().setCustomUserClaims(uid, {role: "admin", schoolId});
  const classRef = db.collection("schools").doc(schoolId).collection("classes").doc();
  await classRef.set({
    name: "10",
    section: "A",
    year: new Date().getFullYear(),
    teacherIds: [],
  });
  const studentRef = db.collection("schools").doc(schoolId).collection("students").doc();
  await studentRef.set({
    name: "Demo Student",
    classId: classRef.id,
    roll: "1",
    viewerUids: [],
  });
  await db.collection("schools").doc(schoolId).collection("users").doc(uid).set({
    email: request.auth.token.email || "",
    displayName,
    role: "admin",
    schoolId,
    classIds: [],
    studentIds: [],
  });
  return {schoolId, classId: classRef.id, studentId: studentRef.id};
});

exports.createSchoolUser = onCall(async (request) => {
  requireAdmin(request);
  const schoolId = request.auth.token.schoolId;
  const {email, password, displayName, role, classIds = [], studentIds = []} = request.data;
  if (!email || !password || !role) {
    throw new HttpsError("invalid-argument", "email, password, and role are required.");
  }
  const user = await getAuth().createUser({
    email,
    password,
    displayName: displayName || email,
  });
  await getAuth().setCustomUserClaims(user.uid, {role, schoolId});
  await db.collection("schools").doc(schoolId).collection("users").doc(user.uid).set({
    email,
    displayName: displayName || email,
    role,
    schoolId,
    classIds,
    studentIds,
  });
  return {uid: user.uid};
});

exports.setUserClaims = onCall(async (request) => {
  requireAdmin(request);
  const {uid, role, schoolId} = request.data;
  await getAuth().setCustomUserClaims(uid, {
    role,
    schoolId: schoolId || request.auth.token.schoolId,
  });
  return {ok: true};
});

async function notifyTopic(schoolId, classId, title, body) {
  const topic = classId
    ? `school_${schoolId}_class_${classId}`
    : `school_${schoolId}_all`;
  await getMessaging().send({
    topic,
    notification: {title, body},
  }).catch((error) => {
    console.error("FCM send failed", error);
  });
}

exports.onAnnouncementCreated = onDocumentCreated(
  "schools/{schoolId}/announcements/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.schoolId,
      data.audience === "all" ? null : (data.classIds || [])[0],
      data.title || "Announcement",
      data.body || "",
    );
  },
);

exports.onHomeworkCreated = onDocumentCreated(
  "schools/{schoolId}/homework/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.schoolId,
      data.classId,
      data.title || "New homework",
      data.body || "",
    );
  },
);

exports.onReportCardPublished = onDocumentCreated(
  "schools/{schoolId}/reportCards/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.schoolId,
      data.classId,
      "Report card published",
      data.examName || "A new report card is available.",
    );
  },
);

exports.onPtmBooked = onDocumentCreated(
  "schools/{schoolId}/ptmBookings/{id}",
  async (event) => {
    const data = event.data?.data() || {};
    await notifyTopic(
      event.params.schoolId,
      null,
      "PTM booking",
      "A parent-teacher meeting slot was booked.",
    );
  },
);
