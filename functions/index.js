const { onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

async function deleteSubcollectionDocs(collectionRef) {
  const snapshot = await collectionRef.get();
  if (snapshot.empty) return 0;
  let deleted = 0;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
    deleted += 1;
  });
  await batch.commit();
  return deleted;
}

async function cleanupUserSystems(uid) {
  const systemsRef = db.collection('user').doc(uid).collection('systems');
  const systemsSnapshot = await systemsRef.get();
  if (systemsSnapshot.empty) return 0;

  let removedSystems = 0;
  for (const systemDoc of systemsSnapshot.docs) {
    const weeklyLogsRef = systemDoc.ref.collection('weekly_logs');
    await deleteSubcollectionDocs(weeklyLogsRef);
    await systemDoc.ref.delete();
    removedSystems += 1;
  }
  return removedSystems;
}

exports.onUserDeleted = onDocumentDeleted('user/{uid}', async (event) => {
  const uid = event.params.uid;

  try {
    const removedSystems = await cleanupUserSystems(uid);
    if (removedSystems > 0) {
      console.log(
        `Cleanup: removed ${removedSystems} system(s) for user ${uid}.`,
      );
    } else {
      console.log(`Cleanup: no remaining systems for user ${uid}.`);
    }
  } catch (err) {
    console.error(`Cleanup failed for user ${uid}:`, err);
  }

  try {
    await admin.auth().deleteUser(uid);
    console.log(`Auth: successfully removed user ${uid}.`);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      console.log(`Auth: user ${uid} already removed.`);
      return;
    }
    console.error(`Auth: failed to remove user ${uid}:`, err);
  }
});
