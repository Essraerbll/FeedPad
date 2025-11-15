/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onUserCreated} = require("firebase-functions/v2/identity");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Firebase Admin SDK'yi başlat
admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Yeni kullanıcı oluşturulduğunda otomatik profil belgesi oluştur
exports.createUserProfile = onUserCreated(async (user) => {
  const uid = user.uid;
  const email = user.email || "";
  const displayName = user.displayName || "Kullanıcı";

  logger.log(`Yeni kullanıcı kaydedildi: ${uid}, email: ${email}`);

  try {
    // Firestore'a yeni profil belgesi yaz
    await admin.firestore().collection("users").doc(uid).set({
      email: email,
      username: displayName,
      profileImageUrl: "",
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      location: "",
      bio: "",
      followersCount: 0,
      followingCount: 0,
    });

    logger.log(`Profil belgesi başarıyla oluşturuldu: ${uid}`);
  } catch (error) {
    logger.error(`Profil belgesi oluşturulamadı: ${error.message}`);
    throw error;
  }
});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
