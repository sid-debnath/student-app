import { getApps, initializeApp, cert } from "npm:firebase-admin/app";
import { getAuth } from "npm:firebase-admin/auth";
import { getFirestore } from "npm:firebase-admin/firestore";
import { getMessaging } from "npm:firebase-admin/messaging";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

if (!serviceAccountRaw) {
  throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not configured.");
}

const serviceAccount = JSON.parse(serviceAccountRaw);

if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const auth = getAuth();
const db = getFirestore();
const messaging = getMessaging();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        {
          status: 405,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const authorization = req.headers.get("Authorization");

    if (!authorization?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({
          error: "Missing Firebase authentication token",
        }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const idToken = authorization.substring("Bearer ".length).trim();

    // Verify that the request comes from a real Firebase user.
    const decodedToken = await auth.verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const body = await req.json();

    const studentId = String(body.studentId ?? "");
    const examType = String(body.examType ?? "Exam");
    const institutionId = String(body.institutionId ?? "");

    if (!studentId) {
      return new Response(
        JSON.stringify({ error: "studentId is required" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    if (!institutionId) {
      return new Response(
        JSON.stringify({ error: "institutionId is required" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Verify the Firebase user against the admin profile
    // inside the requested institution.
    const userRef = db
      .collection("institutions")
      .doc(institutionId)
      .collection("users")
      .doc(uid);

    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return new Response(
        JSON.stringify({ error: "User profile not found" }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const userData = userSnap.data() ?? {};
    const role = userData.role;

    if (role !== "admin") {
      return new Response(
        JSON.stringify({
          error: "Only administrators can send notifications",
        }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Find the student in the same institution.
    const studentRef = db
      .collection("institutions")
      .doc(institutionId)
      .collection("students")
      .doc(studentId);

    const studentSnap = await studentRef.get();

    if (!studentSnap.exists) {
      return new Response(
        JSON.stringify({ error: "Student not found" }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const student = studentSnap.data() ?? {};

    const viewerUids = Array.isArray(student.viewerUids)
      ? student.viewerUids.filter(
          (uid): uid is string =>
            typeof uid === "string" && uid.trim().length > 0,
        )
      : [];

    if (viewerUids.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          sent: 0,
          failed: 0,
          message:
            "No parent/viewer accounts linked to this student",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Get the linked parent/viewer accounts.
    const userRefs = viewerUids.map((viewerUid) =>
      db
        .collection("institutions")
        .doc(institutionId)
        .collection("users")
        .doc(viewerUid)
    );

    const userSnaps = await db.getAll(...userRefs);

    const tokens = userSnaps
      .map((snap) => snap.data()?.fcmToken)
      .filter(
        (token): token is string =>
          typeof token === "string" && token.trim().length > 0,
      );

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          sent: 0,
          failed: 0,
          message:
            "No FCM tokens found for linked parent/viewer accounts",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Send the notification through Firebase Cloud Messaging.
    const result = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: "Report card published",
        body: `${examType} report card is now available.`,
      },
      data: {
        type: "report_card",
        studentId,
      },
    });

    return new Response(
      JSON.stringify({
        ok: true,
        sent: result.successCount,
        failed: result.failureCount,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Notification error:", error);

    return new Response(
      JSON.stringify({
        error: "Failed to send notification",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});