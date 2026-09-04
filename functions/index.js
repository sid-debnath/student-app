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
    mustChangePassword: false,
  });
  return {institutionId};
});

exports.createInstitutionUser = onCall(async (request) => {
  requireAdmin(request);
  const institutionId = request.auth.token.institutionId || "default";
  const {
    email,
    password,
    displayName,
    role,
    classIds = [],
    studentIds = [],
    fatherPhone = "",
    motherPhone = "",
    alternativePhone = "",
    viewerAccountType = null,
  } = request.data;
  if (!email || !password || !role) {
    throw new HttpsError("invalid-argument", "email, password, and role are required.");
  }
  let user;
  try {
    user = await getAuth().createUser({
      email,
      password,
      displayName: displayName || email,
    });
  } catch (error) {
    if (error.code !== "auth/email-already-exists") {
      throw error;
    }
    // Re-enroll after a Firestore-only delete: reset password and reuse uid.
    const existing = await getAuth().getUserByEmail(email);
    await getAuth().updateUser(existing.uid, {
      password,
      displayName: displayName || email,
      disabled: false,
    });
    user = await getAuth().getUser(existing.uid);
  }
  await getAuth().setCustomUserClaims(user.uid, {role, institutionId});
  const profile = {
    email,
    displayName: displayName || email,
    role,
    institutionId,
    classIds,
    studentIds,
    mustChangePassword: role === "teacher" || role === "viewer",
  };
  if (viewerAccountType === "parent" || viewerAccountType === "student") {
    profile.viewerAccountType = viewerAccountType;
  }
  if (fatherPhone || motherPhone) {
    profile.fatherPhone = fatherPhone || "";
    profile.motherPhone = motherPhone || "";
    profile.alternativePhone = alternativePhone || "";
  }
  await db.collection("institutions").doc(institutionId).collection("users").doc(user.uid).set(profile);
  return {uid: user.uid};
});

exports.deleteInstitutionUser = onCall(async (request) => {
  requireAdmin(request);
  const {uid} = request.data;
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (uid === request.auth.uid) {
    throw new HttpsError("invalid-argument", "You cannot delete your own account.");
  }
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }
  return {ok: true};
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

async function notifyReportCardParents(
  institutionId,
  studentId,
  title,
  body,
) {
  const studentSnap = await db
    .collection("institutions")
    .doc(institutionId)
    .collection("students")
    .doc(studentId)
    .get();

  if (!studentSnap.exists) {
    console.error(`Student not found: ${studentId}`);
    return;
  }

  const student = studentSnap.data() || {};
  const viewerUids = Array.isArray(student.viewerUids)
    ? student.viewerUids
    : [];

  if (viewerUids.length === 0) {
    console.log(`No parent/viewer accounts linked to student: ${studentId}`);
    return;
  }

  const userRefs = viewerUids.map((uid) =>
    db
      .collection("institutions")
      .doc(institutionId)
      .collection("users")
      .doc(uid)
  );

  const userSnaps = await db.getAll(...userRefs);

  const tokens = userSnaps
    .map((snap) => snap.data()?.fcmToken)
    .filter((token) => typeof token === "string" && token.length > 0);

  if (tokens.length === 0) {
    console.log(`No FCM tokens found for student: ${studentId}`);
    return;
  }

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
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

    await notifyReportCardParents(
      event.params.institutionId,
      data.studentId,
      "Report card published",
      `${data.examType || "Exam"} report card is now available.`,
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
